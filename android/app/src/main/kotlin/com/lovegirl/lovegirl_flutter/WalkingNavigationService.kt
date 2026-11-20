package com.lovegirl.lovegirl_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.model.CameraPosition
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.amap.api.maps.model.Polyline
import com.amap.api.maps.model.PolylineOptions
import com.amap.api.navi.AMapNavi
import com.amap.api.navi.AMapNaviView
import com.amap.api.navi.AmapRouteActivity
import com.amap.api.navi.INaviInfoCallback
import com.amap.api.navi.enums.AMapNaviViewShowMode
import com.amap.api.navi.model.AMapCalcRouteResult
import com.amap.api.navi.model.AMapNaviLocation

class WalkingNavigationActivity : AmapRouteActivity() {
    private var navigationView: AMapNaviView? = null
    private var routeLine: Polyline? = null
    private var renderedPoints = emptyList<LatLng>()
    private var overviewFitAttempts = 0
    private val renderRoute = Runnable { updateRouteLine() }
    private val fitRoute = Runnable { fitRouteOverview() }
    private val overviewListener = object : AMap.OnCameraChangeListener {
        override fun onCameraChange(position: CameraPosition?) = Unit
        override fun onCameraChangeFinish(position: CameraPosition?) {
            if (navigationView?.isRouteOverviewNow != true) {
                overviewFitAttempts = 0
            } else if (position != null && position.zoom < 12f) {
                scheduleRouteOverview()
            }
        }
    }

    override fun onNaviViewLoaded() {
        super.onNaviViewLoaded()
        scheduleRouteLine()
    }

    override fun onStartNavi(type: Int) {
        super.onStartNavi(type)
        scheduleRouteLine()
    }

    override fun onNaviViewShowMode(showMode: Int) {
        super.onNaviViewShowMode(showMode)
        window.decorView.removeCallbacks(fitRoute)
        if (showMode == AMapNaviViewShowMode.SHOW_MODE_DISPLAY_OVERVIEW) {
            overviewFitAttempts = 0
            scheduleRouteOverview()
        }
    }

    override fun onCalculateRouteSuccess(routeIds: IntArray?) {
        super.onCalculateRouteSuccess(routeIds)
        scheduleRouteLine()
    }

    override fun onCalculateRouteSuccess(result: AMapCalcRouteResult?) {
        super.onCalculateRouteSuccess(result)
        scheduleRouteLine()
    }

    private fun scheduleRouteLine() {
        window.decorView.removeCallbacks(renderRoute)
        window.decorView.post(renderRoute)
    }

    private fun updateRouteLine() {
        if (isFinishing || isDestroyed) return
        val view = navigationView ?: findNavigationView(window.decorView) ?: return
        val map = view.map ?: return
        if (navigationView == null) {
            view.viewOptions = view.viewOptions.apply {
                setLeaderLineEnabled(Color.TRANSPARENT)
                setTilt(0)
                setAutoChangeZoom(false)
                setAutoDisplayOverview(false)
            }
            map.showBuildings(false)
            navigationView = view
            map.addOnCameraChangeListener(overviewListener)
        }

        val points = AMapNavi.getInstance(applicationContext).naviPath?.coordList
            .orEmpty()
            .filter { it.latitude in -90.0..90.0 && it.longitude in -180.0..180.0 &&
                (it.latitude != 0.0 || it.longitude != 0.0) }
            .map { LatLng(it.latitude, it.longitude) }
        if (points.size < 2 || points.all { it == points.first() }) return
        if (points != renderedPoints) {
            if (routeLine == null) {
                routeLine = map.addPolyline(PolylineOptions().addAll(points)
                    .width(8 * resources.displayMetrics.density)
                    .color(Color.rgb(22, 112, 232)).zIndex(25f))
            } else {
                routeLine?.points = points
            }
            renderedPoints = points
            Log.i("WalkingNavigation", "Displayed SDK walking route (${points.size} points)")
            if (view.isRouteOverviewNow) {
                overviewFitAttempts = 0
                scheduleRouteOverview()
            }
        }
    }

    private fun scheduleRouteOverview() {
        if (overviewFitAttempts >= 2) return
        window.decorView.removeCallbacks(fitRoute)
        window.decorView.postDelayed(fitRoute, 160)
    }

    private fun fitRouteOverview() {
        val view = navigationView ?: return
        if (isFinishing || isDestroyed || !view.isRouteOverviewNow ||
            renderedPoints.size < 2 || view.width == 0 || view.height == 0) return
        val bounds = LatLngBounds.builder()
        renderedPoints.forEach { bounds.include(it) }
        val map = view.map ?: return
        overviewFitAttempts++
        map.stopAnimation()
        map.moveCamera(CameraUpdateFactory.newLatLngBounds(
            bounds.build(), view.width, view.height, view.width / 5
        ))
        Log.i("WalkingNavigation", "Fitted the walking route overview ($overviewFitAttempts)")
    }

    private fun findNavigationView(root: View): AMapNaviView? {
        if (root is AMapNaviView) return root
        if (root is ViewGroup) {
            for (index in 0 until root.childCount) {
                findNavigationView(root.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    override fun onDestroy() {
        window.decorView.removeCallbacks(renderRoute)
        window.decorView.removeCallbacks(fitRoute)
        navigationView?.map?.removeOnCameraChangeListener(overviewListener)
        routeLine?.remove()
        if (!isChangingConfigurations) {
            stopService(Intent(this, WalkingNavigationService::class.java))
        }
        super.onDestroy()
    }
}

internal class WalkingNavigationCallback(private val context: Context) : INaviInfoCallback {
    private val service = Intent(context, WalkingNavigationService::class.java)

    override fun onStartNavi(type: Int) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(service)
            } else {
                context.startService(service)
            }
        } catch (error: RuntimeException) {
            Log.w("WalkingNavigation", "Could not keep navigation active in background", error)
            android.os.Handler(context.mainLooper).post {
                Toast.makeText(context, "请保持导航页面打开，以继续接收语音提示", Toast.LENGTH_LONG).show()
            }
        }
    }

    override fun onInitNaviFailure() {
        context.stopService(service)
    }

    override fun onArriveDestination(arrived: Boolean) {
        if (arrived) context.stopService(service)
    }

    override fun onExitPage(type: Int) {
        context.stopService(service)
    }

    override fun onGetNavigationText(text: String?) = Unit
    override fun onLocationChange(location: AMapNaviLocation?) = Unit
    override fun onCalculateRouteSuccess(routeIds: IntArray?) = Unit
    override fun onCalculateRouteFailure(errorCode: Int) = Unit
    override fun onStopSpeaking() = Unit
    override fun onReCalculateRoute(type: Int) = Unit
    override fun onStrategyChanged(strategy: Int) = Unit
    override fun onArrivedWayPoint(index: Int) = Unit
    override fun onMapTypeChanged(type: Int) = Unit
    override fun onNaviDirectionChanged(direction: Int) = Unit
    override fun onDayAndNightModeChanged(mode: Int) = Unit
    override fun onBroadcastModeChanged(mode: Int) = Unit
    override fun onScaleAutoChanged(enabled: Boolean) = Unit
    override fun getCustomMiddleView(): View? = null
    override fun getCustomNaviView(): View? = null
    override fun getCustomNaviBottomView(): View? = null
}

class WalkingNavigationService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channel = "lovegirl_walking_navigation"
        val builder =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                getSystemService(NotificationManager::class.java).createNotificationChannel(
                    NotificationChannel(channel, "步行导航", NotificationManager.IMPORTANCE_LOW)
                )
                Notification.Builder(this, channel)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            builder.setContentIntent(PendingIntent.getActivity(
                this, 0, launch, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            ))
        }
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("LoveGirl 正在步行导航")
            .setContentText("点击返回导航")
            .setOngoing(true)
            .build()
        try {
            startForeground(43000, notification)
        } catch (error: RuntimeException) {
            Log.w("WalkingNavigation", "Could not start the navigation notification", error)
            stopSelf(startId)
        }
        return START_NOT_STICKY
    }
}
