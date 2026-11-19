package com.lovegirl.lovegirl_flutter

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs

internal class TravelHeading(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = context.getSystemService(SensorManager::class.java)
    private val rotation = FloatArray(9)
    private val angles = FloatArray(3)
    private var events: EventChannel.EventSink? = null
    private var declination = 0.0
    private var previous: Double? = null

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        onCancel(null)
        val coordinates = arguments as? Map<*, *>
        val latitude = (coordinates?.get("latitude") as? Number)?.toFloat()
        val longitude = (coordinates?.get("longitude") as? Number)?.toFloat()
        declination = if (latitude != null && longitude != null) {
            GeomagneticField(latitude, longitude, 0f, System.currentTimeMillis())
                .declination.toDouble()
        } else 0.0
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        if (sensor == null || !sensors.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)) {
            sink.endOfStream()
            return
        }
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        sensors.unregisterListener(this)
        previous = null
        events = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE) clearHeading()
    }

    private fun clearHeading() {
        if (previous == null) return
        previous = null
        events?.success(null)
    }

    override fun onSensorChanged(event: SensorEvent) {
        val accuracy = event.values.getOrNull(4)
        if (event.accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE ||
            (accuracy != null && accuracy > .61f)) {
            clearHeading()
            return
        }
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        SensorManager.getOrientation(rotation, angles)
        // When the top edge is nearly vertical, a horizontal heading is ambiguous.
        if (abs(angles[1]) > 1.4f) {
            clearHeading()
            return
        }
        val heading = (Math.toDegrees(angles[0].toDouble()) + declination + 360) % 360
        val last = previous
        if (heading.isFinite() && (last == null || abs((heading - last + 540) % 360 - 180) >= 5)) {
            previous = heading
            events?.success(heading)
        }
    }
}
