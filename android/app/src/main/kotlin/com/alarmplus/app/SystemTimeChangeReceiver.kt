package com.alarmplus.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms alarms after the events that invalidate whatever was scheduled.
 *
 * The `alarm` plugin schedules by relative delay — it converts the alarm's
 * wall-clock time into "fire in N seconds" at scheduling time — so a timezone
 * or clock change silently shifts every pending alarm by the difference. A
 * reboot or an app update drops them outright.
 *
 * Each of these asks Dart to reschedule from the stored wall-clock times,
 * which are the only source of truth. The plugin ships its own BOOT_COMPLETED
 * receiver, but it replays those same stale relative delays, so this runs a
 * proper resync on top.
 */
class SystemTimeChangeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_MY_PACKAGE_REPLACED ->
                WidgetCommandBridge.dispatch(context, WidgetCommandBridge.CMD_RESYNC)
        }
    }
}
