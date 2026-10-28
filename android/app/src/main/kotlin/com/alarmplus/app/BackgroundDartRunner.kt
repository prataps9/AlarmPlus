package com.alarmplus.app

import android.content.BroadcastReceiver
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.gdelataillade.alarm.alarm.AlarmPlugin
import com.gdelataillade.alarm.generated.AlarmTriggerApi
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Runs a short piece of Dart work (`backgroundMain` in main.dart) for a
 * broadcast that arrives while Alarm+ isn't open: a timezone change, a
 * geofence arrival. Alarms live in Hive, which only Dart can read, so the
 * work can't be done natively.
 *
 * Only used when the app's own engine isn't running; when it is, the
 * receivers hand the event to that engine instead, so two isolates never
 * have the Hive boxes open at once. Tasks run one at a time.
 */
object BackgroundDartRunner {

    private const val TAG = "BackgroundDartRunner"
    private const val CHANNEL = "alarmplus/background"
    private const val ENTRYPOINT = "backgroundMain"

    /** A receiver's goAsync() window is ~60 s in the background; stay well inside it. */
    private const val TIMEOUT_MS = 25_000L

    private class Task(
        val args: List<String>,
        val pending: BroadcastReceiver.PendingResult?,
    )

    private val main = Handler(Looper.getMainLooper())
    private val queue = ArrayDeque<Task>()
    private var engine: FlutterEngine? = null
    private var current: Task? = null
    private var timeout: Runnable? = null

    /**
     * Hands [task] to the app's running engine as a `NativeControls` call
     * (with [args] as the argument list), or, when the app isn't running,
     * runs it in a background engine. Finishes [pending] either way.
     */
    fun dispatch(
        context: Context,
        task: String,
        args: List<String>,
        pending: BroadcastReceiver.PendingResult?,
    ) {
        val live = WidgetCommandBridge.liveEngine()
        if (live == null) {
            run(context, listOf(task) + args, pending)
            return
        }
        try {
            MethodChannel(live.dartExecutor.binaryMessenger, MainActivity.METHOD_CHANNEL)
                .invokeMethod(task, args)
        } catch (e: Exception) {
            Log.e(TAG, "Could not deliver $task to the app", e)
        }
        pending?.finish()
    }

    /**
     * Queues [args] (the task name first) for `backgroundMain`. [pending]
     * comes from the caller's goAsync() and is finished when Dart is done.
     */
    fun run(context: Context, args: List<String>, pending: BroadcastReceiver.PendingResult?) {
        val appContext = context.applicationContext
        main.post {
            queue.addLast(Task(args, pending))
            if (current == null) startNext(appContext)
        }
    }

    private fun startNext(context: Context) {
        val task = queue.removeFirstOrNull() ?: return
        // The app was opened while this waited: hand it over instead, so
        // Hive is never open in two isolates.
        if (WidgetCommandBridge.liveEngine() != null) {
            dispatch(context, task.args.first(), task.args.drop(1), task.pending)
            startNext(context)
            return
        }
        current = task
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)

            val e = FlutterEngine(context)
            engine = e
            MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "done" -> {
                            result.success(null)
                            main.post { finish(context, task) }
                        }
                        // The same live-countdown calls MainActivity answers, for
                        // a task that changed the next alarm with the app closed.
                        "liveAlarmSync" -> {
                            LiveActivity.syncAlarm(context, call.argument<String>("ring"))
                            result.success(null)
                        }
                        "liveTimerSync" -> {
                            LiveActivity.syncTimer(
                                context,
                                call.argument<Number>("endMs")?.toLong() ?: 0L,
                                call.argument<String>("title") ?: "Timer",
                                call.argument<String>("text") ?: "",
                            )
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            timeout = Runnable { finish(context, task) }.also { main.postDelayed(it, TIMEOUT_MS) }
            e.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), ENTRYPOINT),
                task.args,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Could not start background task ${task.args}", e)
            finish(context, task)
        }
    }

    private fun finish(context: Context, task: Task) {
        // The timeout and "done" both land here; only the first counts.
        if (current !== task) return
        timeout?.let { main.removeCallbacks(it) }
        timeout = null
        current = null
        engine?.destroy()
        engine = null
        // The alarm plugin keeps one static callback for "an alarm rang";
        // attaching and destroying this engine replaced it and then cleared
        // it. If the app's engine is up, point it back there, or the app
        // would never hear about the next alarm.
        WidgetCommandBridge.liveEngine()?.let {
            AlarmPlugin.alarmTriggerApi = AlarmTriggerApi(it.dartExecutor.binaryMessenger)
        }
        try {
            task.pending?.finish()
        } catch (e: IllegalStateException) {
            Log.w(TAG, "Broadcast already finished", e)
        }
        startNext(context)
    }
}
