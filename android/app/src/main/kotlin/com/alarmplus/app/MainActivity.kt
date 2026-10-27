package com.alarmplus.app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    companion object {
        const val METHOD_CHANNEL = "alarmplus/alarm_controls"
        const val ENGINE_ID = "main_engine"
        private const val REQ_PICK_RINGTONE = 1001
    }

    private var ringtoneResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over the lock screen so a ringing alarm is visible at wake-up.
        // The keyguard is deliberately not dismissed here: on a secure lock
        // that put the PIN pad over the ring screen. Dart calls
        // "ringScreenClosed" once the alarm is dealt with instead.
        setShowOverLockScreen(true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A later alarm reopening the running activity (singleTop) after
        // "ringScreenClosed" turned this off must still show over the lock.
        setShowOverLockScreen(true)
    }

    private fun setShowOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    /** Leaves the lock screen: the user unlocks to carry on into the app. */
    private fun dismissKeyguard() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val km = getSystemService(KEYGUARD_SERVICE) as? KeyguardManager ?: return
            km.requestDismissKeyguard(this, null)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Widget/tile taps and the ring service look the engine up here; left
        // cached after the activity is gone, they "delivered" commands to a
        // destroyed engine and the taps were lost.
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(ENGINE_ID) === flutterEngine) cache.remove(ENGINE_ID)
        super.cleanUpFlutterEngine(flutterEngine)
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
                    "ringScreenShown" -> {
                        setShowOverLockScreen(true)
                        result.success(null)
                    }
                    "ringScreenClosed" -> {
                        setShowOverLockScreen(false)
                        dismissKeyguard()
                        result.success(null)
                    }
                    "cacheRingtone" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrEmpty()) {
                            result.success(null)
                        } else {
                            Thread {
                                val path = cacheRingtone(uri)
                                runOnUiThread { result.success(path) }
                            }.start()
                        }
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

    /**
     * Copies a picked content:// sound into app storage so the alarm plugin
     * can play it from a file path, even when this process was dead at ring
     * time. Returns the file's absolute path, or null if it can't be read.
     */
    private fun cacheRingtone(uriString: String): String? {
        return try {
            val uri = Uri.parse(uriString)
            val digest = MessageDigest.getInstance("SHA-1")
                .digest(uriString.toByteArray())
                .joinToString("") { "%02x".format(it) }
            val ext = contentResolver.getType(uri)
                ?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
                ?: "snd"
            val dir = File(filesDir, "ringtones").apply { mkdirs() }
            val file = File(dir, "$digest.$ext")
            if (file.exists() && file.length() > 0) return file.absolutePath

            // Copy to a temp file first so a failed copy never leaves a
            // truncated file that the size check above would reuse.
            val tmp = File(dir, "$digest.$ext.tmp")
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { inp -> tmp.outputStream().use { out -> inp.copyTo(out) } }
            if (tmp.length() <= 0 || !tmp.renameTo(file)) {
                tmp.delete()
                return null
            }
            file.absolutePath
        } catch (_: Exception) {
            null
        }
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
