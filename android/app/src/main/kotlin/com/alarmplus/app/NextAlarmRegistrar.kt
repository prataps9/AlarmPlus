package com.alarmplus.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Registers the next alarm with the OS through AlarmManager.setAlarmClock().
 *
 * This is what makes Android treat AlarmPlus as a real alarm clock: the
 * status-bar alarm icon, the next-alarm text on the lock screen and in the
 * system Clock, and visibility to other apps via getNextAlarmClock(). It is
 * also the strongest Doze exemption AlarmManager offers, and it is what
 * justifies the USE_EXACT_ALARM permission the app declares.
 *
 * It deliberately does NOT ring anything. The `alarm` plugin still owns
 * scheduling and playback — ringing here would double up. setAlarmClock()
 * requires an operation PendingIntent, so that is put to use as a safety net:
 * [NextAlarmMarkerReceiver] only asks Dart to re-check its schedule.
 */
object NextAlarmRegistrar {

    private const val TAG = "NextAlarmRegistrar"
    private const val REQ_SHOW = 770077
    private const val REQ_MARKER = 770078

    private fun pendingFlags(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

    /**
     * Must be built identically for set and cancel — AlarmManager matches the
     * alarm to cancel by intent equality, which ignores extras.
     */
    private fun markerOperation(context: Context): PendingIntent {
        val intent = Intent(context, NextAlarmMarkerReceiver::class.java).apply {
            action = NextAlarmMarkerReceiver.ACTION_MARKER
        }
        return PendingIntent.getBroadcast(context, REQ_MARKER, intent, pendingFlags())
    }

    /** Tells the system an alarm is due at [triggerAtMillis] (epoch millis). */
    fun setNextAlarm(context: Context, triggerAtMillis: Long) {
        val manager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return

        // Tapping the lock-screen or status-bar alarm chip opens the app.
        val launch = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val show = PendingIntent.getActivity(context, REQ_SHOW, launch, pendingFlags())

        try {
            manager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, show),
                markerOperation(context)
            )
        } catch (e: SecurityException) {
            // Android 12+ can withhold exact-alarm permission. The app's own
            // scheduling still runs; only the system-level registration is lost.
            Log.w(TAG, "setAlarmClock denied: ${e.message}")
        }
    }

    /** Clears the registration — no alarms are enabled. */
    fun clear(context: Context) {
        val manager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        try {
            manager.cancel(markerOperation(context))
        } catch (e: Exception) {
            Log.w(TAG, "clear failed: ${e.message}")
        }
    }
}
