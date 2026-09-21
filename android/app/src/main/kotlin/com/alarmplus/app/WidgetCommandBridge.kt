package com.alarmplus.app

import android.content.Context
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

    /** Reschedule anything stale — boot, timezone/clock change, app update. */
    const val CMD_RESYNC = "resync"

    const val CMD_SHOW_ALARMS = "showAlarms"
    const val CMD_DISMISS_ALARM = "dismissAlarm"

    /** Carried as a JSON object rather than a bare string: it has arguments. */
    const val CMD_SET_ALARM = "setAlarm"

    const val CMD_NEW_ALARM = "newAlarm"
    const val CMD_START_NAP = "startNap"
    const val CMD_START_FOCUS = "startFocus"

    /**
     * Delivers [command], returning true if it reached a running app. When it
     * returns false the command has been queued instead and the caller should
     * open the app so Dart can drain it.
     */
    fun dispatch(context: Context, command: String): Boolean {
        val engine = FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)
        if (engine != null) {
            return try {
                MethodChannel(
                    engine.dartExecutor.binaryMessenger,
                    MainActivity.METHOD_CHANNEL
                ).invokeMethod("widgetCommand", command)
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
     * Queues [command] without attempting live delivery.
     *
     * For the cold-start path: during MainActivity.onCreate the engine exists
     * but Dart's `main()` has not yet bound its handler, so a live call would
     * be dropped. Queued commands are drained once storage is ready.
     */
    fun queue(context: Context, command: String) = enqueue(context, command)

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
        val intent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK) }
        if (intent != null) context.startActivity(intent)
    }
}
