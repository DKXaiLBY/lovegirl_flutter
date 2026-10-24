import 'dart:io';

import 'package:flutter/services.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

class TravelMapPlatform {
  static const channel = MethodChannel('lovegirl/device');
  static const androidKey = '2209d350da6804c16673f5c36d52f64b';

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
}
