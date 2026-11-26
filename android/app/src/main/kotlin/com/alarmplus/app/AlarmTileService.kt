package com.alarmplus.app

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Quick Settings tile for arming/disarming the next alarm from the shade.
 *
 * Reads the same values `WidgetSyncService` writes for the home-screen widget,
 * so the tile and the widget can never disagree about what the next alarm is.
 */
@RequiresApi(Build.VERSION_CODES.N)
class AlarmTileService : TileService() {

    companion object {
        /** Asks the system to rebind the tile so it re-reads fresh values. */
        fun requestRefresh(context: Context) {
            try {
                TileService.requestListeningState(
                    context,
                    ComponentName(context, AlarmTileService::class.java)
                )
            } catch (_: Exception) {
                // Best effort: the tile re-reads on its next onStartListening.
            }
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        refreshTile()
    }

    override fun onClick() {
        super.onClick()

        val apply = Runnable {
            val delivered =
                WidgetCommandBridge.dispatch(this, WidgetCommandBridge.CMD_TOGGLE_NEXT)
            if (!delivered) launchApp()

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

    /**
     * A tile can't start activities directly from the background on API 34+;
     * it has to hand the system a PendingIntent and let it collapse the shade.
     */
    private fun launchApp() {
        val intent = WidgetCommandBridge.launchIntent(this) ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startActivityAndCollapse(
                    PendingIntent.getActivity(
                        this,
                        0,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        } catch (_: Exception) {
            // The command is queued either way; it drains on the next launch.
        }
    }

    private fun refreshTile() {
        val tile = qsTile ?: return

        // home_widget keeps its values in its own prefs file
        // ("HomeWidgetPreferences"), unprefixed. Reading FlutterSharedPreferences
        // with "flutter." keys found nothing, so the tile was always unavailable.
        val prefs = HomeWidgetPlugin.getData(this)
        val nextAlarm = prefs.getString("next_alarm", null)
        val enabled = prefs.getBoolean("next_alarm_enabled", false)
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
