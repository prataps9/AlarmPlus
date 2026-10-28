package com.alarmplus.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/**
 * The "live" alarm and timer: an ongoing countdown that sits on the lock
 * screen and, on Android 16+ (ColorOS 16, OxygenOS 16, One UI 8…), is
 * promoted to a status-bar capsule, the same slot Swiggy/Zomato delivery
 * trackers use. Older phones show it as an ordinary ongoing notification
 * with a live countdown.
 *
 * The alarm countdown appears [window] before the next ring and is
 * scheduled natively (AlarmManager), so it shows with the app closed; the
 * notification times itself out at the ring. The next ring is worked out in
 * Dart (skips, pauses, snoozes) and handed over by [syncAlarm]; the last
 * one is kept in prefs so a reboot can restore it.
 */
object LiveActivity {

    private const val TAG = "LiveActivity"
    private const val PREFS = "alarmplus_live"
    private const val KEY_ALARM = "alarm"
    private const val CHANNEL_ID = "alarmplus_live"
    private const val ID_ALARM = 7401
    private const val ID_TIMER = 7402

    const val ACTION_SHOW = "alarmplus.LIVE_SHOW"
    const val ACTION_SKIP = "alarmplus.LIVE_SKIP"
    const val EXTRA_ALARM_ID = "alarmId"

    /** Android 16's opt-in for a status-bar capsule (Notification.EXTRA_REQUEST_PROMOTED_ONGOING). */
    private const val EXTRA_REQUEST_PROMOTED_ONGOING = "android.requestPromotedOngoing"

    private const val ACCENT = 0xFF3B82F6.toInt()

    private class Ring(
        val alarmId: Int,
        val dueMs: Long,
        val windowMs: Long,
        val title: String,
        val text: String,
        val canSkip: Boolean,
    )

    // ── Alarm ────────────────────────────────────────────────────────────────

    /** Stores the next ring from [json] (null or empty: none) and shows or schedules its countdown. */
    fun syncAlarm(context: Context, json: String?) {
        val ctx = context.applicationContext
        cancelShow(ctx)
        notificationManager(ctx).cancel(ID_ALARM)
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (json.isNullOrEmpty()) {
            prefs.edit().remove(KEY_ALARM).apply()
            return
        }
        prefs.edit().putString(KEY_ALARM, json).apply()
        apply(ctx)
    }

    /** Re-evaluates the stored ring: after the show alarm fires, or a reboot. */
    fun restore(context: Context) = apply(context.applicationContext)

    fun clearAlarm(context: Context) = syncAlarm(context, null)

    private fun load(ctx: Context): Ring? {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_ALARM, null) ?: return null
        return try {
            val o = JSONObject(raw)
            Ring(
                alarmId = o.getInt("alarmId"),
                dueMs = o.getLong("dueMs"),
                windowMs = o.getLong("windowMs"),
                title = o.getString("title"),
                text = o.optString("text"),
                canSkip = o.optBoolean("canSkip", true),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Bad stored ring", e)
            null
        }
    }

    private fun apply(ctx: Context) {
        val ring = load(ctx) ?: return
        val now = System.currentTimeMillis()
        if (ring.dueMs <= now) {
            notificationManager(ctx).cancel(ID_ALARM)
            return
        }
        val showAt = ring.dueMs - ring.windowMs
        if (now >= showAt) post(ctx, ring) else scheduleShow(ctx, showAt)
    }

    private fun post(ctx: Context, ring: Ring) {
        val now = System.currentTimeMillis()
        val builder = base(ctx)
            .setContentTitle(ring.title)
            .setContentText(ring.text.ifEmpty { "Alarm+" })
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            // The countdown ticks by itself: in the shade and in the capsule.
            .setWhen(ring.dueMs)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            // The ring takes over at due time; this just goes away.
            .setTimeoutAfter(ring.dueMs - now + 1_000)
        if (ring.canSkip) {
            builder.addAction(
                0, "Skip",
                PendingIntent.getBroadcast(
                    ctx, ring.alarmId,
                    Intent(ctx, LiveAlarmReceiver::class.java)
                        .setAction(ACTION_SKIP)
                        .putExtra(EXTRA_ALARM_ID, ring.alarmId),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            )
        }
        notify(ctx, ID_ALARM, builder)
    }

    private fun scheduleShow(ctx: Context, at: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = showIntent(ctx)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        } else {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    private fun cancelShow(ctx: Context) {
        (ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(showIntent(ctx))
    }

    private fun showIntent(ctx: Context): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, 0,
            Intent(ctx, LiveAlarmReceiver::class.java).setAction(ACTION_SHOW),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    // ── Timer ────────────────────────────────────────────────────────────────

    /** A running timer's countdown, ending at [endMs]; [endMs] <= 0 clears it. */
    fun syncTimer(context: Context, endMs: Long, title: String, text: String) {
        val ctx = context.applicationContext
        val now = System.currentTimeMillis()
        if (endMs <= now) {
            notificationManager(ctx).cancel(ID_TIMER)
            return
        }
        val builder = base(ctx)
            .setContentTitle(title)
            .setContentText(text)
            .setCategory(NotificationCompat.CATEGORY_STOPWATCH)
            .setWhen(endMs)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setTimeoutAfter(endMs - now + 1_000)
        notify(ctx, ID_TIMER, builder)
    }

    // ── Shared ───────────────────────────────────────────────────────────────

    private fun base(ctx: Context): NotificationCompat.Builder {
        val open = WidgetCommandBridge.launchIntent(ctx)?.let {
            PendingIntent.getActivity(
                ctx, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        return NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(ACCENT)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .addExtras(Bundle().apply { putBoolean(EXTRA_REQUEST_PROMOTED_ONGOING, true) })
    }

    private fun notify(ctx: Context, id: Int, builder: NotificationCompat.Builder) {
        val nm = notificationManager(ctx)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Low importance is silent but still allowed to be promoted
            // (IMPORTANCE_MIN is not).
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Live alarm and timer", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Countdown to your next alarm and running timer" }
            )
        }
        try {
            nm.notify(id, builder.build())
        } catch (e: SecurityException) {
            Log.w(TAG, "Notifications not allowed", e)
        }
    }

    private fun notificationManager(ctx: Context) =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}

/** The countdown's show alarm, its Skip button, and reboot restore. */
class LiveAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            LiveActivity.ACTION_SHOW,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> LiveActivity.restore(context)
            LiveActivity.ACTION_SKIP -> {
                val id = intent.getIntExtra(LiveActivity.EXTRA_ALARM_ID, 0)
                if (id == 0) return
                // Gone straight away; Dart then syncs the ring after it.
                LiveActivity.clearAlarm(context)
                BackgroundDartRunner.dispatch(context, "skipUpcoming", listOf(id.toString()), goAsync())
            }
        }
    }
}
