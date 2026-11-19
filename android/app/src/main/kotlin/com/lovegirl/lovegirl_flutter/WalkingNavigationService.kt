package com.lovegirl.lovegirl_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.View
import android.widget.Toast
import com.amap.api.navi.AmapRouteActivity
import com.amap.api.navi.INaviInfoCallback
import com.amap.api.navi.model.AMapNaviLocation

class WalkingNavigationActivity : AmapRouteActivity() {
    override fun onDestroy() {
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
