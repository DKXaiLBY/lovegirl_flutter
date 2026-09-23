package com.amap.flutter.map;

import android.content.Context;
import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.widget.TextView;

import io.flutter.plugin.platform.PlatformView;

class AMapErrorPlatformView implements PlatformView {
    private final TextView view;

    AMapErrorPlatformView(Context context) {
        this(context, "\u5730\u56fe\u6682\u65f6\u65e0\u6cd5\u52a0\u8f7d\n\u8bf7\u68c0\u67e5\u9ad8\u5fb7\u5bc6\u94a5\u3001\u7f51\u7edc\u6216\u5b9a\u4f4d\u6743\u9650\u540e\u91cd\u8bd5");
    }

    AMapErrorPlatformView(Context context, String message) {
        view = new TextView(context);
        view.setGravity(Gravity.CENTER);
        view.setText(message);
        view.setTextColor(Color.rgb(109, 94, 90));
        view.setTextSize(14);
        view.setBackgroundColor(Color.rgb(255, 251, 245));
    }

    @Override
    public View getView() {
        return view;
    }

    @Override
    public void dispose() {
    }
}

