import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';

/// WGS-84 坐标转 GCJ-02 坐标（高德地图使用）
LatLng wgs84ToGcj02(double lat, double lng) {
  const double pi = 3.14159265358979324;
  const double a = 6378245.0;
  const double ee = 0.00669342162296594;
  double dLat = _transformLat(lng - 105.0, lat - 35.0);
  double dLng = _transformLng(lng - 105.0, lat - 35.0);
  double radLat = lat / 180.0 * pi;
  double magic = sin(radLat);
  magic = 1 - ee * magic * magic;
  double sqrtMagic = sqrt(magic);
  dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
  dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * pi);
  return LatLng(lat + dLat, lng + dLng);
}

double _transformLat(double x, double y) {
  const double pi = 3.14159265358979324;
  double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
  ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
  return ret;
}

double _transformLng(double x, double y) {
  const double pi = 3.14159265358979324;
  double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
  ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
  return ret;
}

/// 旅行地图组件 — 使用 flutter_map + 高德高清瓦片
class TravelMapWidget extends StatefulWidget {
  final List<TravelSpot> spots;
  final int? highlightedId;
  final void Function(TravelSpot spot)? onMarkerTap;
  final bool showRoute;

  const TravelMapWidget({
    super.key,
    required this.spots,
    this.highlightedId,
    this.onMarkerTap,
    this.showRoute = true,
  });

  @override
  State<TravelMapWidget> createState() => TravelMapWidgetState();
}

class TravelMapWidgetState extends State<TravelMapWidget> {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);
  LatLng? _currentPosition;

  // 高德高清矢量瓦片 (scl=2 为2倍高清, style=7 为矢量路网)
  static const String _tileUrl =
      'https://wprd01.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=2&style=7';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 10));
        final gcj02 = wgs84ToGcj02(position.latitude, position.longitude);
        setState(() { _currentPosition = gcj02; });
        _mapController.move(gcj02, 12.0);
      }
    } catch (_) {}
  }

  void animateToSpot(TravelSpot spot) {
    if (spot.lat != 0 || spot.lng != 0) {
      _mapController.move(LatLng(spot.lat, spot.lng), 15.0);
    }
  }

  void fitAllMarkers() {
    final validSpots = widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.isEmpty) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final spot in validSpots) {
      if (spot.lat < minLat) minLat = spot.lat;
      if (spot.lat > maxLat) maxLat = spot.lat;
      if (spot.lng < minLng) minLng = spot.lng;
      if (spot.lng > maxLng) maxLng = spot.lng;
    }
    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _getInitialCenter(),
              initialZoom: _getInitialZoom(),
              maxZoom: 18.0,
              minZoom: 3.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrl,
                userAgentPackageName: 'com.lovegirl.app',
                maxZoom: 18,
                maxNativeZoom: 18,
              ),
              if (widget.showRoute) PolylineLayer(polylines: _buildRoutePolylines()),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          Positioned(left: 12, bottom: 12, child: _buildMapControls()),
          Positioned(right: 12, bottom: 12, child: _buildLocateButton()),
        ],
      ),
    );
  }

  LatLng _getInitialCenter() {
    final validSpots = widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.isNotEmpty) return LatLng(validSpots.first.lat, validSpots.first.lng);
    return _defaultCenter;
  }

  double _getInitialZoom() {
    final validSpots = widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    return validSpots.length > 1 ? 10.0 : 12.0;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    if (_currentPosition != null) {
      markers.add(Marker(
        point: _currentPosition!, width: 24, height: 24,
        child: Container(
          decoration: BoxDecoration(
            color: LoveGirlTheme.primary, shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: LoveGirlTheme.primary.withAlpha(80), blurRadius: 8, spreadRadius: 2)],
          ),
        ),
      ));
    }
    for (final spot in widget.spots) {
      if (spot.lat == 0 && spot.lng == 0) continue;
      final isHighlighted = widget.highlightedId == spot.id;
      final color = _statusColor(spot.status);
      markers.add(Marker(
        point: LatLng(spot.lat, spot.lng),
        width: isHighlighted ? 50 : 40, height: isHighlighted ? 60 : 50,
        child: GestureDetector(
          onTap: () { widget.onMarkerTap?.call(spot); },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 4, offset: const Offset(0, 2))]),
              child: Text(spot.name, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.location_on, color: color, size: isHighlighted ? 30 : 24),
          ]),
        ),
      ));
    }
    return markers;
  }

  List<Polyline> _buildRoutePolylines() {
    final visitedSpots = widget.spots
        .where((s) => s.status == 'visited' && (s.lat != 0 || s.lng != 0))
        .toList()..sort((a, b) => (a.visitedDate ?? '').compareTo(b.visitedDate ?? ''));
    if (visitedSpots.length < 2) return [];
    final points = visitedSpots.map((s) => LatLng(s.lat, s.lng)).toList();
    return [
      Polyline(points: points, color: LoveGirlTheme.primary.withAlpha(40), strokeWidth: 6.0),
      Polyline(points: points, color: LoveGirlTheme.primary.withAlpha(180), strokeWidth: 3.0),
    ];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'visited': return const Color(0xFF4CAF50);
      case 'wish': return const Color(0xFFFF9800);
      case 'planned': return const Color(0xFF9C27B0);
      default: return LoveGirlTheme.primary;
    }
  }

  Widget _buildMapControls() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _miniButton(Icons.add, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }),
      const SizedBox(height: 4),
      _miniButton(Icons.remove, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); }),
    ]);
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(220), borderRadius: BorderRadius.circular(8),
      child: InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap,
        child: Container(width: 32, height: 32, alignment: Alignment.center,
          child: Icon(icon, size: 18, color: LoveGirlTheme.textSecondary))),
    );
  }

  Widget _buildLocateButton() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Material(color: Colors.white.withAlpha(220), borderRadius: BorderRadius.circular(8),
        child: InkWell(borderRadius: BorderRadius.circular(8), onTap: _getCurrentLocation,
          child: Container(width: 32, height: 32, alignment: Alignment.center,
            child: const Icon(Icons.my_location, size: 16, color: LoveGirlTheme.primary)))),
      const SizedBox(height: 4),
      Material(color: Colors.white.withAlpha(220), borderRadius: BorderRadius.circular(8),
        child: InkWell(borderRadius: BorderRadius.circular(8), onTap: fitAllMarkers,
          child: Container(width: 32, height: 32, alignment: Alignment.center,
            child: const Icon(Icons.center_focus_strong, size: 16, color: LoveGirlTheme.primary)))),
    ]);
  }
}
