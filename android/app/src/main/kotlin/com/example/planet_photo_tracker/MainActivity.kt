package com.example.planet_photo_tracker

import android.os.Bundle
import com.google.android.gms.location.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.native_location"
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationRequest: LocationRequest
    private lateinit var locationCallback: LocationCallback
    private var latestLocation: android.location.Location? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize the Fused Location Provider
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        // Build a location request for continuous updates.
        // Here we request high accuracy updates every 1 second (adjust as needed)
        locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000)
            .setMinUpdateIntervalMillis(500)  // Minimum update interval
            .build()

        // Define the location callback
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                super.onLocationResult(locationResult)
                // Store the latest location continuously
                latestLocation = locationResult.lastLocation
            }
        }

        // Start continuous location updates (ensure location permissions are granted)
        try {
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, mainLooper)
        } catch (e: SecurityException) {
            // Handle the exception if permissions are not granted
            e.printStackTrace()
        }

        // Set up the method channel to handle "getLocation" calls from Flutter.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getLocation") {
                latestLocation?.let { location ->
                    val locData = mapOf(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                        "accuracy" to location.accuracy
                    )
                    result.success(locData)
                } ?: result.error("UNAVAILABLE", "Location not available", null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Stop location updates to avoid memory leaks.
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }
}
