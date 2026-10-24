package com.lovegirl.lovegirl_flutter

import android.os.Build
import android.os.Bundle
import com.amap.api.location.AMapLocationClient
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.CoordinateConverter
import com.amap.api.maps.model.LatLng
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        MapsInitializer.updatePrivacyShow(applicationContext, true, true)
        MapsInitializer.updatePrivacyAgree(applicationContext, true)
        MapsInitializer.setApiKey("2209d350da6804c16673f5c36d52f64b")
        AMapLocationClient.updatePrivacyShow(applicationContext, true, true)
        AMapLocationClient.updatePrivacyAgree(applicationContext, true)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lovegirl/device"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "gpsToAmap" -> {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    if (lat == null || lng == null || !lat.isFinite() || !lng.isFinite() ||
                        lat !in -90.0..90.0 || lng !in -180.0..180.0) {
                        result.error("INVALID_COORDINATE", "无效的位置", null)
                    } else {
                        try {
                            val point = CoordinateConverter(applicationContext)
                                .from(CoordinateConverter.CoordType.GPS)
                                .coord(LatLng(lat, lng)).convert()
                            result.success(mapOf("lat" to point.latitude, "lng" to point.longitude))
                        } catch (error: Exception) {
                            result.error("COORDINATE_CONVERSION_FAILED", "位置转换失败", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
