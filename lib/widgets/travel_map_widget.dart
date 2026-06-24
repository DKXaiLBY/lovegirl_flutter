import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';

/// 旅行地图组件 — 使用flutter_map + 高德瓦片服务
/// 国内使用高德瓦片，加载更快、数据更准确
class TravelMapWidget extends StatefulWidget {
  final List<TravelSpot> spots;
  final int? highlightedId;
  final void Function(TravelSpot spot)? onMarkerTap;

  const TravelMapWidget({
    super.key,
    required this.spots,
    this.highlightedId,
    this.onMarkerTap,
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

  // 高德瓦片服务地址（高清矢量瓦片）
  // scale=2 为 Retina 高清，style=7 为矢量地图（更清晰）
  static const String _gaodeTileUrl =
      'https://wprd01.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=2&style=7';

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
    final validSpots =
        widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
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
            ),
            children: [
              // 高德瓦片图层
              TileLayer(
                urlTemplate: _gaodeTileUrl,
                userAgentPackageName: 'com.lovegirl.app',
                maxZoom: 18,
              ),
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

          // 右上角"已探索"标签
          Positioned(
            right: 16,
            top: 8,
            child: _buildExploredBadge(),
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
    final validSpots =
        widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.isNotEmpty) {
      return LatLng(validSpots.first.lat, validSpots.first.lng);
    }
    return _defaultCenter;
  }

  double _getInitialZoom() {
    final validSpots =
        widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    if (validSpots.length > 1) {
      return 10.0;
    }
    return 12.0;
  }

  /// 构建地图标记点
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

    for (final spot in widget.spots) {
      if (spot.lat == 0 && spot.lng == 0) continue; // 跳过未定位的点

      final isHighlighted = widget.highlightedId == spot.id;
      final color = _statusColor(spot.status);

      markers.add(
        Marker(
          point: LatLng(spot.lat, spot.lng),
          width: isHighlighted ? 50 : 40,
          height: isHighlighted ? 60 : 50,
          child: GestureDetector(
            onTap: () {
              widget.onMarkerTap?.call(spot);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
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
    }

    return markers;
  }

  Widget _buildExploredBadge() {
    final validSpots =
        widget.spots.where((s) => s.lat != 0 || s.lng != 0).toList();
    final cityCount = validSpots.map((s) => s.city).toSet().length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LoveGirlTheme.primary.withAlpha(30),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.explore, size: 14, color: LoveGirlTheme.primary),
          const SizedBox(width: 4),
          Text(
            '已探索 $cityCount 个城市',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
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
            onTap: _locateCurrentPosition,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.my_location,
                  size: 16, color: LoveGirlTheme.primary),
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
              child: const Icon(Icons.center_focus_strong,
                  size: 16, color: LoveGirlTheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  /// 定位到当前位置
  Future<void> _locateCurrentPosition() async {
    try {
      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // 获取当前位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentPos = LatLng(position.latitude, position.longitude);

      // 更新当前位置
      setState(() {
        _currentPosition = currentPos;
      });

      // 移动地图到当前位置
      _mapController.move(currentPos, 15.0);
    } catch (e) {
      // 定位失败，忽略
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'visited':
        return LoveGirlTheme.visited;
      case 'wish':
        return LoveGirlTheme.wish;
      case 'planned':
        return LoveGirlTheme.planned;
      default:
        return LoveGirlTheme.textMuted;
    }
  }
}

/// 地图选点页面 — 用于选择旅行地点的位置
class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _selectedPosition = const LatLng(39.9042, 116.4074);

  // 高德瓦片服务地址
  static const String _gaodeTileUrl =
      'https://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}';

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null &&
        widget.initialLng != null &&
        widget.initialLat != 0 &&
        widget.initialLng != 0) {
      _selectedPosition = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择位置'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'lat': _selectedPosition.latitude,
                'lng': _selectedPosition.longitude,
              });
            },
            child: const Text('确定'),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 地图
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  setState(() {
                    _selectedPosition = position.center!;
                  });
                }
              },
            ),
            children: [
              // 高德瓦片图层
              TileLayer(
                urlTemplate: _gaodeTileUrl,
                userAgentPackageName: 'com.lovegirl.app',
                maxZoom: 18,
              ),
            ],
          ),

          // 中心标记
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${_selectedPosition.latitude.toStringAsFixed(4)}, ${_selectedPosition.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.location_on,
                  color: LoveGirlTheme.primary,
                  size: 40,
                ),
              ],
            ),
          ),

          // 底部提示
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: LoveGirlTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '移动地图，将标记点对准你要记录的位置',
                      style: TextStyle(
                        fontSize: 13,
                        color: LoveGirlTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
