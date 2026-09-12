package com.alarmplus.app

import android.content.Context
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi

/**
 * Quick Settings tile for arming/disarming the next alarm from the shade.
 *
 * Reads the same values `WidgetSyncService` writes for the home-screen widget,
 * so the tile and the widget can never disagree about what the next alarm is.
 */
@RequiresApi(Build.VERSION_CODES.N)
class AlarmTileService : TileService() {

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onClick() {
        super.onClick()

        val apply = Runnable {
            val delivered =
                WidgetCommandBridge.dispatch(this, WidgetCommandBridge.CMD_TOGGLE_NEXT)
            if (!delivered) WidgetCommandBridge.launchApp(this)

            // Optimistic flip so the tile feels instant; Dart's next sync
            // corrects it if the command didn't land.
            qsTile?.let { tile ->
                tile.state = if (tile.state == Tile.STATE_ACTIVE) {
                    Tile.STATE_INACTIVE
                } else {
                    Tile.STATE_ACTIVE
                }
                tile.updateTile()
            }
        }

        // Toggling writes alarm state, so require the device to be unlocked.
        if (isSecure) {
            unlockAndRun(apply)
        } else {
            apply.run()
        }
    }

    private fun refreshTile() {
        val tile = qsTile ?: return
        val prefs = getSharedPreferences(
            WidgetCommandBridge.PREFS,
            Context.MODE_PRIVATE,
        )

        // home_widget stores its values in the same Flutter prefs file.
        val nextAlarm = prefs.getString("flutter.next_alarm", null)
        val enabled = prefs.getBoolean("flutter.next_alarm_enabled", false)
        val hasAlarm = !nextAlarm.isNullOrEmpty() && nextAlarm != "No alarm set"

        tile.label = "Alarm+"
        tile.subtitleCompat = if (hasAlarm) nextAlarm else "No alarm set"
        tile.state = when {
            !hasAlarm -> Tile.STATE_UNAVAILABLE
            enabled -> Tile.STATE_ACTIVE
            else -> Tile.STATE_INACTIVE
        }
        tile.updateTile()
    }

    /** Subtitle is API 29+; below that the label carries everything. */
    private var Tile.subtitleCompat: CharSequence?
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) subtitle else null
        set(value) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) subtitle = value
        }
}
