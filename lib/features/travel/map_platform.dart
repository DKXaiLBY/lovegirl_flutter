import 'dart:io';

import 'package:flutter/services.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class TravelMapPlatform {
  static const channel = MethodChannel('lovegirl/device');

  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    final abis = await channel.invokeListMethod<String>('getSupportedAbis');
    return !(abis ?? []).any((abi) => abi.toLowerCase().startsWith('x86'));
  }

  static Future<LatLng> fromGps(double lat, double lng) async {
    final point = await channel.invokeMapMethod<String, dynamic>(
        'gpsToAmap', {'lat': lat, 'lng': lng});
    if (point == null) {
      throw const FormatException('Coordinate conversion failed');
    }
    return LatLng(
        (point['lat'] as num).toDouble(), (point['lng'] as num).toDouble());
  }

  static Future<void> setLogoBottomInset(int mapId, int pixels) async {
    if (!Platform.isAndroid) return;
    await MethodChannel('amap_flutter_map_$mapId').invokeMethod('map#update', {
      'options': {'logoBottomInset': pixels}
    });
  }

  static Future<void> startWalkingNavigation({
    required double latitude,
    required double longitude,
    required String name,
    required bool dark,
  }) async {
    if (!await isSupported()) {
      throw StateError('这台设备暂不支持应用内步行导航');
    }
    final permission = await Permission.locationWhenInUse.request();
    if (!permission.isGranted) throw StateError('请允许位置权限后再出发');
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        forceAndroidLocationManager: true,
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      throw StateError('暂未取得当前位置，请到开阔处再试');
    }
    if (!position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 150 ||
        DateTime.now().difference(position.timestamp).abs() >
            const Duration(seconds: 45)) {
      throw StateError('当前位置不够准确，请到开阔处再试');
    }
    final start = await fromGps(position.latitude, position.longitude);
    await channel.invokeMethod<void>('startWalkingNavigation', {
      'lat': latitude,
      'lng': longitude,
      'startLat': start.latitude,
      'startLng': start.longitude,
      'name': name,
      'dark': dark,
    });
  }
}
