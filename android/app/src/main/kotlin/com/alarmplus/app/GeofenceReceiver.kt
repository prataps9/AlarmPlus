package com.alarmplus.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent

/** Arrival at a location alarm's place, sent by the OS geofencing service. */
class GeofenceReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            Log.w("GeofenceReceiver", "Geofence error ${event.errorCode}")
            return
        }
        if (event.geofenceTransition != Geofence.GEOFENCE_TRANSITION_ENTER) return
        val ids = event.triggeringGeofences?.map { it.requestId }.orEmpty()
        if (ids.isEmpty()) return
        BackgroundDartRunner.dispatch(context, "geofenceEntered", ids, goAsync())
    }
}

/** The OS drops geofences on reboot; register the stored ones again. */
class GeofenceBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val pending = goAsync()
                GeofenceManager.restore(context) { pending.finish() }
            }
        }
    }
}
