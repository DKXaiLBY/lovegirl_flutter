package com.amap.flutter.map;

import android.content.Context;
import android.os.Build;

import com.amap.api.maps.model.CameraPosition;
import com.amap.flutter.map.utils.ConvertUtil;
import com.amap.flutter.map.utils.LogUtil;

import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/**
 * @author whm
 * @date 2020/10/27 4:08 PM
 * @mail hongming.whm@alibaba-inc.com
 * @since
 */
class AMapPlatformViewFactory extends PlatformViewFactory {
    private static final String CLASS_NAME = "AMapPlatformViewFactory";
    private final BinaryMessenger binaryMessenger;
    private final LifecycleProvider lifecycleProvider;
    AMapPlatformViewFactory(BinaryMessenger binaryMessenger,
                            LifecycleProvider lifecycleProvider) {
        super(StandardMessageCodec.INSTANCE);
        this.binaryMessenger = binaryMessenger;
        this.lifecycleProvider = lifecycleProvider;
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
        if (Build.SUPPORTED_ABIS != null) {
            for (String abi : Build.SUPPORTED_ABIS) {
                if (abi != null && abi.startsWith("x86")) {
                    return new AMapErrorPlatformView(
                            context,
                            "\u5f53\u524d\u6a21\u62df\u5668\u67b6\u6784\u7f3a\u5c11\u9ad8\u5fb7\u539f\u751f\u5730\u56fe\u5e93\n\u8bf7\u5728\u5b89\u5353\u771f\u673a\u4e0a\u67e5\u770b\u771f\u5730\u56fe"
                    );
                }
            }
        }

        final AMapOptionsBuilder builder = new AMapOptionsBuilder();
        Map<String, Object> params = null;
        try {
            ConvertUtil.density = context.getResources().getDisplayMetrics().density;
            params = (Map<String, Object>) args;
            LogUtil.i(CLASS_NAME,"create params==>" + params);
            if (params.containsKey("privacyStatement")) {
                ConvertUtil.setPrivacyStatement(context, params.get("privacyStatement"));
            }

            Object options = ((Map<String, Object>) args).get("options");
            if(null != options) {
                ConvertUtil.interpretAMapOptions(options, builder);
            }

            if (params.containsKey("initialCameraPosition")) {
                CameraPosition cameraPosition = ConvertUtil.toCameraPosition(params.get("initialCameraPosition"));
                builder.setCamera(cameraPosition);
            }

            if (params.containsKey("markersToAdd")) {
                builder.setInitialMarkers(params.get("markersToAdd"));
            }
            if (params.containsKey("polylinesToAdd")) {
                builder.setInitialPolylines(params.get("polylinesToAdd"));
            }

            if (params.containsKey("polygonsToAdd")) {
                builder.setInitialPolygons(params.get("polygonsToAdd"));
            }


            if (params.containsKey("apiKey")) {
                ConvertUtil.checkApiKey(params.get("apiKey"));
            }

            if (params.containsKey("debugMode")) {
                LogUtil.isDebugMode = ConvertUtil.toBoolean(params.get("debugMode"));
            }

        } catch (Throwable e) {
            LogUtil.e(CLASS_NAME, "create", e);
        }
        AMapPlatformView view = builder.build(viewId, context, binaryMessenger, lifecycleProvider);
        if (view == null || !view.isReady()) {
            return new AMapErrorPlatformView(context);
        }
        return view;
    }
}
