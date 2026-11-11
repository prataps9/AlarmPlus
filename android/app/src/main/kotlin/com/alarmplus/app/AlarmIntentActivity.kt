package com.alarmplus.app

import android.app.Activity
import android.os.Bundle
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Answers the standard Android alarm intents, so Google Assistant, Wear OS,
 * Android Auto and other apps can use Alarm+ as the phone's alarm app
 * ("Hey Google, set an alarm for 6:30"):
 *
 * - SET_ALARM: creates the alarm (HOUR, MINUTES, MESSAGE, DAYS), through
 *   the same Dart code the app uses. With SKIP_UI it stays invisible;
 *   without it the app opens afterwards. No HOUR: just opens the app.
 * - SHOW_ALARMS: opens the app.
 * - SNOOZE_ALARM: snoozes the ringing alarm (not for Hardcore alarms).
 * - DISMISS_ALARM: opens the app on the ring screen. It never dismisses
 *   directly: that would skip the wake challenge.
 *
 * It has no UI of its own; the activity stays until Dart has finished, so
 * the process cannot be killed halfway through saving.
 */
class AlarmIntentActivity : Activity() {

    private companion object {
        const val TAG = "AlarmIntentActivity"
        const val ACTION_SET = "android.intent.action.SET_ALARM"
        const val ACTION_SNOOZE = "android.intent.action.SNOOZE_ALARM"
        const val EXTRA_HOUR = "android.intent.extra.alarm.HOUR"
        const val EXTRA_MINUTES = "android.intent.extra.alarm.MINUTES"
        const val EXTRA_MESSAGE = "android.intent.extra.alarm.MESSAGE"
        const val EXTRA_DAYS = "android.intent.extra.alarm.DAYS"
        const val EXTRA_SKIP_UI = "android.intent.extra.alarm.SKIP_UI"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            when (intent?.action) {
                ACTION_SET -> handleSet()
                ACTION_SNOOZE -> {
                    val delivered = WidgetCommandBridge.dispatch(this, WidgetCommandBridge.CMD_SNOOZE)
                    if (!delivered) WidgetCommandBridge.launchApp(this)
                    finish()
                }
                else -> {
                    // SHOW_ALARMS, DISMISS_ALARM: show the app.
                    WidgetCommandBridge.launchApp(this)
                    finish()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not handle ${intent?.action}", e)
            finish()
        }
    }

    private fun handleSet() {
        val i = intent
        if (!i.hasExtra(EXTRA_HOUR)) {
            // No time given: let the person pick it in the app.
            WidgetCommandBridge.launchApp(this)
            finish()
            return
        }
        val json = JSONObject()
            .put("hour", i.getIntExtra(EXTRA_HOUR, -1))
            .put("minute", i.getIntExtra(EXTRA_MINUTES, 0))
            .put("message", i.getStringExtra(EXTRA_MESSAGE) ?: "")
            .put("days", JSONArray(i.getIntegerArrayListExtra(EXTRA_DAYS) ?: arrayListOf<Int>()))
            .toString()
        val skipUi = i.getBooleanExtra(EXTRA_SKIP_UI, false)
        BackgroundDartRunner.dispatch(this, "setAlarm", listOf(json), null) {
            if (!skipUi) WidgetCommandBridge.launchApp(this)
            finish()
        }
    }
}
