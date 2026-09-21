package com.alarmplus.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires at the moment the alarm registered with [NextAlarmRegistrar] is due.
 *
 * It must never ring: the `alarm` plugin schedules and plays the real alarm,
 * and ringing here would double up. setAlarmClock() simply requires an
 * operation PendingIntent, so this one earns its keep as a safety net — it
 * asks Dart to re-check its schedule, which re-arms anything that was missed.
 *
 * Dart's resync is a no-op while an alarm is actually ringing, so the normal
 * case (this fires at the same instant the real alarm does) changes nothing.
 */
class NextAlarmMarkerReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_MARKER = "alarmplus.NEXT_ALARM_MARKER"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        // No launchApp(): a queued resync is applied at next start, and opening
        // the app on its own at alarm time would be hostile.
        WidgetCommandBridge.dispatch(context, WidgetCommandBridge.CMD_RESYNC)
    }
}
