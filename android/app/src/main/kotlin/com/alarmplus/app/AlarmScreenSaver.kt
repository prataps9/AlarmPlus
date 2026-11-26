package com.alarmplus.app

import android.app.AlarmManager
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.service.dreams.DreamService
import android.text.format.DateFormat
import android.view.View
import android.widget.TextView
import java.util.Date

/**
 * Alarm+ as an Android screen saver (Settings → Display → Screen saver), like
 * the stock Clock: a dim clock with the date and the next alarm, shown while
 * the phone charges or docks. The block drifts a little every minute so the
 * same pixels aren't lit all night (burn-in), and the screen stays dim.
 */
class AlarmScreenSaver : DreamService() {

    private val handler = Handler(Looper.getMainLooper())
    private var block: View? = null
    private var nextAlarm: TextView? = null
    private var step = 0

    private val tick = object : Runnable {
        override fun run() {
            refreshNextAlarm()
            drift()
            handler.postDelayed(this, 60_000L)
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isInteractive = false
        isFullscreen = true
        // Dim, for a dark bedroom.
        isScreenBright = false
        setContentView(R.layout.screen_saver)
        block = findViewById(R.id.saver_block)
        nextAlarm = findViewById(R.id.saver_next_alarm)
    }

    override fun onDreamingStarted() {
        super.onDreamingStarted()
        handler.post(tick)
    }

    override fun onDreamingStopped() {
        handler.removeCallbacks(tick)
        super.onDreamingStopped()
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacks(tick)
        super.onDetachedFromWindow()
    }

    /** The next alarm the system knows about (Alarm+ registers its own). */
    private fun refreshNextAlarm() {
        val view = nextAlarm ?: return
        val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val next = am?.nextAlarmClock
        if (next == null) {
            view.visibility = View.GONE
            return
        }
        val skeleton = if (DateFormat.is24HourFormat(this)) "EEE HH:mm" else "EEE h:mm a"
        val pattern = DateFormat.getBestDateTimePattern(resources.configuration.locales[0], skeleton)
        view.text = "⏰  " + DateFormat.format(pattern, Date(next.triggerTime))
        view.visibility = View.VISIBLE
    }

    /** Moves the clock a few dp each minute, in a slow loop. */
    private fun drift() {
        val v = block ?: return
        val d = resources.displayMetrics.density
        val offsets = arrayOf(0 to 0, 24 to 16, -20 to 32, 16 to -24, -24 to -12)
        val (x, y) = offsets[step % offsets.size]
        step++
        v.animate().translationX(x * d).translationY(y * d).setDuration(2_000L).start()
    }
}
