package com.alarmplus.app

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/**
 * Routes an action taken outside the app — a home-screen widget button, the
 * Quick Settings tile — into Dart, where the alarm state actually lives.
 *
 * Alarms are stored in Hive, which native code can't read or write, so every
 * command has to reach Dart eventually. Two paths:
 *
 *  1. The app is alive: deliver straight over the existing method channel and
 *     it applies immediately.
 *  2. The app is not running: append the command to a queue in the same
 *     SharedPreferences file Flutter uses, and launch the app. `main()` drains
 *     the queue once storage is initialised.
 *
 * The queue is what makes this safe rather than clever: a tap is never
 * silently dropped, even if the process is gone.
 */
object WidgetCommandBridge {

    const val PREFS = "FlutterSharedPreferences"

    /** Flutter prefixes every key it owns with "flutter." */
    const val PENDING_KEY = "flutter.widget_pending_commands"

    const val CMD_TOGGLE_NEXT = "toggleNext"
    const val CMD_SNOOZE = "snooze"

    /**
     * Delivers [command], returning true if it reached a running app. When it
     * returns false the command has been queued instead and the caller should
     * open the app so Dart can drain it.
     */
    fun dispatch(context: Context, command: String): Boolean {
        val engine = liveEngine()
        if (engine != null) {
            return try {
                val appContext = context.applicationContext
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    MainActivity.METHOD_CHANNEL
                ).invokeMethod("widgetCommand", command, object : MethodChannel.Result {
                    override fun success(result: Any?) {}

                    // Dart is up but hasn't bound its handler yet (or it
                    // threw): keep the command for the next drain.
                    override fun error(code: String, message: String?, details: Any?) {
                        enqueue(appContext, command)
                    }

                    override fun notImplemented() {
                        enqueue(appContext, command)
                    }
                })
                true
            } catch (_: Exception) {
                enqueue(context, command)
                false
            }
        }

        enqueue(context, command)
        return false
    }

    /**
     * The app's engine if it is still running Dart, else null. MainActivity
     * removes it from the cache when it tears the engine down; before that,
     * a tap after backing out of the app was "delivered" to a destroyed
     * engine and silently lost.
     */
    fun liveEngine(): FlutterEngine? {
        val engine = FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)
            ?: return null
        return if (engine.dartExecutor.isExecutingDart) engine else null
    }

    /**
     * Stored as a JSON array string rather than a StringSet: Flutter's
     * SharedPreferences encodes its own types with a prefix, and a raw
     * Android StringSet written here would not be readable from Dart.
     */
    private fun enqueue(context: Context, command: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(PENDING_KEY, null)

        val array = try {
            if (existing.isNullOrEmpty()) JSONArray() else JSONArray(existing)
        } catch (_: Exception) {
            JSONArray()
        }
        array.put(command)

        prefs.edit().putString(PENDING_KEY, array.toString()).apply()
    }

    /** Opens the app so a queued command gets drained promptly. */
    fun launchApp(context: Context) {
        val intent = launchIntent(context)
        if (intent != null) context.startActivity(intent)
    }

    fun launchIntent(context: Context): Intent? =
        context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
}
