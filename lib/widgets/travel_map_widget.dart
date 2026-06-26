import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

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

/// 旅行地图组件 — flutter_map + 高德瓦片（稳定可靠）
class TravelMapWidget extends StatefulWidget {
  final List<TravelSpot> spots;
  final int? highlightedId;
  final void Function(TravelSpot spot)? onMarkerTap;
  final void Function(LatLng position)? onLongPress;

  const TravelMapWidget({
    super.key,
    required this.spots,
    this.highlightedId,
    this.onMarkerTap,
    this.onLongPress,
  });

  @override
  State<TravelMapWidget> createState() => TravelMapWidgetState();
}

class TravelMapWidgetState extends State<TravelMapWidget> {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(30.5728, 104.0668);

  // 高德瓦片 + 备用瓦片
  static const String _primaryTile =
      'https://wprd01.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=2&style=7';
  static const String _fallbackTile =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  void animateToSpot(TravelSpot spot) {
    if (spot.lat != 0 || spot.lng != 0) {
      _mapController.move(LatLng(spot.lat, spot.lng), 15.0);
    }
  }

  void moveToLocation(double lat, double lng, {double zoom = 14.0}) {
    _mapController.move(LatLng(lat, lng), zoom);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _defaultCenter,
          initialZoom: 4.0,
          maxZoom: 18.0,
          minZoom: 3.0,
          onLongPress: widget.onLongPress != null
              ? (pos, point) => widget.onLongPress!(point)
              : null,
        ),
        children: [
          TileLayer(
            urlTemplate: _primaryTile,
            fallbackUrl: _fallbackTile,
            userAgentPackageName: 'com.lovegirl.app',
            maxZoom: 18,
            maxNativeZoom: 18,
          ),
          PolylineLayer(polylines: _buildPolylines()),
          MarkerLayer(markers: _buildMarkers()),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final spot in widget.spots) {
      if (spot.lat == 0 && spot.lng == 0) continue;

      final color = _statusColor(spot.status);
      final isHighlighted = widget.highlightedId == spot.id;

      markers.add(Marker(
        point: LatLng(spot.lat, spot.lng),
        width: isHighlighted ? 50 : 40,
        height: isHighlighted ? 60 : 50,
        child: GestureDetector(
          onTap: () => widget.onMarkerTap?.call(spot),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(80),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  spot.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.location_on,
                  color: color, size: isHighlighted ? 30 : 24),
            ],
          ),
        ),
      ));
    }
    return markers;
  }

  List<Polyline> _buildPolylines() {
    final visitedSpots = widget.spots
        .where((s) => s.status == 'visited' && (s.lat != 0 || s.lng != 0))
        .toList()
      ..sort((a, b) => (a.visitedDate ?? '').compareTo(b.visitedDate ?? ''));

    if (visitedSpots.length < 2) return [];

    final points = visitedSpots.map((s) => LatLng(s.lat, s.lng)).toList();
    return [
      Polyline(
          points: points,
          color: LoveGirlTheme.primary.withAlpha(40),
          strokeWidth: 6.0),
      Polyline(
          points: points,
          color: LoveGirlTheme.primary.withAlpha(180),
          strokeWidth: 3.0),
    ];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'visited':
        return const Color(0xFF4CAF50);
      case 'wish':
        return const Color(0xFFFF9800);
      case 'planned':
        return const Color(0xFF9C27B0);
      default:
        return LoveGirlTheme.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'visited':
        return '已打卡';
      case 'wish':
        return '心愿单';
      case 'planned':
        return '计划中';
      default:
        return status;
    }
  }
}
