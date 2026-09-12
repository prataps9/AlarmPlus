package com.alarmplus.app

import android.appwidget.AppWidgetManager
import android.content.Context
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

      val views = RemoteViews(context.packageName, R.layout.alarm_widget).apply {
        setOnClickPendingIntent(
            R.id.alarm_widget_container,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
        setInt(R.id.alarm_widget_flame_icon, "setColorFilter", flameColor)
        setTextViewText(R.id.alarm_widget_streak, streak.toString())
        setTextViewText(R.id.alarm_widget_streak_label, "day streak")
        setTextViewText(R.id.alarm_widget_next_alarm, nextAlarm)
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
