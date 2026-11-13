package com.lovegirl.lovegirl_flutter

import android.content.ContentValues
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
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
                "saveCreationPng" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name")
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        result.success(false)
                    } else if (bytes == null || bytes.isEmpty() || name == null ||
                        !name.matches(Regex("[A-Za-z0-9_-]{1,100}"))) {
                        result.error("INVALID_CREATION_EXPORT", "图片导出参数无效", null)
                    } else {
                        Thread {
                            try {
                                saveCreationPng(name, bytes)
                                runOnUiThread { result.success(true) }
                            } catch (_: Exception) {
                                runOnUiThread {
                                    result.error("CREATION_EXPORT_FAILED", "相册写入失败", null)
                                }
                            }
                        }.start()
                    }
                }
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

    @android.annotation.TargetApi(Build.VERSION_CODES.Q)
    private fun saveCreationPng(name: String, bytes: ByteArray) {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "$name.png")
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val images = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = contentResolver.insert(images, values) ?: error("Cannot create image")
        try {
            val output = contentResolver.openOutputStream(uri) ?: error("Cannot open image")
            output.use { it.write(bytes) }
            val published = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
            if (contentResolver.update(uri, published, null, null) != 1) {
                error("Cannot publish image")
            }
        } catch (failure: Exception) {
            runCatching { contentResolver.delete(uri, null, null) }
            throw failure
        }
    }
}
