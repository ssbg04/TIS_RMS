package com.teamsb.tis_rms

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureNotificationChannel()
        AlarmScheduler.schedule(this)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val channels = listOf(
                NotificationChannel(
                    "tis_rms_activities_sound_vibrate",
                    "Recent Activities (Sound & Vibrate)",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications with sound and vibration"
                    enableVibration(true)
                },
                NotificationChannel(
                    "tis_rms_activities_sound_only",
                    "Recent Activities (Sound Only)",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications with sound only"
                    enableVibration(false)
                },
                NotificationChannel(
                    "tis_rms_activities_vibrate_only",
                    "Recent Activities (Vibrate Only)",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications with vibration only"
                    enableVibration(true)
                    setSound(null, null)
                },
                NotificationChannel(
                    "tis_rms_activities_silent",
                    "Recent Activities (Silent)",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Silent notifications without sound or vibration"
                    enableVibration(false)
                    setSound(null, null)
                },
                NotificationChannel(
                    "tis_rms_activities_channel",
                    "Recent Activities",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Notifications for recent activities and system events"
                    enableVibration(false)
                    setSound(null, null)
                }
            )

            for (ch in channels) {
                notificationManager.createNotificationChannel(ch)
            }
        }
    }
}

