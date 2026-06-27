import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
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

/// 地图样式枚举
enum MapStyle {
  standard('标准', Icons.map_rounded),
  satellite('卫星', Icons.satellite_alt_rounded),
  dark('暗色', Icons.dark_mode_rounded);

  final String label;
  final IconData icon;
  const MapStyle(this.label, this.icon);
}

/// 旅行地图组件 — flutter_map + 高德瓦片 + 样式切换 + 定位
class TravelMapWidget extends StatefulWidget {
  final List<TravelSpot> spots;
  final List<TravelSpot>? allSpots; // 全量spots（用于计算边界）
  final int? highlightedId;
  final void Function(TravelSpot spot)? onMarkerTap;
  final void Function(LatLng position)? onLongPress;

  const TravelMapWidget({
    super.key,
    required this.spots,
    this.allSpots,
    this.highlightedId,
    this.onMarkerTap,
    this.onLongPress,
  });

  @override
  State<TravelMapWidget> createState() => TravelMapWidgetState();
}

class TravelMapWidgetState extends State<TravelMapWidget>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(30.5728, 104.0668);

  MapStyle _currentStyle = MapStyle.standard;
  bool _isLocating = false;
  bool _hasFitBounds = false;

  // 地图瓦片配置
  static const Map<MapStyle, String> _tileUrls = {
    MapStyle.standard:
        'https://wprd01.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=2&style=7',
    MapStyle.satellite:
        'https://webst01.is.autonavi.com/appmaptile?style=8&x={x}&y={y}&z={z}',
    MapStyle.dark:
        'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
  };

  static const String _fallbackTile =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(TravelMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当spots变化时，自动适应边界
    if (!_hasFitBounds && widget.spots.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
        _hasFitBounds = true;
      });
    }
  }

  void _fitBounds() {
    final validSpots =
        widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.isEmpty) return;
    if (validSpots.length == 1) {
      _mapController.move(
          LatLng(validSpots.first.lat, validSpots.first.lng), 12.0);
      return;
    }

    double minLat = validSpots.first.lat;
    double maxLat = validSpots.first.lat;
    double minLng = validSpots.first.lng;
    double maxLng = validSpots.first.lng;

    for (final s in validSpots) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lng < minLng) minLng = s.lng;
      if (s.lng > maxLng) maxLng = s.lng;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 10.0;
    if (maxDiff > 30) {
      zoom = 3.0;
    } else if (maxDiff > 15) {
      zoom = 4.0;
    } else if (maxDiff > 8) {
      zoom = 5.0;
    } else if (maxDiff > 3) {
      zoom = 6.0;
    } else if (maxDiff > 1) {
      zoom = 8.0;
    } else if (maxDiff > 0.3) {
      zoom = 10.0;
    }

    _mapController.move(center, zoom);
  }

  void animateToSpot(TravelSpot spot) {
    if (spot.lat != 0 || spot.lng != 0) {
      _mapController.move(LatLng(spot.lat, spot.lng), 15.0);
    }
  }

  void moveToLocation(double lat, double lng, {double zoom = 14.0}) {
    _mapController.move(LatLng(lat, lng), zoom);
  }

  /// 定位到当前位置
  Future<void> locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('需要定位权限才能使用此功能'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('定位权限被永久拒绝，请在设置中开启'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: '设置',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // WGS-84 → GCJ-02
      final gcjPos = wgs84ToGcj02(position.latitude, position.longitude);

      _mapController.move(gcjPos, 14.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('定位失败，请重试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _cycleMapStyle() {
    final nextIndex =
        (_currentStyle.index + 1) % MapStyle.values.length;
    setState(() => _currentStyle = MapStyle.values[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
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
                urlTemplate: _tileUrls[_currentStyle]!,
                fallbackUrl: _fallbackTile,
                userAgentPackageName: 'com.lovegirl.app',
                maxZoom: 18,
                maxNativeZoom: 18,
              ),
              PolylineLayer(polylines: _buildPolylines()),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
        ),

        // 地图样式切换按钮
        Positioned(
          top: 12,
          right: 12,
          child: _MapButton(
            icon: _currentStyle.icon,
            tooltip: '切换地图样式（${_currentStyle.label}）',
            onTap: _cycleMapStyle,
          ),
        ),

        // 定位按钮
        Positioned(
          bottom: 12,
          right: 12,
          child: _MapButton(
            icon: _isLocating ? null : Icons.my_location_rounded,
            tooltip: '定位到我',
            onTap: locateMe,
            isLoading: _isLocating,
          ),
        ),

        // 适应所有标记按钮
        if (widget.spots.length > 1)
          Positioned(
            bottom: 56,
            right: 12,
            child: _MapButton(
              icon: Icons.fit_screen_rounded,
              tooltip: '查看所有标记',
              onTap: _fitBounds,
            ),
          ),
      ],
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
}

/// 地图上的圆形按钮
class _MapButton extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isLoading;

  const _MapButton({
    this.icon,
    required this.tooltip,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(220),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: LoveGirlTheme.primary),
                  )
                : Icon(icon,
                    size: 20, color: LoveGirlTheme.textPrimary),
          ),
        ),
      ),
    );
  }
}
