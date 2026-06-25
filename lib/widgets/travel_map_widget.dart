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

/// 旅行地图组件 — 使用 flutter_map + 高德瓦片服务
class TravelMapWidget extends StatefulWidget {
  final List<TravelSpot> spots;
  final int? highlightedId;
  final void Function(TravelSpot spot)? onMarkerTap;
  final bool showRoute; // 是否显示路线

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

  // 默认中心点（北京）
  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

  // 当前位置
  LatLng? _currentPosition;

  // 高德瓦片服务地址
  static const String _gaodeTileUrl =
      'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// 获取当前位置
  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));

        // 转换为 GCJ-02 坐标
        final gcj02 = wgs84ToGcj02(position.latitude, position.longitude);

        setState(() {
          _currentPosition = gcj02;
        });

        // 移动地图到当前位置
        _mapController.move(gcj02, 12.0);
      }
    } catch (e) {
      // 定位失败，使用默认位置
    }
  }

  /// 平滑移动到指定地点
  void animateToSpot(TravelSpot spot) {
    if (spot.lat != 0 || spot.lng != 0) {
      _mapController.move(
        LatLng(spot.lat, spot.lng),
        15.0,
      );
    }
  }

  /// 移动到所有标记点的中心
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

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
      child: Stack(
        children: [
          // flutter_map + 高德瓦片
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _getInitialCenter(),
              initialZoom: _getInitialZoom(),
              maxZoom: 16.0,
              minZoom: 3.0,
            ),
            children: [
              // 高德瓦片图层
              TileLayer(
                urlTemplate: _gaodeTileUrl,
                userAgentPackageName: 'com.lovegirl.app',
              ),
              // 路线图层
              if (widget.showRoute) PolylineLayer(polylines: _buildRoutePolylines()),
              // 标记点
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),

          // 底部渐变过渡
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      LoveGirlTheme.bgLight.withAlpha(0),
                      LoveGirlTheme.bgLight,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 左下角控制按钮
          Positioned(
            left: 12,
            bottom: 50,
            child: _buildMapControls(),
          ),

          // 右下角定位按钮
          Positioned(
            right: 12,
            bottom: 50,
            child: _buildLocateButton(),
          ),
        ],
      ),
    );
  }

  LatLng _getInitialCenter() {
    final validSpots = widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.isNotEmpty) {
      return LatLng(validSpots.first.lat, validSpots.first.lng);
    }
    return _defaultCenter;
  }

  double _getInitialZoom() {
    final validSpots = widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.length > 1) {
      return 10.0;
    }
    return 12.0;
  }

  /// 构建地图标记点（带聚合）
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // 添加当前位置标记
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: LoveGirlTheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: LoveGirlTheme.primary.withAlpha(80),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 获取有效地点
    final validSpots = widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.isEmpty) return markers;

    // 聚合逻辑：当缩放级别较低时，将相近的标记聚合
    final zoom = _mapController.camera.zoom;
    final clusters = _clusterSpots(validSpots, zoom);

    for (final cluster in clusters) {
      if (cluster.spots.length == 1) {
        // 单个标记
        final spot = cluster.spots.first;
        final isHighlighted = widget.highlightedId == spot.id;
        final color = _statusColor(spot.status);

        markers.add(
          Marker(
            point: LatLng(spot.lat, spot.lng),
            width: isHighlighted ? 50 : 40,
            height: isHighlighted ? 60 : 50,
            child: GestureDetector(
              onTap: () => widget.onMarkerTap?.call(spot),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  Icon(
                    Icons.location_on,
                    color: color,
                    size: isHighlighted ? 30 : 24,
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // 聚合标记
        markers.add(
          Marker(
            point: cluster.center,
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () {
                // 点击聚合标记时，缩放到该区域
                _mapController.move(cluster.center, zoom + 2);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: LoveGirlTheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: LoveGirlTheme.primary.withAlpha(80),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${cluster.spots.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  /// 聚合标记点
  List<_Cluster> _clusterSpots(List<TravelSpot> spots, double zoom) {
    // 根据缩放级别确定聚合距离（经纬度度数）
    // 缩放越大，聚合距离越小
    final double clusterDistance;
    if (zoom < 6) {
      clusterDistance = 5.0;
    } else if (zoom < 8) {
      clusterDistance = 2.0;
    } else if (zoom < 10) {
      clusterDistance = 0.8;
    } else if (zoom < 12) {
      clusterDistance = 0.3;
    } else {
      clusterDistance = 0.1; // 高缩放级别不聚合
    }

    final clusters = <_Cluster>[];
    final used = <bool>[];

    for (int i = 0; i < spots.length; i++) {
      used.add(false);
    }

    for (int i = 0; i < spots.length; i++) {
      if (used[i]) continue;

      final clusterSpots = <TravelSpot>[spots[i]];
      used[i] = true;

      for (int j = i + 1; j < spots.length; j++) {
        if (used[j]) continue;

        final distance = _calculateDistance(
          spots[i].lat, spots[i].lng,
          spots[j].lat, spots[j].lng,
        );

        if (distance < clusterDistance) {
          clusterSpots.add(spots[j]);
          used[j] = true;
        }
      }

      // 计算聚合中心点
      double sumLat = 0, sumLng = 0;
      for (final spot in clusterSpots) {
        sumLat += spot.lat;
        sumLng += spot.lng;
      }

      clusters.add(_Cluster(
        center: LatLng(sumLat / clusterSpots.length, sumLng / clusterSpots.length),
        spots: clusterSpots,
      ));
    }

    return clusters;
  }

  /// 计算两点之间的距离（简化版，用于聚合判断）
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = lat1 - lat2;
    final dLng = lng1 - lng2;
    return sqrt(dLat * dLat + dLng * dLng);
  }

  /// 构建路线折线
  List<Polyline> _buildRoutePolylines() {
    // 获取已访问的地点，按访问日期排序
    final visitedSpots = widget.spots
        .where((s) => s.status == 'visited' && (s.lat != 0 || s.lng != 0))
        .toList()
      ..sort((a, b) => (a.visitedDate ?? '').compareTo(b.visitedDate ?? ''));

    if (visitedSpots.length < 2) return [];

    final points = visitedSpots.map((s) => LatLng(s.lat, s.lng)).toList();

    return [
      // 阴影线（底层）
      Polyline(
        points: points,
        color: LoveGirlTheme.primary.withAlpha(40),
        strokeWidth: 6.0,
        borderColor: LoveGirlTheme.primary.withAlpha(60),
        borderStrokeWidth: 2.0,
      ),
      // 主线
      Polyline(
        points: points,
        color: LoveGirlTheme.primary.withAlpha(180),
        strokeWidth: 3.0,
      ),
    ];
  }

  Widget _buildMapControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniButton(Icons.add, () {
          _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom + 1,
          );
        }),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 1,
          color: Colors.white.withAlpha(100),
        ),
        const SizedBox(height: 4),
        _miniButton(Icons.remove, () {
          _mapController.move(
            _mapController.camera.center,
            _mapController.camera.zoom - 1,
          );
        }),
      ],
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(220),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: LoveGirlTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildLocateButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // GPS定位到当前位置
        Material(
          color: Colors.white.withAlpha(220),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _getCurrentLocation,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.my_location, size: 16, color: LoveGirlTheme.primary),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 显示所有标记点
        Material(
          color: Colors.white.withAlpha(220),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: fitAllMarkers,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.center_focus_strong, size: 16, color: LoveGirlTheme.primary),
            ),
          ),
        ),
      ],
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
}

/// 聚合数据类
class _Cluster {
  final LatLng center;
  final List<TravelSpot> spots;

  _Cluster({required this.center, required this.spots});
}
