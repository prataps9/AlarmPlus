package com.alarmplus.app

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Handles taps on the home-screen widget's buttons.
 *
 * Deliberately does no work of its own beyond handing the command to
 * [WidgetCommandBridge]: a receiver gets a short window to run and cannot
 * start a background service on Android 12+.
 */
class AlarmWidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_TOGGLE = "alarmplus.WIDGET_TOGGLE_NEXT"
        const val ACTION_SNOOZE = "alarmplus.WIDGET_SNOOZE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val command = when (intent.action) {
            ACTION_TOGGLE -> WidgetCommandBridge.CMD_TOGGLE_NEXT
            ACTION_SNOOZE -> WidgetCommandBridge.CMD_SNOOZE
            else -> return
        }

        val delivered = WidgetCommandBridge.dispatch(context, command)
        if (!delivered) {
            // Queued instead — open the app so Dart drains it now rather than
            // whenever the user next happens to launch.
            WidgetCommandBridge.launchApp(context)
        }

        // Ask the provider to redraw; Dart will push fresh values once the
        // command has actually been applied.
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, AlarmWidgetProvider::class.java)
        )
        if (ids.isNotEmpty()) {
            context.sendBroadcast(
                Intent(context, AlarmWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
            )
        }
    }
}
