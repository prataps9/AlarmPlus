package com.alarmplus.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONArray
import org.json.JSONObject

/**
 * Registers location alarms with the OS geofencing service, so an arrival is
 * noticed with Alarm+ closed. Before this, arrival was only detected by a
 * position stream inside the running app.
 *
 * The OS forgets geofences on reboot, so the last set is kept in prefs and
 * registered again by [GeofenceBootReceiver].
 */
object GeofenceManager {

    private const val TAG = "GeofenceManager"
    private const val PREFS = "alarmplus_geofences"
    private const val KEY = "fences"

    /**
     * Replaces every registered geofence with [fencesJson], a JSON array of
     * `{id, lat, lng, radius}`. [done] gets whether the OS accepted them:
     * false without "Allow all the time" location access on Android 10+,
     * where only the in-app check works.
     */
    fun sync(context: Context, fencesJson: String, done: (Boolean) -> Unit) {
        val appContext = context.applicationContext
        appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, fencesJson).apply()
        register(appContext, fencesJson, done)
    }

    /** Registers the stored set again (after a reboot or an app update). */
    fun restore(context: Context, done: () -> Unit) {
        val appContext = context.applicationContext
        val stored = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)
        if (stored == null) {
            done()
            return
        }
        register(appContext, stored) { done() }
    }

    fun hasAccess(context: Context): Boolean {
        fun granted(p: String) =
            context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
        if (!granted(Manifest.permission.ACCESS_FINE_LOCATION)) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    }

    @SuppressLint("MissingPermission") // checked by hasAccess()
    private fun register(context: Context, fencesJson: String, done: (Boolean) -> Unit) {
        val client = LocationServices.getGeofencingClient(context)
        val intent = pendingIntent(context)
        val fences = parse(fencesJson)

        client.removeGeofences(intent).addOnCompleteListener {
            if (fences.isEmpty()) {
                done(true)
                return@addOnCompleteListener
            }
            if (!hasAccess(context)) {
                done(false)
                return@addOnCompleteListener
            }
            val request = GeofencingRequest.Builder()
                // Already inside when it's set: ring, as the in-app check does.
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofences(fences)
                .build()
            try {
                client.addGeofences(request, intent)
                    .addOnSuccessListener { done(true) }
                    .addOnFailureListener {
                        Log.w(TAG, "Geofences not registered", it)
                        done(false)
                    }
            } catch (e: SecurityException) {
                Log.w(TAG, "Geofences not registered", e)
                done(false)
            }
        }
    }

    private fun parse(json: String): List<Geofence> {
        val array = try {
            JSONArray(json)
        } catch (_: Exception) {
            return emptyList()
        }
        // The OS allows 100 per app.
        return (0 until minOf(array.length(), 100)).mapNotNull { i ->
            val o: JSONObject = array.optJSONObject(i) ?: return@mapNotNull null
            val id = o.optString("id")
            if (id.isEmpty()) return@mapNotNull null
            Geofence.Builder()
                .setRequestId(id)
                .setCircularRegion(
                    o.optDouble("lat"),
                    o.optDouble("lng"),
                    o.optDouble("radius", 200.0).toFloat().coerceAtLeast(100f),
                )
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                .build()
        }
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, GeofenceReceiver::class.java)
        // Mutable: the geofencing service adds the event to the intent.
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }
}
