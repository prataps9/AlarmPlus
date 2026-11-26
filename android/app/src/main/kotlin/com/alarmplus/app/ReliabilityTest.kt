package com.alarmplus.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Alarm Health Check: proves that an alarm fires with Alarm+ swiped away.
 *
 * Many phones (Xiaomi, Oppo/Realme, Vivo, Huawei…) stop a closed app from
 * being started in the background, so an alarm app can be perfectly
 * configured and still never ring. Permission checks can't see that; only
 * a real alarm can. The test uses the same AlarmManager call as the alarm
 * plugin (setExactAndAllowWhileIdle), so if it fires, alarms can.
 *
 * State lives in its own prefs file; Dart reads it over the channel.
 */
object ReliabilityTest {

    private const val PREFS = "alarmplus_reliability_test"
    private const val KEY_DUE = "due"
    private const val KEY_FIRED = "fired"
    private const val CHANNEL_ID = "alarmplus_health_check"
    private const val NOTIFICATION_ID = 7301

    /**
     * Schedules the test [delaySeconds] from now. Returns the due time in
     * epoch ms, or null when exact alarms aren't allowed (then the test
     * can't run, and that is the problem to fix).
     */
    fun start(context: Context, delaySeconds: Int): Long? {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
            return null
        }
        val due = System.currentTimeMillis() + delaySeconds * 1000L
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(KEY_DUE, due)
            .remove(KEY_FIRED)
            .apply()
        am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, pendingIntent(context))
        return due
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pendingIntent(context))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    /** {due, fired}: epoch ms, either absent when unknown. */
    fun result(context: Context): Map<String, Long> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val out = mutableMapOf<String, Long>()
        if (prefs.contains(KEY_DUE)) out["due"] = prefs.getLong(KEY_DUE, 0)
        if (prefs.contains(KEY_FIRED)) out["fired"] = prefs.getLong(KEY_FIRED, 0)
        return out
    }

    internal fun onFired(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        prefs.edit().putLong(KEY_FIRED, now).apply()
        val due = prefs.getLong(KEY_DUE, now)
        val lateSeconds = ((now - due) / 1000).coerceAtLeast(0)
        notify(context, lateSeconds)
    }

    private fun notify(context: Context, lateSeconds: Long) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Alarm health check", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        val text = if (lateSeconds <= 60) {
            "Your phone let Alarm+ ring with the app closed. Alarms will work."
        } else {
            "It went off ${lateSeconds / 60} min late. Open Alarm+ to fix it."
        }
        val open = WidgetCommandBridge.launchIntent(context)?.let {
            PendingIntent.getActivity(
                context, NOTIFICATION_ID, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(if (lateSeconds <= 60) "Test alarm worked ✓" else "Test alarm was late")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try {
            nm.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.w("ReliabilityTest", "Notifications not allowed", e)
        }
    }

    private fun pendingIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context, 0, Intent(context, ReliabilityTestReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    // ── Phone-maker background settings ────────────────────────────────────

    /**
     * The settings screens phone makers add to stop apps starting in the
     * background ("Autostart", "Background start", "Protected apps"). Not
     * public APIs, so each is tried in turn; they move between OS versions.
     */
    private val autostartScreens = mapOf(
        "xiaomi" to listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        ),
        "oppo" to listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        ),
        "vivo" to listOf(
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        ),
        "huawei" to listOf(
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
        ),
        "oneplus" to listOf(
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
        ),
        "samsung" to listOf(
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
        ),
        "asus" to listOf(
            "com.asus.mobilemanager" to "com.asus.mobilemanager.powersaver.PowerSaverSettings",
        ),
    )

    /** The phone maker, folded to the families above ("redmi" → "xiaomi"). */
    fun maker(): String = when (val m = Build.MANUFACTURER.lowercase()) {
        "redmi", "poco" -> "xiaomi"
        "realme", "oplus" -> "oppo"
        "iqoo" -> "vivo"
        "honor" -> "huawei"
        else -> m
    }

    /**
     * Opens this phone's background-start screen, or the app's own system
     * settings page when there is none (or it moved). Returns which one.
     */
    fun openAutostartSettings(context: Context): String {
        for ((pkg, cls) in autostartScreens[maker()].orEmpty()) {
            try {
                context.startActivity(
                    Intent().setComponent(ComponentName(pkg, cls))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                return "maker"
            } catch (_: Exception) {
                // Not on this OS version, or not exported; try the next.
            }
        }
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", context.packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        return "app"
    }
}

/** The health-check alarm going off; may cold-start the process. */
class ReliabilityTestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ReliabilityTest.onFired(context)
    }
}
