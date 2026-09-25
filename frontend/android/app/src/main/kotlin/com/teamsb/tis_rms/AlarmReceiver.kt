package com.teamsb.tis_rms

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmReceiver"
        private const val CHANNEL_ID = "tis_rms_activities_channel"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_SERVER_URL = "flutter.server_url"
        private const val KEY_TOKEN = "flutter.jwt_token"
        private const val KEY_LAST_ID = "flutter.last_seen_notification_id"
        private const val TIMEOUT_MS = 4000
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        Thread {
            try {
                checkAndNotify(context)
            } catch (e: Exception) {
                Log.e(TAG, "check failed: ${e.message}")
            } finally {
                AlarmScheduler.schedule(context)
                pendingResult.finish()
            }
        }.start()
    }

    private fun checkAndNotify(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val rawUrl = prefs.getString(KEY_SERVER_URL, "") ?: ""
        if (rawUrl.isEmpty()) return

        val token = prefs.getString(KEY_TOKEN, "") ?: ""
        if (token.isEmpty()) return

        val clean = rawUrl.trimEnd('/')
        val baseUrl = if (clean.endsWith("/api")) clean else "$clean/api"

        val conn = (URL("$baseUrl/notifications").openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = TIMEOUT_MS
            readTimeout = TIMEOUT_MS
            setRequestProperty("Authorization", "Bearer $token")
        }

        if (conn.responseCode != 200) {
            conn.disconnect()
            return
        }

        val body = conn.inputStream.bufferedReader().readText()
        conn.disconnect()

        val list = JSONArray(body)
        if (list.length() == 0) return

        val highestOldId = prefs.getInt(KEY_LAST_ID, 0)
        if (highestOldId == 0) {
            // Seed KEY_LAST_ID on initial check to avoid spamming past notifications
            var maxId = 0
            for (i in 0 until list.length()) {
                val id = list.getJSONObject(i).optInt("id", 0)
                if (id > maxId) maxId = id
            }
            if (maxId > 0) {
                prefs.edit().putInt(KEY_LAST_ID, maxId).apply()
            }
            return
        }

        var newHighestId = highestOldId
        val soundEnabled = prefs.getBoolean("flutter.pref_sound_enabled", false)
        val vibrationEnabled = prefs.getBoolean("flutter.pref_vibration_enabled", false)
        val channelId = when {
            soundEnabled && vibrationEnabled -> "tis_rms_activities_sound_vibrate"
            soundEnabled -> "tis_rms_activities_sound_only"
            vibrationEnabled -> "tis_rms_activities_vibrate_only"
            else -> "tis_rms_activities_silent"
        }
        ensureChannel(context, channelId, soundEnabled, vibrationEnabled)
        val notifManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        for (i in 0 until list.length()) {
            val item = list.getJSONObject(i)
            val id = item.optInt("id", 0)

            // Handle is_read as boolean or integer (0/1)
            val isReadRaw = item.opt("is_read")
            val isRead = isReadRaw == true || isReadRaw == 1

            if (id <= highestOldId || isRead) continue

            val title = item.optString("title", "TIS RMS Notification")
            val message = item.optString("message", "")

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP }

            val pi = PendingIntent.getActivity(
                context, id, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = Notification.Builder(context, channelId)
                .setSmallIcon(R.drawable.ic_launcher_foreground)
                .setContentTitle(title)
                .setContentText(message)
                .setAutoCancel(true)
                .setContentIntent(pi)
                .build()

            notifManager.notify(id, notification)
            Log.d(TAG, "notified: [$id] $title")

            if (id > newHighestId) newHighestId = id
        }

        if (newHighestId > highestOldId) {
            prefs.edit().putInt(KEY_LAST_ID, newHighestId).apply()
        }
    }

    private fun ensureChannel(context: Context, channelId: String, soundEnabled: Boolean, vibrationEnabled: Boolean) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(channelId) != null) return
        val channelName = when (channelId) {
            "tis_rms_activities_sound_vibrate" -> "Recent Activities (Sound & Vibrate)"
            "tis_rms_activities_sound_only" -> "Recent Activities (Sound Only)"
            "tis_rms_activities_vibrate_only" -> "Recent Activities (Vibrate Only)"
            else -> "Recent Activities (Silent)"
        }
        val importance = if (soundEnabled || vibrationEnabled) NotificationManager.IMPORTANCE_HIGH else NotificationManager.IMPORTANCE_DEFAULT
        val channel = NotificationChannel(
            channelId,
            channelName,
            importance
        ).apply {
            description = "Notifications for recent activities and system events"
            enableVibration(vibrationEnabled)
            if (!soundEnabled) {
                setSound(null, null)
            }
        }
        manager.createNotificationChannel(channel)
    }
}
