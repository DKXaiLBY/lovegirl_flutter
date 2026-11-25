package com.lovegirl.lovegirl_flutter

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import com.amap.api.location.AMapLocationClient
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.CoordinateConverter
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.Poi
import com.amap.api.navi.AMapNavi
import com.amap.api.navi.AmapNaviPage
import com.amap.api.navi.AmapNaviParams
import com.amap.api.navi.AmapNaviTheme
import com.amap.api.navi.AmapNaviType
import com.amap.api.navi.AmapPageType
import com.amap.api.navi.enums.NaviType
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val studyPdf by lazy { StudyPdfReader(this) }
    private val amapSdkKey by lazy {
        @Suppress("DEPRECATION")
        packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            .metaData?.getString("com.amap.api.v2.apikey").orEmpty()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        MapsInitializer.updatePrivacyShow(applicationContext, true, true)
        MapsInitializer.updatePrivacyAgree(applicationContext, true)
        if (amapSdkKey.isNotBlank()) MapsInitializer.setApiKey(amapSdkKey)
        AMapLocationClient.updatePrivacyShow(applicationContext, true, true)
        AMapLocationClient.updatePrivacyAgree(applicationContext, true)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "lovegirl/travel_heading")
            .setStreamHandler(TravelHeading(applicationContext))

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "lovegirl/device"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickStudyPdf", "readStudyPdf", "previewStudyPdf", "copyStudyPdf" -> studyPdf.handle(call, result)
                "recognizeStudyText" -> {
                    val path = call.arguments as? String
                    if (path.isNullOrBlank()) {
                        result.error("STUDY_IMAGE", "图片暂时无法读取", null)
                    } else {
                        recognizeStudyText(path, result)
                    }
                }
                "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "setAppHaptics" -> {
                    val enabled = call.arguments as? Boolean
                    if (enabled == null) {
                        result.error("HAPTICS_OPTION", "触觉设置无效", null)
                    } else {
                        window.decorView.isHapticFeedbackEnabled = enabled
                        result.success(null)
                    }
                }
                "reclaimInstalledUpdate" -> Thread {
                    try {
                        val removed = reclaimInstalledUpdate()
                        runOnUiThread { result.success(removed) }
                    } catch (_: Exception) {
                        runOnUiThread { result.error("UPDATE_CACHE", "无法回收安装包", null) }
                    }
                }.start()
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
                "startWalkingNavigation" -> {
                    val lat = call.argument<Double>("lat")
                    val lng = call.argument<Double>("lng")
                    val startLat = call.argument<Double>("startLat")
                    val startLng = call.argument<Double>("startLng")
                    val name = call.argument<String>("name")
                    if (lat == null || lng == null || lat !in -90.0..90.0 ||
                        lng !in -180.0..180.0 || name.isNullOrBlank() ||
                        (lat == 0.0 && lng == 0.0)) {
                        result.error("INVALID_DESTINATION", "下一站缺少有效位置", null)
                    } else if (startLat == null || startLng == null || startLat !in -90.0..90.0 ||
                        startLng !in -180.0..180.0 || (startLat == 0.0 && startLng == 0.0)) {
                        result.error("INVALID_ORIGIN", "暂未取得有效的当前位置", null)
                    } else {
                        try {
                            if (amapSdkKey.isBlank()) {
                                result.error("NAVIGATION_KEY_MISSING", "应用内导航暂不可用", null)
                                return@setMethodCallHandler
                            }
                            AMapNavi.setApiKey(applicationContext, amapSdkKey)
                            val start = Poi("当前位置", LatLng(startLat, startLng), "")
                            val end = Poi(name, LatLng(lat, lng), "")
                            val params = AmapNaviParams(
                                start, null, end, AmapNaviType.WALK, AmapPageType.NAVI
                            )
                                .setNaviMode(NaviType.GPS)
                                .setUseInnerVoice(true)
                                .setShowExitNaviDialog(true)
                                .setNeedDestroyDriveManagerInstanceWhenNaviExit(true)
                                .setTheme(if (call.argument<Boolean>("dark") == true)
                                    AmapNaviTheme.BLACK else AmapNaviTheme.WHITE)
                            AmapNaviPage.getInstance().showRouteActivity(
                                this,
                                params,
                                WalkingNavigationCallback(applicationContext),
                                WalkingNavigationActivity::class.java
                            )
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("NAVIGATION_START_FAILED", "步行导航暂时无法启动", null)
                        }
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

    @Deprecated("Android document picker callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == StudyPdfReader.PICK_REQUEST) studyPdf.finishPick(resultCode, data)
    }

    private fun recognizeStudyText(path: String, result: MethodChannel.Result) {
        Thread {
            try {
                val image = InputImage.fromFilePath(applicationContext, Uri.fromFile(File(path)))
                val recognizer = TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
                recognizer.process(image)
                    .addOnSuccessListener { recognized -> result.success(recognized.text) }
                    .addOnFailureListener { result.error("STUDY_OCR", "文字暂时无法识别", null) }
                    .addOnCompleteListener { recognizer.close() }
            } catch (_: Exception) {
                runOnUiThread { result.error("STUDY_IMAGE", "图片暂时无法读取", null) }
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun reclaimInstalledUpdate(): Boolean {
        val installed = packageManager.getPackageInfo(packageName, 0)
        val installedVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            installed.longVersionCode
        } else installed.versionCode.toLong()
        var removed = false
        for (apk in listOf(File(cacheDir, "LoveGirl-latest.apk"),
            File(filesDir, "app_update/LoveGirl-latest.apk"))) {
            if (!apk.isFile) continue
            val modified = apk.lastModified()
            val size = apk.length()
            val archive = packageManager.getPackageArchiveInfo(apk.path, 0) ?: continue
            if (archive.packageName != packageName) continue
            val archiveVersion = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                archive.longVersionCode
            } else archive.versionCode.toLong()
            if (archiveVersion <= installedVersion && apk.lastModified() == modified &&
                apk.length() == size && apk.delete()) removed = true
        }
        return removed
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
