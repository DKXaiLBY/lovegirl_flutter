package com.amap.flutter.map;

import android.content.Context;
import android.os.Bundle;
import android.view.View;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import com.amap.api.maps.AMap;
import com.amap.api.maps.AMapOptions;
import com.amap.api.maps.TextureMapView;
import com.amap.flutter.map.core.MapController;
import com.amap.flutter.map.overlays.marker.MarkersController;
import com.amap.flutter.map.overlays.polygon.PolygonsController;
import com.amap.flutter.map.overlays.polyline.PolylinesController;
import com.amap.flutter.map.utils.LogUtil;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;


/**
 * @author whm
 * @date 2020/10/27 5:49 PM
 * @mail hongming.whm@alibaba-inc.com
 * @since
 */
public class AMapPlatformView
        implements
        DefaultLifecycleObserver,
        ActivityPluginBinding.OnSaveInstanceStateListener,
        MethodChannel.MethodCallHandler,
        PlatformView {
    private static final String CLASS_NAME = "AMapPlatformView";
    private final MethodChannel methodChannel;

    private MapController mapController;
    private MarkersController markersController;
    private PolylinesController polylinesController;
    private PolygonsController polygonsController;

    private TextureMapView mapView;
    private final View fallbackView;
    private boolean mapViewCreated = false;
    private boolean mapViewResumed = false;

    private boolean disposed = false;
    private final Lifecycle lifecycle;

    private final Map<String, MyMethodCallHandler> myMethodCallHandlerMap;

    AMapPlatformView(int id,
                     Context context,
                     BinaryMessenger binaryMessenger,
                     LifecycleProvider lifecycleProvider,
                     AMapOptions options) {
        this.lifecycle = lifecycleProvider.getLifecycle();
        this.fallbackView = new AMapErrorPlatformView(context).getView();

        methodChannel = new MethodChannel(binaryMessenger, "amap_flutter_map_" + id);
        methodChannel.setMethodCallHandler(this);
        myMethodCallHandlerMap = new HashMap<String, MyMethodCallHandler>(8);

        try {
            mapView = new TextureMapView(context, options);
            ensureMapViewCreated(null);
            AMap amap = mapView.getMap();
            mapController = new MapController(methodChannel, mapView);
            markersController = new MarkersController(methodChannel, amap);
            polylinesController = new PolylinesController(methodChannel, amap);
            polygonsController = new PolygonsController(methodChannel, amap);
            initMyMethodCallHandlerMap();
            if (lifecycle != null) {
                lifecycle.addObserver(this);
            }
            ensureMapViewResumed();
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "<init>", e);
        }
    }

    private void ensureMapViewCreated(@Nullable Bundle bundle) {
        if (mapView == null || mapViewCreated) {
            return;
        }
        mapView.onCreate(bundle);
        mapViewCreated = true;
    }

    private void ensureMapViewResumed() {
        if (mapView == null || mapViewResumed) {
            return;
        }
        mapView.onResume();
        mapViewResumed = true;
    }

    private void pauseMapViewIfNecessary() {
        if (mapView == null || !mapViewResumed) {
            return;
        }
        mapView.onPause();
        mapViewResumed = false;
    }

    private void initMyMethodCallHandlerMap() {
        String[] methodIdArray = mapController.getRegisterMethodIdArray();
        if (null != methodIdArray && methodIdArray.length > 0) {
            for (String methodId : methodIdArray) {
                myMethodCallHandlerMap.put(methodId, mapController);
            }
        }

        methodIdArray = markersController.getRegisterMethodIdArray();
        if (null != methodIdArray && methodIdArray.length > 0) {
            for (String methodId : methodIdArray) {
                myMethodCallHandlerMap.put(methodId, markersController);
            }
        }

        methodIdArray = polylinesController.getRegisterMethodIdArray();
        if (null != methodIdArray && methodIdArray.length > 0) {
            for (String methodId : methodIdArray) {
                myMethodCallHandlerMap.put(methodId, polylinesController);
            }
        }

        methodIdArray = polygonsController.getRegisterMethodIdArray();
        if (null != methodIdArray && methodIdArray.length > 0) {
            for (String methodId : methodIdArray) {
                myMethodCallHandlerMap.put(methodId, polygonsController);
            }
        }
    }


    public MapController getMapController() {
        return mapController;
    }

    public MarkersController getMarkersController() {
        return markersController;
    }

    public PolylinesController getPolylinesController() {
        return polylinesController;
    }

    public PolygonsController getPolygonsController() {
        return polygonsController;
    }

    public boolean isReady() {
        return mapView != null
                && mapController != null
                && markersController != null
                && polylinesController != null
                && polygonsController != null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        LogUtil.i(CLASS_NAME, "onMethodCall==>" + call.method + ", arguments==> " + call.arguments);
        String methodId = call.method;
        if (myMethodCallHandlerMap.containsKey(methodId)) {
            myMethodCallHandlerMap.get(methodId).doMethodCall(call, result);
        } else {
            LogUtil.w(CLASS_NAME, "onMethodCall, the methodId: " + call.method + ", not implemented");
            result.notImplemented();
        }
    }


    @Override
    public void onCreate(@NonNull LifecycleOwner owner) {
        LogUtil.i(CLASS_NAME, "onCreate==>");
        try {
            if (disposed) {
                return;
            }
            ensureMapViewCreated(null);
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "onCreate", e);
        }
    }

    @Override
    public void onStart(@NonNull LifecycleOwner owner) {
        LogUtil.i(CLASS_NAME, "onStart==>");
    }

    @Override
    public void onResume(@NonNull LifecycleOwner owner) {
        LogUtil.i(CLASS_NAME, "onResume==>");
        try {
            if (disposed) {
                return;
            }
            ensureMapViewCreated(null);
            ensureMapViewResumed();
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "onResume", e);
        }
    }

    @Override
    public void onPause(@NonNull LifecycleOwner owner) {
        LogUtil.i(CLASS_NAME, "onPause==>");
        try {
            if (disposed) {
                return;
            }
            pauseMapViewIfNecessary();
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "onPause", e);
        }
    }

    @Override
    public void onStop(@NonNull LifecycleOwner owner) {
        LogUtil.i(CLASS_NAME, "onStop==>");
    }

    @Override
    public void onDestroy(@NonNull LifecycleOwner owner) {
        LogUtil.i(CLASS_NAME, "onDestroy==>");
        try {
            if (disposed) {
                return;
            }
            destroyMapViewIfNecessary();
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "onDestroy", e);
        }
    }

    @Override
    public void onSaveInstanceState(@NonNull Bundle bundle) {
        LogUtil.i(CLASS_NAME, "onDestroy==>");
        try {
            if (disposed) {
                return;
            }
            if (null != mapView) {
                mapView.onSaveInstanceState(bundle);
            }
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "onSaveInstanceState", e);
        }
    }

    @Override
    public void onRestoreInstanceState(@Nullable Bundle bundle) {
        LogUtil.i(CLASS_NAME, "onDestroy==>");
        try {
            if (disposed) {
                return;
            }
            if (!mapViewCreated && null != mapView) {
                mapView.onCreate(bundle);
                mapViewCreated = true;
            }
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "onRestoreInstanceState", e);
        }
    }


    @Override
    public View getView() {
        LogUtil.i(CLASS_NAME, "getView==>");
        if (mapView != null) {
            return mapView;
        }
        return fallbackView;
    }

    @Override
    public void dispose() {
        LogUtil.i(CLASS_NAME, "dispose==>");
        try {
            if (disposed) {
                return;
            }
            disposed = true;
            methodChannel.setMethodCallHandler(null);
            if (lifecycle != null) {
                lifecycle.removeObserver(this);
            }
            destroyMapViewIfNecessary();
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "dispose", e);
        }
    }

    private void destroyMapViewIfNecessary() {
        if (mapView == null) {
            return;
        }
        try {
            if (mapViewResumed) {
                mapView.onPause();
            }
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "pauseBeforeDestroy", e);
        }
        try {
            mapView.onDestroy();
        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "destroyMapViewIfNecessary", e);
        }
        mapViewResumed = false;
        mapViewCreated = false;
        mapView = null;
        mapController = null;
        markersController = null;
        polylinesController = null;
        polygonsController = null;
        myMethodCallHandlerMap.clear();
    }


}
