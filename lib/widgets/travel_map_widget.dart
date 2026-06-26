import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

/// 旅行地图组件 — 使用高德原生SDK
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
  AMapController? _controller;
  static const LatLng _defaultCenter = LatLng(30.5728, 104.0668); // 成都

  void animateToSpot(TravelSpot spot) {
    if (spot.lat != 0 || spot.lng != 0) {
      _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(spot.lat, spot.lng), 15.0),
      );
    }
  }

  void moveToLocation(double lat, double lng, {double zoom = 14.0}) {
    _controller?.moveCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
      child: AMapWidget(
        // 高德合规声明
        privacyStatement: const AMapPrivacyStatement(
          hasContains: true,
          hasShow: true,
          hasAgree: true,
        ),
        initialCameraPosition: const CameraPosition(
          target: _defaultCenter,
          zoom: 4.0,
        ),
        // 暗色主题
        mapType: MapType.night,
        // 3D建筑
        buildingsEnabled: true,
        // 缩放范围
        minMaxZoomPreference: const MinMaxZoomPreference(3.0, 18.0),
        // 显示定位蓝点
        myLocationStyleOptions: MyLocationStyleOptions(
          true,
          circleFillColor: LoveGirlTheme.primary.withAlpha(40),
          circleStrokeColor: LoveGirlTheme.primary.withAlpha(100),
          circleStrokeWidth: 2.0,
        ),
        // 手势
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        // 标记
        markers: _buildMarkers(),
        // 路线连线
        polylines: _buildPolylines(),
        // 回调
        onMapCreated: (controller) {
          _controller = controller;
          // 延迟移动到第一个有点的位置
          Future.delayed(const Duration(milliseconds: 500), () {
            _fitBounds();
          });
        },
        onLongPress: widget.onLongPress,
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    for (final spot in widget.spots) {
      if (spot.lat == 0 && spot.lng == 0) continue;

      final color = _statusColor(spot.status);
      final isHighlighted = widget.highlightedId == spot.id;

      markers.add(Marker(
        position: LatLng(spot.lat, spot.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(_colorToHue(color)),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: _statusLabel(spot.status),
        ),
        alpha: isHighlighted ? 1.0 : 0.85,
        zIndex: isHighlighted ? 10 : 1,
        onTap: (_) {
          widget.onMarkerTap?.call(spot);
        },
      ));
    }
    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final visitedSpots = widget.spots
        .where((s) =>
            s.status == 'visited' && (s.lat != 0 || s.lng != 0))
        .toList()
      ..sort(
          (a, b) => (a.visitedDate ?? '').compareTo(b.visitedDate ?? ''));

    if (visitedSpots.length < 2) return {};

    final points =
        visitedSpots.map((s) => LatLng(s.lat, s.lng)).toList();

    return {
      Polyline(
        points: points,
        color: LoveGirlTheme.primary.withAlpha(150),
        width: 3.0,
      ),
    };
  }

  void _fitBounds() {
    final validSpots =
        widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.isEmpty) return;
    if (validSpots.length == 1) {
      _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(validSpots.first.lat, validSpots.first.lng), 12.0),
      );
      return;
    }

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final spot in validSpots) {
      if (spot.lat < minLat) minLat = spot.lat;
      if (spot.lat > maxLat) maxLat = spot.lat;
      if (spot.lng < minLng) minLng = spot.lng;
      if (spot.lng > maxLng) maxLng = spot.lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - 0.5, minLng - 0.5),
      northeast: LatLng(maxLat + 0.5, maxLng + 0.5),
    );

    _controller?.moveCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
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

  double _colorToHue(Color color) {
    if (color == const Color(0xFF4CAF50)) return BitmapDescriptor.hueGreen;
    if (color == const Color(0xFFFF9800)) return BitmapDescriptor.hueOrange;
    if (color == const Color(0xFF9C27B0)) return BitmapDescriptor.hueViolet;
    return BitmapDescriptor.hueRed;
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
