package com.alarmplus.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "alarmplus/alarm_controls"
        const val ENGINE_ID = "main_engine"
        private const val REQ_PICK_RINGTONE = 1001
    }

    private var ringtoneResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        val km = getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            km.requestDismissKeyguard(this, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarmService" -> {
                        val alarmId = call.argument<Int>("alarmId") ?: 0
                        val hardcore = call.argument<Boolean>("hardcore") ?: false
                        val snoozeMinutes = call.argument<Int>("snoozeMinutes") ?: 5
                        startAlarmForegroundService(alarmId, hardcore, snoozeMinutes)
                        result.success(null)
                    }
                    "stopAlarmService" -> {
                        stopAlarmForegroundService()
                        result.success(null)
                    }
                    "pickRingtone" -> {
                        val currentUri = call.argument<String>("currentUri")
                        pickRingtone(currentUri, result)
                    }
                    "getRingtoneTitle" -> {
                        val uri = call.argument<String>("uri")
                        result.success(getRingtoneTitle(uri))
                    }
                    "getDefaultAlarmUri" -> {
                        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        result.success(uri?.toString())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickRingtone(currentUri: String?, result: MethodChannel.Result) {
        ringtoneResult = result
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Choose Alarm Tone")
            if (currentUri != null) {
                putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(currentUri))
            } else {
                putExtra(
                    RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                )
            }
        }
        startActivityForResult(intent, REQ_PICK_RINGTONE)
    }

    private fun getRingtoneTitle(uri: String?): String {
        if (uri == null) return "Default Alarm"
        return try {
            val ringtone = RingtoneManager.getRingtone(this, Uri.parse(uri))
            ringtone?.getTitle(this) ?: "Unknown"
        } catch (e: Exception) {
            "Unknown"
        }
    }

    @Deprecated("Using legacy onActivityResult for ringtone picker compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_RINGTONE) {
            val pending = ringtoneResult
            ringtoneResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri = data.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                pending?.success(uri?.toString())
            } else {
                pending?.success(null)
            }
        }
    }

    private fun startAlarmForegroundService(alarmId: Int, hardcore: Boolean, snoozeMinutes: Int) {
        val intent = Intent(this, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_START
            putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
            putExtra(AlarmForegroundService.EXTRA_HARDCORE, hardcore)
            putExtra(AlarmForegroundService.EXTRA_SNOOZE_MINUTES, snoozeMinutes)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopAlarmForegroundService() {
        val intent = Intent(this, AlarmForegroundService::class.java)
        stopService(intent)
    }
}
