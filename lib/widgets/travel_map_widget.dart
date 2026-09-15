import 'package:amap_flutter_base/amap_flutter_base.dart'
    show AMapApiKey, AMapLocation, AMapPrivacyStatement, LatLng, LatLngBounds;
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

enum TravelMapStyle {
  normal('\u6807\u51c6', Icons.map_rounded, MapType.normal),
  satellite('\u536b\u661f', Icons.satellite_alt_rounded, MapType.satellite),
  night('\u591c\u95f4', Icons.dark_mode_rounded, MapType.night);

  final String label;
  final IconData icon;
  final MapType type;

  const TravelMapStyle(this.label, this.icon, this.type);
}

class TravelMapWidget extends StatefulWidget {
  final List<TravelSpot> spots;
  final List<TravelSpot>? allSpots;
  final List<TravelRoute> routes;
  final TravelRoute? activeRoute;
  final int? currentUserId;
  final int? highlightedId;
  final VoidCallback? onMapReady;
  final void Function(TravelSpot spot)? onMarkerTap;
  final void Function(LatLng position)? onLongPress;

  const TravelMapWidget({
    super.key,
    required this.spots,
    this.allSpots,
    this.routes = const [],
    this.activeRoute,
    this.currentUserId,
    this.highlightedId,
    this.onMapReady,
    this.onMarkerTap,
    this.onLongPress,
  });

  @override
  State<TravelMapWidget> createState() => TravelMapWidgetState();
}

class TravelMapWidgetState extends State<TravelMapWidget> {
  static const LatLng _defaultCenter = LatLng(30.5728, 104.0668);
  static const String _androidMapKey = '2209d350da6804c16673f5c36d52f64b';

  AMapController? _controller;
  TravelMapStyle _style = TravelMapStyle.normal;
  AMapLocation? _lastLocation;
  String? _approvalNumber;
  bool _trafficEnabled = false;
  bool _isLocating = false;
  bool _hasFitBounds = false;
  bool _locationEnabled = false;
  bool _mapReady = false;

  Future<bool> _ensureLocationLayer({bool requestPermission = false}) async {
    var status = await Permission.location.status;
    if (!status.isGranted && requestPermission) {
      status = await Permission.location.request();
    }

    if (!status.isGranted) {
      if (!requestPermission) {
        return false;
      }
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              '\u9700\u8981\u5b9a\u4f4d\u6743\u9650\u540e\u624d\u80fd\u663e\u793a\u5f53\u524d\u4f4d\u7f6e'),
          behavior: SnackBarBehavior.floating,
          action: status.isPermanentlyDenied
              ? SnackBarAction(
                  label: '\u8bbe\u7f6e',
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
      return false;
    }

    if (!_locationEnabled && mounted) {
      setState(() => _locationEnabled = true);
    }
    return true;
  }

  Future<void> _primeLocationLayer() async {
    if (_locationEnabled || !mounted) return;
    await _ensureLocationLayer();
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        !(lat == 0 && lng == 0);
  }

  @override
  void didUpdateWidget(covariant TravelMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_mapReady) return;
    if (!_hasFitBounds && widget.spots.isNotEmpty && _controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fitBounds();
        _hasFitBounds = true;
      });
    }
    if (oldWidget.activeRoute != widget.activeRoute &&
        widget.activeRoute?.path.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => fitBounds());
    }
  }

  void animateToSpot(TravelSpot spot) {
    if (!_isValidCoordinate(spot.lat, spot.lng)) return;
    moveToLocation(spot.lat, spot.lng, zoom: 16);
  }

  Future<void> moveToLocation(
    double lat,
    double lng, {
    double zoom = 14,
  }) async {
    try {
      await _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom),
        animated: true,
        duration: 650,
      );
    } catch (_) {
      // Ignore transient native camera errors while the platform view is mounting.
    }
  }

  Future<void> fitBounds() async {
    final points = <LatLng>[
      ...widget.spots
          .where((s) => _isValidCoordinate(s.lat, s.lng))
          .map((s) => LatLng(s.lat, s.lng)),
      ...?widget.activeRoute?.path
          .where((p) => _isValidCoordinate(p.lat, p.lng))
          .map((p) => LatLng(p.lat, p.lng)),
    ];
    if (points.isEmpty || _controller == null) return;
    if (points.length == 1) {
      await moveToLocation(
        points.first.latitude,
        points.first.longitude,
        zoom: 13,
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    try {
      await _controller!.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          72,
        ),
        animated: true,
        duration: 650,
      );
    } catch (_) {
      await moveToLocation(points.first.latitude, points.first.longitude);
    }
  }

  Future<void> locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      final locationReady = await _ensureLocationLayer(requestPermission: true);
      if (!locationReady) {
        return;
      }

      if (_lastLocation == null) {
        for (var i = 0; i < 8 && mounted && _lastLocation == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }

      final location = _lastLocation;
      if (location != null) {
        await _controller?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: location.latLng,
              zoom: 16,
              bearing: location.bearing.isFinite ? location.bearing : 0,
              tilt: 0,
            ),
          ),
          animated: true,
          duration: 650,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\u6b63\u5728\u83b7\u53d6\u5b9a\u4f4d\uff0c\u7a0d\u7b49\u4e00\u4e0b\u518d\u8bd5'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _cycleStyle() {
    final nextIndex = (_style.index + 1) % TravelMapStyle.values.length;
    setState(() => _style = TravelMapStyle.values[nextIndex]);
  }

  void cycleMapStyle() {
    _cycleStyle();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AMapWidget(
          apiKey: const AMapApiKey(androidKey: _androidMapKey),
          privacyStatement: const AMapPrivacyStatement(
            hasContains: true,
            hasShow: true,
            hasAgree: true,
          ),
          initialCameraPosition: const CameraPosition(
            target: _defaultCenter,
            zoom: 4,
          ),
          mapType: _style.type,
          trafficEnabled: _trafficEnabled,
          compassEnabled: true,
          scaleEnabled: true,
          touchPoiEnabled: true,
          myLocationStyleOptions: _locationEnabled
              ? MyLocationStyleOptions(
                  true,
                  trackingMode: MyLocationTrackingMode.locationRotate,
                  circleFillColor: const Color(0x331677FF),
                  circleStrokeColor: const Color(0xFF1677FF),
                  circleStrokeWidth: 1,
                )
              : null,
          markers: _mapReady ? _buildMarkers() : const <Marker>{},
          polylines: _mapReady ? _buildPolylines() : const <Polyline>{},
          onMapCreated: (controller) async {
            _controller = controller;
            try {
              _approvalNumber = await controller.getMapContentApprovalNumber();
            } catch (_) {
              _approvalNumber = null;
            }
            if (mounted) {
              setState(() {
                _mapReady = true;
              });
            } else {
              _mapReady = true;
            }
            widget.onMapReady?.call();
            _primeLocationLayer();
            if (widget.spots.isNotEmpty) {
              Future<void>.delayed(const Duration(milliseconds: 320), () {
                if (!mounted) return;
                fitBounds();
                _hasFitBounds = true;
              });
            }
          },
          onLongPress: widget.onLongPress,
          onLocationChanged: (location) {
            if (!mounted) return;
            setState(() => _lastLocation = location);
          },
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _MapButton(
                icon: _style.icon,
                tooltip:
                    '\u5207\u6362\u5730\u56fe\u6837\u5f0f\uff1a${_style.label}',
                onTap: _cycleStyle,
              ),
              const SizedBox(height: 10),
              _MapButton(
                icon: _trafficEnabled
                    ? Icons.traffic_rounded
                    : Icons.traffic_outlined,
                tooltip: _trafficEnabled
                    ? '\u5173\u95ed\u8def\u51b5'
                    : '\u6253\u5f00\u8def\u51b5',
                isActive: _trafficEnabled,
                onTap: () => setState(() {
                  _trafficEnabled = !_trafficEnabled;
                }),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: Column(
            children: [
              if (widget.spots.length > 1 ||
                  widget.activeRoute?.path.isNotEmpty == true) ...[
                _MapButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: '\u67e5\u770b\u5168\u90e8\u6807\u8bb0',
                  onTap: fitBounds,
                ),
                const SizedBox(height: 10),
              ],
              _MapButton(
                icon: _isLocating ? null : Icons.my_location_rounded,
                tooltip: '\u5b9a\u4f4d\u5230\u6211',
                onTap: locateMe,
                isLoading: _isLocating,
              ),
            ],
          ),
        ),
        if (_lastLocation != null)
          Positioned(
            left: 12,
            bottom: 12,
            child: _LocationBadge(location: _lastLocation!),
          ),
        if (_approvalNumber != null && _approvalNumber!.isNotEmpty)
          Positioned(
            left: 12,
            top: 12,
            child: _ApprovalBadge(text: _approvalNumber!),
          ),
      ],
    );
  }

  Set<Marker> _buildMarkers() {
    return widget.spots
        .where((spot) => _isValidCoordinate(spot.lat, spot.lng))
        .map((spot) {
      final highlighted = widget.highlightedId == spot.id;
      return Marker(
        position: LatLng(spot.lat, spot.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          highlighted ? BitmapDescriptor.hueRose : _spotHue(spot),
        ),
        infoWindow: InfoWindow(
          title: spot.name,
          snippet: [
            if (spot.city.isNotEmpty) spot.city,
            if ((spot.creatorNickname ?? '').isNotEmpty) spot.creatorNickname!,
          ].join(' · '),
        ),
        zIndex: highlighted ? 20 : 10,
        onTap: (_) => widget.onMarkerTap?.call(spot),
      );
    }).toSet();
  }

  Set<Polyline> _buildPolylines() {
    final lines = <Polyline>{};
    final activeRoute = widget.activeRoute;
    final activeRoutePoints = activeRoute?.path
            .where((p) => _isValidCoordinate(p.lat, p.lng))
            .map((p) => LatLng(p.lat, p.lng))
            .toList() ??
        const <LatLng>[];
    if (activeRoute != null && activeRoutePoints.length > 1) {
      final points = activeRoutePoints;
      lines.add(
        Polyline(
          points: points,
          width: 12,
          color: LoveGirlTheme.primary.withAlpha(70),
          capType: CapType.round,
          joinType: JoinType.round,
        ),
      );
      lines.add(
        Polyline(
          points: points,
          width: 7,
          color: LoveGirlTheme.primary,
          capType: CapType.round,
          joinType: JoinType.round,
        ),
      );
      return lines;
    }

    final visited = widget.spots
        .where((s) => s.status == 'visited' && _isValidCoordinate(s.lat, s.lng))
        .toList()
      ..sort((a, b) => (a.visitedDate ?? '').compareTo(b.visitedDate ?? ''));
    if (visited.length > 1) {
      lines.add(
        Polyline(
          points: visited.map((s) => LatLng(s.lat, s.lng)).toList(),
          width: 5,
          color: LoveGirlTheme.primary.withAlpha(150),
          capType: CapType.round,
          joinType: JoinType.round,
        ),
      );
    }
    return lines;
  }

  double _statusHue(String status) {
    switch (status) {
      case 'visited':
        return BitmapDescriptor.hueGreen;
      case 'planned':
        return BitmapDescriptor.hueViolet;
      case 'wish':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueRose;
    }
  }

  double _spotHue(TravelSpot spot) {
    final owner = spot.createdBy;
    if (owner == null || owner <= 0) return _statusHue(spot.status);
    if (spot.status == 'visited') return BitmapDescriptor.hueGreen;
    if (widget.currentUserId != null && owner == widget.currentUserId) {
      return BitmapDescriptor.hueAzure;
    }
    return BitmapDescriptor.hueOrange;
  }
}

class _LocationBadge extends StatelessWidget {
  final AMapLocation location;

  const _LocationBadge({required this.location});

  @override
  Widget build(BuildContext context) {
    final accuracy = location.accuracy > 0
        ? ' \u00b7 \u7cbe\u5ea6 ${location.accuracy.round()} \u7c73'
        : '';
    final bearing = location.bearing > 0
        ? ' \u00b7 \u671d\u5411${location.bearing.round()}\u00b0'
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.navigation_rounded,
            size: 14,
            color: Color(0xFF1677FF),
          ),
          const SizedBox(width: 5),
          Text(
            '\u5f53\u524d\u4f4d\u7f6e$accuracy$bearing',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  final String text;

  const _ApprovalBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(210),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: LoveGirlTheme.textMuted),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData? icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isActive;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isLoading = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                isActive ? LoveGirlTheme.primary : Colors.white.withAlpha(235),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(24),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
                      color: LoveGirlTheme.primary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: isActive ? Colors.white : LoveGirlTheme.textPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
