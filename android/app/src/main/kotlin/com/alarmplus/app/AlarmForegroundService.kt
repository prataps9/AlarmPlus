package com.alarmplus.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class AlarmForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "alarm_plus_active"
        const val NOTIFICATION_ID = 9999
        const val ACTION_START = "alarmplus.START_ALARM_SERVICE"
        const val ACTION_STOP = "alarmplus.STOP_ALARM_SERVICE"
        const val ACTION_SNOOZE_FROM_NOTIFICATION = "alarmplus.SNOOZE_FROM_NOTIFICATION"
        const val ACTION_STOP_FROM_NOTIFICATION = "alarmplus.STOP_FROM_NOTIFICATION"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val METHOD_CHANNEL = "alarmplus/alarm_controls"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var actionReceiver: BroadcastReceiver? = null
    private var alarmId: Int = 0
    private var ringtone: Ringtone? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, 0) ?: 0

        startForeground(NOTIFICATION_ID, buildNotification(alarmId))
        acquireWakeLock()
        playNativeRingtoneIfSet(alarmId)
        registerVolumeReceiver()
        registerActionReceiver()

        // START_STICKY restarts this service if the system kills it while an alarm is active
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // User swiped app away — restart the alarm service so it keeps ringing
        val restartIntent = Intent(applicationContext, AlarmForegroundService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_ALARM_ID, alarmId)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        stopNativeRingtone()
        releaseWakeLock()
        unregisterVolumeReceiverSafe()
        unregisterActionReceiverSafe()
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Native ringtone ──────────────────────────────────────────────────────

    private fun playNativeRingtoneIfSet(id: Int) {
        // Flutter's shared_preferences prefixes keys with "flutter."
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val uriString = prefs.getString("flutter.alarm.native_ringtone.$id", null)
        if (uriString.isNullOrEmpty()) return
        try {
            val uri = Uri.parse(uriString)
            ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            // Route to the alarm stream, so the ringtone follows alarm volume
            // rather than media volume — a muted phone must still wake you.
            ringtone?.audioAttributes = alarmAudioAttributes()
            ringtone?.isLooping = true
            requestAlarmAudioFocus()
            ringtone?.play()
        } catch (_: Exception) {}
    }

    private fun stopNativeRingtone() {
        try { ringtone?.stop() } catch (_: Exception) {}
        ringtone = null
        abandonAlarmAudioFocus()
    }

    // ── Audio focus ─────────────────────────────────────────────────────────

    private fun alarmAudioAttributes(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

    /** Ducks/pauses whatever else is playing so the alarm is actually audible. */
    private fun requestAlarmAudioFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val request = AudioFocusRequest.Builder(
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE
                )
                    .setAudioAttributes(alarmAudioAttributes())
                    .build()
                audioFocusRequest = request
                am.requestAudioFocus(request)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                )
            }
        } catch (_: Exception) {}
    }

    private fun abandonAlarmAudioFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
                audioFocusRequest = null
            } else {
                @Suppress("DEPRECATION")
                am.abandonAudioFocus(null)
            }
        } catch (_: Exception) {}
    }

    // ── Notification ────────────────────────────────────────────────────────

    private fun buildNotification(alarmId: Int): Notification {
        // Full-screen intent — opens the app on lock screen
        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            putExtra(EXTRA_ALARM_ID, alarmId)
        }
        val fullScreenPi = PendingIntent.getActivity(
            this, 0, fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Snooze action
        val snoozePi = PendingIntent.getBroadcast(
            this, 1,
            Intent(ACTION_SNOOZE_FROM_NOTIFICATION).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Stop action
        val stopPi = PendingIntent.getBroadcast(
            this, 2,
            Intent(ACTION_STOP_FROM_NOTIFICATION).setPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Alarm Ringing")
            .setContentText("Tap to dismiss • Swipe for options")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPi, true)
            .addAction(android.R.drawable.ic_media_pause, "Snooze 5 min", snoozePi)
            .addAction(android.R.drawable.ic_delete, "Stop", stopPi)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(fullScreenPi)
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Active Alarm",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Shown while alarm is ringing"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
            enableVibration(false)
        }
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }

    // ── Wake lock ────────────────────────────────────────────────────────────

    private fun acquireWakeLock() {
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        wakeLock = pm.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or
            PowerManager.ACQUIRE_CAUSES_WAKEUP or
            PowerManager.ON_AFTER_RELEASE,
            "alarmplus:AlarmWakeLock"
        ).apply { acquire(10 * 60 * 1000L) }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    // ── Volume button → snooze ───────────────────────────────────────────────

    private fun registerVolumeReceiver() {
        volumeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != Intent.ACTION_MEDIA_BUTTON) return
                val event = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT) as? KeyEvent
                }
                if (event?.action == KeyEvent.ACTION_DOWN &&
                    (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN ||
                     event.keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
                    sendSnoozeToFlutter()
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_MEDIA_BUTTON).apply {
            priority = IntentFilter.SYSTEM_HIGH_PRIORITY
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(volumeReceiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(volumeReceiver, filter)
        }
    }

    private fun unregisterVolumeReceiverSafe() {
        try { volumeReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        volumeReceiver = null
    }

    // ── Notification action buttons → snooze / stop ──────────────────────────

    private fun registerActionReceiver() {
        actionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    ACTION_SNOOZE_FROM_NOTIFICATION -> sendSnoozeToFlutter()
                    ACTION_STOP_FROM_NOTIFICATION   -> sendStopToFlutter()
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(ACTION_SNOOZE_FROM_NOTIFICATION)
            addAction(ACTION_STOP_FROM_NOTIFICATION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(actionReceiver, filter, RECEIVER_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(actionReceiver, filter)
        }
    }

    private fun unregisterActionReceiverSafe() {
        try { actionReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        actionReceiver = null
    }

    // ── Flutter MethodChannel calls ──────────────────────────────────────────

    private fun sendSnoozeToFlutter() {
        invokeFlutterMethod("snooze", alarmId)
    }

    private fun sendStopToFlutter() {
        invokeFlutterMethod("stopFromNotification", alarmId)
        // Also self-stop the service so the notification disappears immediately
        stopSelf()
    }

    private fun invokeFlutterMethod(method: String, arg: Any?) {
        try {
            val engine = FlutterEngineCache.getInstance().get("main_engine")
            engine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, METHOD_CHANNEL).invokeMethod(method, arg)
            }
        } catch (_: Exception) {}
    }
}
