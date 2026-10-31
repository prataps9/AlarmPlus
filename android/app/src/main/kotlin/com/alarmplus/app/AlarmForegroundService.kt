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
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.PowerManager
import android.view.KeyEvent
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
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
        const val EXTRA_HARDCORE = "hardcore"
        const val EXTRA_SNOOZE_MINUTES = "snooze_minutes"
        const val METHOD_CHANNEL = "alarmplus/alarm_controls"
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var actionReceiver: BroadcastReceiver? = null
    private var alarmId: Int = 0
    private var hardcore: Boolean = false
    private var snoozeMinutes: Int = 5
    private var ringtone: Ringtone? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // A null intent is a START_STICKY restart after the process died:
        // the alarm it was ringing for is gone with it, and carrying on as
        // alarm 0 left a permanent "Alarm ringing" notification.
        if (intent == null || intent.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val newAlarmId = intent.getIntExtra(EXTRA_ALARM_ID, 0)
        if (newAlarmId <= 0) {
            // startForegroundService() still has to be answered with
            // startForeground(), even for a start that is ignored.
            startForeground(NOTIFICATION_ID, buildNotification(alarmId))
            if (alarmId <= 0) {
                stopSelf()
                return START_NOT_STICKY
            }
            return START_STICKY
        }
        alarmId = newAlarmId
        hardcore = intent.getBooleanExtra(EXTRA_HARDCORE, false)
        snoozeMinutes = intent.getIntExtra(EXTRA_SNOOZE_MINUTES, 5)

        startForeground(NOTIFICATION_ID, buildNotification(alarmId))
        // A repeat start (a second alarm, a notification tap, a cold-start
        // replay) used to overwrite these without releasing them; the old
        // looping ringtone kept sounding after Stop and the old media
        // session kept turning volume keys into snoozes.
        stopNativeRingtone()
        releaseWakeLock()
        unregisterVolumeReceiverSafe()
        unregisterActionReceiverSafe()
        stopMediaSession()
        acquireWakeLock()
        playNativeRingtoneIfSet(alarmId)
        registerVolumeReceiver()
        registerActionReceiver()
        startMediaSession()

        // START_STICKY restarts this service if the system kills it while an alarm is active
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Only Hardcore alarms fight being swiped away; a normal alarm
        // swiped away is the user's choice. The Flutter engine went with the
        // task, so nothing would ever stop the native ringtone: stop here.
        if (!hardcore) {
            stopNativeRingtone()
            stopSelf()
            super.onTaskRemoved(rootIntent)
            return
        }
        val restartIntent = Intent(applicationContext, AlarmForegroundService::class.java).apply {
            action = ACTION_START
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_HARDCORE, true)
            putExtra(EXTRA_SNOOZE_MINUTES, snoozeMinutes)
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
        stopMediaSession()
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
            // Ringtone.setLooping is API 28; calling it below that throws
            // NoSuchMethodError, which the catch below doesn't cover.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ringtone?.isLooping = true
            }
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

        // There is deliberately no "Stop" action: dismissing from the
        // notification skipped the wake challenge. "Open" goes to the ring
        // screen, where the challenge has to be solved.
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Alarm ringing")
            .setContentText("Open Alarm+ and beat the challenge to stop it")
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(0xFFEF4444.toInt())
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPi, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(fullScreenPi)
            // Android 16 Live Updates: a red "Ringing" capsule in the status
            // bar (Notification.EXTRA_REQUEST_PROMOTED_ONGOING and
            // EXTRA_SHORT_CRITICAL_TEXT). Older versions ignore the extras.
            .addExtras(Bundle().apply {
                putBoolean("android.requestPromotedOngoing", true)
                putString("android.shortCriticalText", "Ringing")
            })
        if (!hardcore) {
            builder.addAction(
                android.R.drawable.ic_media_pause,
                "Snooze $snoozeMinutes min",
                snoozePi
            )
        }
        builder.addAction(android.R.drawable.ic_menu_view, "Open", fullScreenPi)
        return builder.build()
    }

    private fun createNotificationChannel() {
        // Channels are API 26+; minSdk is 24.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
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

    // ── MediaSession volume capture ─────────────────────────────────────────

    /**
     * Claims the volume keys while the alarm rings so pressing either one
     * snoozes instead of changing a stream.
     *
     * The ACTION_MEDIA_BUTTON receiver below stays as a fallback: key routing
     * is OEM-specific, and losing the snooze gesture entirely would be worse
     * than handling the same press twice (both paths are idempotent — they
     * send the same snooze to Dart, which ignores a repeat).
     */
    private fun startMediaSession() {
        try {
            val session = MediaSession(this, "AlarmPlusRing")

            // A session only receives volume callbacks while it looks like
            // it's actively playing something.
            session.setPlaybackState(
                PlaybackState.Builder()
                    .setState(PlaybackState.STATE_PLAYING, 0L, 1.0f)
                    .setActions(PlaybackState.ACTION_STOP)
                    .build()
            )

            session.setPlaybackToRemote(
                object : VolumeProvider(VOLUME_CONTROL_ABSOLUTE, 100, 50) {
                    override fun onAdjustVolume(direction: Int) {
                        if (direction != 0) sendSnoozeToFlutter()
                    }

                    override fun onSetVolumeTo(volume: Int) {
                        sendSnoozeToFlutter()
                    }
                }
            )

            session.isActive = true
            mediaSession = session
        } catch (_: Exception) {
            // Fallback receiver still covers the common case.
        }
    }

    private fun stopMediaSession() {
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
        } catch (_: Exception) {}
        mediaSession = null
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
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    ACTION_SNOOZE_FROM_NOTIFICATION -> sendSnoozeToFlutter()
                    ACTION_STOP_FROM_NOTIFICATION   -> sendStopToFlutter()
                }
            }
        }
        actionReceiver = receiver
        val filter = IntentFilter().apply {
            addAction(ACTION_SNOOZE_FROM_NOTIFICATION)
            addAction(ACTION_STOP_FROM_NOTIFICATION)
        }
        // Only our own notification's PendingIntents send these. Exported,
        // any app could broadcast them and snooze or stop the alarm.
        // ContextCompat also protects pre-33 devices via a signature
        // permission.
        ContextCompat.registerReceiver(
            this,
            receiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
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
            // Null once MainActivity has torn its engine down; a call into a
            // destroyed engine would just vanish.
            val engine = WidgetCommandBridge.liveEngine() ?: return
            MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
                .invokeMethod(method, arg)
        } catch (_: Exception) {}
    }
}
