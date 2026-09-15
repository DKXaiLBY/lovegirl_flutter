# AMap SDK - 完整保护，防止 ProGuard 裁剪导致地图闪退
-keep class com.amap.api.** { *; }
-keep class com.amap.api.maps.** { *; }
-keep class com.amap.api.maps.model.** { *; }
-keep class com.amap.api.services.** { *; }
-keep class com.amap.api.location.** { *; }
-keep class com.amap.api.navi.** { *; }
-keep class com.amap.flutter.map.** { *; }
-keep class com.autonavi.** { *; }
-keep class com.loc.** { *; }

# 保留 JNI native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留 Parcelable 序列化
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# 保留 AMap 接口回调
-keep interface com.amap.api.** { *; }

-dontwarn com.amap.api.**
-dontwarn com.amap.flutter.map.**
-dontwarn com.autonavi.**
-dontwarn com.loc.**

# 保留平台视图（PlatformView）相关，防止地图渲染崩溃
-keep class io.flutter.plugin.platform.** { *; }
-dontwarn io.flutter.plugin.platform.**
