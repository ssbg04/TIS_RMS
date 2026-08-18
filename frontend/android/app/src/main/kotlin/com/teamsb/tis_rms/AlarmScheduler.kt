package com.teamsb.tis_rms

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

object AlarmScheduler {
    private const val TAG = "AlarmScheduler"
    const val ACTION = "com.teamsb.tis_rms.ALARM_NOTIFICATION_CHECK"
    private const val INTERVAL_MS = 2 * 60 * 1000L // 2 minutes

    fun schedule(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = buildPendingIntent(context)
            alarmManager.cancel(pi)
            val triggerAt = SystemClock.elapsedRealtime() + INTERVAL_MS

            val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                    alarmManager.canScheduleExactAlarms()

            if (canExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi
                )
                Log.d(TAG, "scheduled (exact): next check in ${INTERVAL_MS / 1000}s")
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pi
                )
                Log.d(TAG, "scheduled (inexact): next check in ${INTERVAL_MS / 1000}s")
            }
        } catch (e: Exception) {
            Log.e(TAG, "schedule failed: ${e.message}")
        }
    }

    fun cancel(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(buildPendingIntent(context))
            Log.d(TAG, "cancelled")
        } catch (e: Exception) {
            Log.e(TAG, "cancel failed: ${e.message}")
        }
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply { action = ACTION }
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
