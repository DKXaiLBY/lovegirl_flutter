import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lovegirl_flutter/utils/amap_api.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/travel_map_widget.dart' show wgs84ToGcj02;

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const MapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  LatLng? _selectedPoint;
  String _selectedName = '';
  String _selectedAddress = '';
  String _selectedCity = '';
  List<AmapPoi> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;
  bool _mapReady = false;

  static const LatLng _defaultCenter = LatLng(39.9042, 116.4074);

  // 主瓦片 + 备用瓦片
  static const String _primaryTile =
      'https://wprd01.is.autonavi.com/appmaptile?x={x}&y={y}&z={z}&lang=zh_cn&size=1&scl=2&style=7';
  static const String _fallbackTile =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null &&
        widget.initialLng != null &&
        (widget.initialLat != 0 || widget.initialLng != 0)) {
      _selectedPoint = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onMapReady() {
    if (!_mapReady) {
      _mapReady = true;
      if (_selectedPoint != null) {
        _mapController.move(_selectedPoint!, 15.0);
      } else {
        _getCurrentLocation();
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high)
            .timeout(const Duration(seconds: 10));
        final gcj02 = wgs84ToGcj02(position.latitude, position.longitude);
        if (mounted) _mapController.move(gcj02, 14.0);
      }
    } catch (_) {
      // 定位失败不阻塞，用户可以手动选点
    }
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _showResults = true;
    });
    try {
      final results = await AmapApi.searchPoi(keyword.trim());
      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('搜索失败，请检查网络'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
    if (mounted) setState(() => _searching = false);
  }

  void _selectPoi(AmapPoi poi) {
    final point = LatLng(poi.lat, poi.lng);
    setState(() {
      _selectedPoint = point;
      _selectedName = poi.name;
      _selectedAddress = poi.address;
      _selectedCity = poi.city;
      _showResults = false;
      _searchCtrl.text = poi.name;
    });
    _mapController.move(point, 15.0);
  }

  void _onMapTap(TapPosition pos, LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _selectedName = '';
      _selectedAddress = '';
      _selectedCity = '';
    });
    try {
      final regeo = await AmapApi.regeo(point.latitude, point.longitude);
      if (regeo != null && mounted) {
        setState(() {
          _selectedAddress = regeo.address;
          _selectedCity = regeo.city;
          _selectedName = regeo.district;
        });
      }
    } catch (_) {
      // 逆地理编码失败不阻塞
    }
  }

  void _confirm() {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一个位置'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop({
      'lat': _selectedPoint!.latitude,
      'lng': _selectedPoint!.longitude,
      'name': _selectedName,
      'address': _selectedAddress,
      'city': _selectedCity,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地图
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint ?? _defaultCenter,
              initialZoom: _selectedPoint != null ? 15.0 : 10.0,
              maxZoom: 18.0,
              minZoom: 3.0,
              onTap: _onMapTap,
              onMapReady: _onMapReady,
            ),
            children: [
              TileLayer(
                urlTemplate: _primaryTile,
                fallbackUrl: _fallbackTile,
                userAgentPackageName: 'com.lovegirl.app',
                maxZoom: 18,
                maxNativeZoom: 18,
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint!,
                      width: 40,
                      height: 50,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: LoveGirlTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: LoveGirlTheme.primary.withAlpha(80),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _selectedName.isNotEmpty
                                  ? _selectedName
                                  : '选中位置',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.location_on,
                              color: LoveGirlTheme.primary, size: 30),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: Material(
              color: Colors.white.withAlpha(220),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back,
                      size: 20, color: LoveGirlTheme.textPrimary),
                ),
              ),
            ),
          ),

          // 搜索栏
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 56,
            right: 16,
            child: _buildSearchBar(),
          ),

          // 搜索结果
          if (_showResults)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: _buildSearchResults(),
            ),

          // 底部确认栏
          if (_selectedPoint != null && !_showResults)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: _buildBottomBar(),
            ),

          // 定位按钮
          Positioned(
            right: 12,
            bottom: _selectedPoint != null
                ? MediaQuery.of(context).padding.bottom + 160
                : MediaQuery.of(context).padding.bottom + 16,
            child: Material(
              color: Colors.white.withAlpha(220),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _getCurrentLocation,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: const Icon(Icons.my_location,
                      size: 20, color: LoveGirlTheme.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: '搜索地点...',
          prefixIcon: const Icon(Icons.search, color: LoveGirlTheme.textMuted),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchResults = [];
                      _showResults = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: _search,
        onChanged: (v) {
          // 防抖：停止输入500ms后自动搜索
          Future.delayed(const Duration(milliseconds: 500), () {
            if (v == _searchCtrl.text && v.isNotEmpty) _search(v);
          });
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_searchResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)
          ],
        ),
        child: const Text('未找到相关地点', textAlign: TextAlign.center),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.withAlpha(30)),
        itemBuilder: (context, index) {
          final poi = _searchResults[index];
          return ListTile(
            dense: true,
            leading:
                const Icon(Icons.location_on, color: LoveGirlTheme.primary, size: 20),
            title: Text(poi.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text('${poi.city} ${poi.address}',
                style: TextStyle(
                    fontSize: 12, color: LoveGirlTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            onTap: () => _selectPoi(poi),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedName.isNotEmpty)
            Text(_selectedName,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: LoveGirlTheme.textPrimary)),
          if (_selectedAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_selectedAddress,
                style:
                    TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 4),
          Text(
            '${_selectedPoint!.latitude.toStringAsFixed(6)}, ${_selectedPoint!.longitude.toStringAsFixed(6)}',
            style: TextStyle(
                fontSize: 11, color: LoveGirlTheme.textMuted.withAlpha(150)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: LoveGirlTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('确认选择此位置',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
