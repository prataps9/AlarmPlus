package com.alarmplus.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Alarms are scheduled as absolute instants, so after a flight from New York
 * to London a 07:00 alarm would ring at 12:00. The app already re-checks the
 * zone when it comes to the foreground; this covers a phone that changes
 * zone and isn't opened before the next alarm. TIMEZONE_CHANGED is exempt
 * from the Android 8 implicit-broadcast limits, so a manifest receiver gets
 * it with the app closed.
 */
class TimeZoneChangeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_TIMEZONE_CHANGED) return
        BackgroundDartRunner.dispatch(context, "timezoneChanged", emptyList(), goAsync())
    }
}
