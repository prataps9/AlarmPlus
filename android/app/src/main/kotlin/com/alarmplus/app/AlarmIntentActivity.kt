package com.alarmplus.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.AlarmClock
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

/**
 * Makes AlarmPlus a real system alarm provider.
 *
 * Google Assistant and other apps drive alarm apps through the standard
 * AlarmClock intents ("set an alarm for 7am", "show my alarms", "snooze").
 * Without these the app can never be offered as the device's alarm handler.
 *
 * This is a trampoline with no UI of its own: it translates the intent into a
 * command, hands it to Dart — where the alarm state actually lives, in Hive,
 * which native code can't read — and finishes, launching the app when the
 * command needs UI or the engine wasn't running to receive it.
 */
class AlarmIntentActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handle(intent)
        finish()
    }

    private fun handle(source: Intent?) {
        val command = when (source?.action) {
            AlarmClock.ACTION_SET_ALARM -> setAlarmCommand(source)
            AlarmClock.ACTION_SHOW_ALARMS -> WidgetCommandBridge.CMD_SHOW_ALARMS
            AlarmClock.ACTION_DISMISS_ALARM -> WidgetCommandBridge.CMD_DISMISS_ALARM
            AlarmClock.ACTION_SNOOZE_ALARM -> WidgetCommandBridge.CMD_SNOOZE
            else -> null
        }

        if (command == null) {
            WidgetCommandBridge.launchApp(this)
            return
        }

        val delivered = WidgetCommandBridge.dispatch(this, command)

        // A queued command needs the app opened so Dart drains it. A SET_ALARM
        // that wasn't told to skip the UI should also show what it created.
        if (!delivered || wantsUi(source)) {
            WidgetCommandBridge.launchApp(this)
        }
    }

    private fun wantsUi(source: Intent?): Boolean {
        if (source?.action != AlarmClock.ACTION_SET_ALARM) return false
        return !source.getBooleanExtra(AlarmClock.EXTRA_SKIP_UI, false)
    }

    private fun setAlarmCommand(source: Intent): String {
        val payload = JSONObject().apply {
            put("cmd", WidgetCommandBridge.CMD_SET_ALARM)
            // -1 means the caller named no time; Dart then opens the editor
            // rather than inventing an alarm.
            put("hour", source.getIntExtra(AlarmClock.EXTRA_HOUR, -1))
            put("minute", source.getIntExtra(AlarmClock.EXTRA_MINUTES, 0))
            put("skipUi", source.getBooleanExtra(AlarmClock.EXTRA_SKIP_UI, false))
            put("vibrate", source.getBooleanExtra(AlarmClock.EXTRA_VIBRATE, true))
            source.getStringExtra(AlarmClock.EXTRA_MESSAGE)?.let { put("label", it) }
        }

        // EXTRA_DAYS uses java.util.Calendar weekdays (Sunday = 1, Monday = 2);
        // Dart's repeatDays uses DateTime weekdays (Monday = 1, Sunday = 7).
        val days = source.getIntegerArrayListExtra(AlarmClock.EXTRA_DAYS)
        if (!days.isNullOrEmpty()) {
            val converted = JSONArray()
            for (day in days) {
                converted.put(if (day == Calendar.SUNDAY) 7 else day - 1)
            }
            payload.put("days", converted)
        }

        return payload.toString()
    }
}
