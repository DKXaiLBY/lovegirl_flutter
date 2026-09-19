import 'dart:async';

import 'package:amap_flutter_base/amap_flutter_base.dart' as amap;
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lovegirl_flutter/utils/amap_api.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  /// 城市聚焦点（非选中态）：进页面直接落到该城市上空
  final double? focusLat;
  final double? focusLng;

  const MapPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.focusLat,
    this.focusLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const amap.LatLng _defaultCenter = amap.LatLng(30.5728, 104.0668);
  static const String _androidMapKey = '2209d350da6804c16673f5c36d52f64b';

  final TextEditingController _searchCtrl = TextEditingController();

  AMapController? _controller;
  amap.LatLng? _selectedPoint;
  amap.AMapLocation? _lastLocation;
  Timer? _searchDebounce;

  String _selectedName = '';
  String _selectedAddress = '';
  String _selectedCity = '';
  List<AmapPoi> _searchResults = [];
  bool _searching = false;
  bool _showResults = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLat;
    final lng = widget.initialLng;
    if (lat != null && lng != null && (lat != 0 || lng != 0)) {
      _selectedPoint = amap.LatLng(lat, lng);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _moveTo(amap.LatLng point, {double zoom = 16}) async {
    await _controller?.moveCamera(
      CameraUpdate.newLatLngZoom(point, zoom),
      animated: true,
      duration: 550,
    );
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final status = await Permission.location.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                '\u9700\u8981\u5b9a\u4f4d\u6743\u9650\u624d\u80fd\u663e\u793a\u5f53\u524d\u4f4d\u7f6e'),
            behavior: SnackBarBehavior.floating,
            action: status.isPermanentlyDenied
                ? SnackBarAction(
                    label: '\u53bb\u8bbe\u7f6e', onPressed: openAppSettings)
                : null,
          ),
        );
        return;
      }

      final location = _lastLocation;
      if (location == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\u6b63\u5728\u83b7\u53d6\u5b9a\u4f4d\uff0c\u7a0d\u7b49\u4e00\u4e0b\u518d\u8bd5'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await _moveTo(location.latLng, zoom: 16);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search(String keyword) async {
    final value = keyword.trim();
    if (value.isEmpty) {
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
      final results = await AmapApi.searchPoi(value, city: _selectedCity);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '\u641c\u7d22\u5931\u8d25\u4e86\uff0c\u6362\u4e2a\u5173\u952e\u8bcd\u518d\u8bd5\u8bd5'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _search(value);
    });
  }

  Future<void> _selectPoi(AmapPoi poi) async {
    final point = amap.LatLng(poi.lat, poi.lng);
    setState(() {
      _selectedPoint = point;
      _selectedName = poi.name;
      _selectedAddress = poi.address;
      _selectedCity = poi.city;
      _showResults = false;
      _searchCtrl.text = poi.name;
    });
    await _moveTo(point);
  }

  Future<void> _selectPoint(amap.LatLng point, {String? name}) async {
    setState(() {
      _selectedPoint = point;
      _selectedName = name ?? '';
      _selectedAddress = '';
      _selectedCity = '';
      _showResults = false;
    });

    final regeo = await AmapApi.regeo(point.latitude, point.longitude);
    if (!mounted) return;
    if (regeo != null) {
      setState(() {
        _selectedAddress = regeo.address;
        _selectedCity = regeo.city;
        _selectedName = name?.isNotEmpty == true
            ? name!
            : (regeo.district.isNotEmpty ? regeo.district : regeo.address);
      });
    }
  }

  void _confirm() {
    final point = _selectedPoint;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('\u8bf7\u5148\u9009\u62e9\u4e00\u4e2a\u4f4d\u7f6e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'lat': point.latitude,
      'lng': point.longitude,
      'name': _selectedName,
      'address': _selectedAddress,
      'city': _selectedCity,
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          AMapWidget(
            apiKey: const amap.AMapApiKey(androidKey: _androidMapKey),
            privacyStatement: const amap.AMapPrivacyStatement(
              hasContains: true,
              hasShow: true,
              hasAgree: true,
            ),
            initialCameraPosition: CameraPosition(
              target: _selectedPoint ??
                  (widget.focusLat != null && widget.focusLng != null
                      ? amap.LatLng(widget.focusLat!, widget.focusLng!)
                      : _defaultCenter),
              zoom: _selectedPoint != null
                  ? 16
                  : (widget.focusLat != null ? 12 : 5),
            ),
            compassEnabled: false,
            scaleEnabled: true,
            touchPoiEnabled: true,
            myLocationStyleOptions: MyLocationStyleOptions(
              true,
              circleFillColor: const Color(0x331677FF),
              circleStrokeColor: const Color(0xFF1677FF),
              circleStrokeWidth: 1,
            ),
            markers: _buildMarkers(),
            onMapCreated: (controller) {
              _controller = controller;
              if (_selectedPoint != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _moveTo(_selectedPoint!, zoom: 16);
                });
              }
            },
            onTap: _selectPoint,
            onPoiTouched: (poi) {
              final point = poi.latLng;
              if (point != null) {
                _selectPoint(point, name: poi.name);
              }
            },
            onLocationChanged: (location) {
              if (mounted) setState(() => _lastLocation = location);
            },
          ),
          Positioned(
            top: topPadding + 8,
            left: 8,
            child: _RoundButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '\u8fd4\u56de',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: topPadding + 8,
            left: 58,
            right: 16,
            child: _buildSearchBar(),
          ),
          if (_showResults)
            Positioned(
              top: topPadding + 64,
              left: 16,
              right: 16,
              child: _buildSearchResults(),
            ),
          Positioned(
            right: 14,
            bottom: _selectedPoint == null
                ? MediaQuery.of(context).padding.bottom + 18
                : MediaQuery.of(context).padding.bottom + 166,
            child: _RoundButton(
              icon: _locating ? null : Icons.my_location_rounded,
              tooltip: '\u5b9a\u4f4d\u5230\u6211',
              onTap: _locateMe,
              loading: _locating,
            ),
          ),
          if (_selectedPoint != null && !_showResults)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: _buildBottomBar(),
            ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final point = _selectedPoint;
    if (point == null) return const {};
    return {
      Marker(
        position: point,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(
          title: _selectedName.isEmpty
              ? '\u9009\u4e2d\u7684\u4f4d\u7f6e'
              : _selectedName,
          snippet: _selectedAddress,
        ),
      ),
    };
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(24),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText:
              '\u641c\u7d22\u5730\u70b9\u3001\u5546\u5708\u6216\u666f\u70b9',
          prefixIcon:
              Icon(Icons.search_rounded, color: context.lgTextMuted),
          suffixIcon: _searchCtrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {
                      _searchResults = [];
                      _showResults = false;
                    });
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
        onSubmitted: _search,
        onChanged: (value) {
          setState(() {});
          _onSearchChanged(value);
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 330),
      decoration: BoxDecoration(
        color: context.lgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(28), blurRadius: 16),
        ],
      ),
      child: _searching
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : _searchResults.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                      '\u6ca1\u6709\u627e\u5230\u76f8\u5173\u5730\u70b9',
                      textAlign: TextAlign.center),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.black.withAlpha(12),
                  ),
                  itemBuilder: (context, index) {
                    final poi = _searchResults[index];
                    return ListTile(
                      leading: Icon(
                        Icons.place_rounded,
                        color: context.lgInk,
                      ),
                      title: Text(
                        poi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [poi.city, poi.address]
                            .where((item) => item.isNotEmpty)
                            .join(' \u00b7 '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectPoi(poi),
                    );
                  },
                ),
    );
  }

  Widget _buildBottomBar() {
    final point = _selectedPoint!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.lgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded,
                  color: context.lgInk, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedName.isEmpty
                      ? '\u9009\u4e2d\u7684\u4f4d\u7f6e'
                      : _selectedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.lgTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _selectedAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 13, color: context.lgTextMuted),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
            style: TextStyle(
              fontSize: 12,
              color: context.lgTextMuted.withAlpha(170),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('\u786e\u8ba4\u8fd9\u4e2a\u5730\u70b9'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.lgInk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool loading;

  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(245),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(24),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 21, color: context.lgTextPrimary),
          ),
        ),
      ),
    );
  }
}
