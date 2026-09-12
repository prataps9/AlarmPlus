package com.alarmplus.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget showing the current streak and next scheduled alarm.
 * Data is synced from Dart via `WidgetSyncService` (lib/core/services/widget_sync_service.dart)
 * using the `home_widget` plugin's shared storage.
 */
class AlarmWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences
  ) {
    appWidgetIds.forEach { widgetId ->
      val streak = widgetData.getInt("streak_days", 0)
      val nextAlarm = widgetData.getString("next_alarm", null) ?: "No alarm set"
      val flameColor = when {
        streak >= 30 -> Color.parseColor("#FBBF24") // gold — on a roll
        streak >= 7 -> Color.parseColor("#F97316") // orange
        streak >= 3 -> Color.parseColor("#EF4444") // red-orange
        else -> Color.parseColor("#94A3B8") // slate — just getting started
      }

      val nextEnabled = widgetData.getBoolean("next_alarm_enabled", false)
      val ringing = widgetData.getBoolean("alarm_ringing", false)

      val views = RemoteViews(context.packageName, R.layout.alarm_widget).apply {
        setOnClickPendingIntent(
            R.id.alarm_widget_container,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
        setInt(R.id.alarm_widget_flame_icon, "setColorFilter", flameColor)
        setTextViewText(R.id.alarm_widget_streak, streak.toString())
        setTextViewText(R.id.alarm_widget_streak_label, "day streak")
        setTextViewText(R.id.alarm_widget_next_alarm, nextAlarm)

        // Toggle reflects whether the next alarm is armed.
        setInt(
            R.id.alarm_widget_toggle,
            "setColorFilter",
            if (nextEnabled) Color.parseColor("#22C55E") else Color.parseColor("#64748B"))
        setOnClickPendingIntent(
            R.id.alarm_widget_toggle,
            actionIntent(context, AlarmWidgetActionReceiver.ACTION_TOGGLE, widgetId))

        // Snooze only means anything while something is actually ringing.
        setInt(
            R.id.alarm_widget_snooze,
            "setColorFilter",
            if (ringing) Color.parseColor("#F97316") else Color.parseColor("#475569"))
        if (ringing) {
          setOnClickPendingIntent(
              R.id.alarm_widget_snooze,
              actionIntent(context, AlarmWidgetActionReceiver.ACTION_SNOOZE, widgetId))
        }
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  /**
   * Explicit (non-exported) broadcast back into this app. The request code is
   * per-widget-and-action so multiple placed widgets don't share one
   * PendingIntent and overwrite each other's extras.
   */
  private fun actionIntent(context: Context, action: String, widgetId: Int): PendingIntent {
    val intent = Intent(context, AlarmWidgetActionReceiver::class.java).apply {
      this.action = action
      putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
    }
    return PendingIntent.getBroadcast(
        context,
        action.hashCode() + widgetId,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
  }
}
