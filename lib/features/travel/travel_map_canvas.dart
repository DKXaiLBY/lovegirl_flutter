import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/travel.dart' show TravelSpot;
import '../../utils/lovegirl_theme.dart';
import 'map_platform.dart';
import 'travel_workspace.dart';
import 'journey.dart';
import 'journey_controller.dart';

/// Stable native surface: no list, search, navigation or location-on-entry logic.
class TravelMapCanvas extends StatefulWidget {
  final List<TravelSpot> places;
  final int? selectedId;
  final TravelCamera initialCamera;
  final ValueChanged<TravelCamera> onCameraSettled;
  final ValueChanged<TravelSpot> onSelect;
  final ValueChanged<PlaceChoice> onPick;
  final VoidCallback? onReady;
  final List<JourneyStop>? journeyStops;
  final List<JourneyLeg> journeyLegs;
  final String? selectedStopKey;
  final ValueChanged<JourneyStop>? onStopSelect;
  const TravelMapCanvas(
      {super.key,
      required this.places,
      this.selectedId,
      required this.initialCamera,
      required this.onCameraSettled,
      required this.onSelect,
      required this.onPick,
      this.onReady,
      this.journeyStops,
      this.journeyLegs = const [],
      this.selectedStopKey,
      this.onStopSelect});

  @override
  State<TravelMapCanvas> createState() => TravelMapCanvasState();
}

class TravelMapCanvasState extends State<TravelMapCanvas> {
  AMapController? _controller;
  late TravelCamera _camera = widget.initialCamera;
  late final Future<bool> _supported =
      TravelMapPlatform.isSupported().catchError((_) => false);
  final Map<int, BitmapDescriptor> _clusterIcons = {};
  final Set<int> _pendingIcons = {};
  bool _locationVisible = false;
  Completer<LatLng>? _fix;
  int _intent = 0;

  Future<void> focus(double lat, double lng, {double zoom = 15}) async {
    _intent++;
    final changedZoom = _camera.zoom.floor() != zoom.floor();
    _camera = TravelCamera(lat, lng, zoom);
    if (changedZoom && mounted) setState(() {});
    widget.onCameraSettled(_camera);
    await _controller?.moveCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), zoom),
        animated: true,
        duration: 350);
  }

  Future<void> locate() async {
    if (_fix != null) return;
    final operation = ++_intent;
    var permission = await Permission.locationWhenInUse.status;
    if (!permission.isGranted) {
      permission = await Permission.locationWhenInUse.request();
    }
    if (!mounted) return;
    if (!permission.isGranted) {
      throw StateError('需要定位权限；也可以搜索或长按地图选点');
    }
    final fix = Completer<LatLng>();
    _fix = fix;
    setState(() => _locationVisible = true);
    unawaited(_systemFix().then((point) {
      if (mounted &&
          identical(_fix, fix) &&
          !fix.isCompleted &&
          point != null) {
        fix.complete(point);
      }
    }));
    try {
      final point = await fix.future.timeout(const Duration(seconds: 12));
      if (mounted && operation == _intent) {
        await focus(point.latitude, point.longitude);
      }
    } on TimeoutException {
      throw StateError('暂时没有拿到位置，请搜索地点或长按地图选点');
    } finally {
      if (identical(_fix, fix)) _fix = null;
    }
  }

  Future<LatLng?> _systemFix() async {
    try {
      var position = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true);
      if (position == null ||
          DateTime.now().difference(position.timestamp).abs() >
              const Duration(minutes: 15) ||
          position.accuracy > 1000) {
        position = await Geolocator.getCurrentPosition(
          forceAndroidLocationManager: true,
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      }
      if (!mounted) return null;
      return await TravelMapPlatform.fromGps(
          position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _prepareIcon(int count,
      {bool numbered = false, bool selected = false}) async {
    final key = count + (numbered ? 10000 : 0) + (selected ? 20000 : 0);
    if (_clusterIcons.containsKey(key) || !_pendingIcons.add(key)) return;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
        const Offset(36, 36),
        33,
        Paint()
          ..color = numbered && !selected
              ? const Color(0xff24798e)
              : const Color(0xFF1F2126));
    canvas.drawCircle(
        const Offset(36, 36),
        33,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    final label = TextPainter(
        text: TextSpan(
            text: '$count',
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: 66);
    label.paint(canvas, Offset(36 - label.width / 2, 36 - label.height / 2));
    final picture = recorder.endRecording();
    final image = await picture.toImage(72, 72);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null || !mounted) return;
    _clusterIcons[key] = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    _pendingIcons.remove(key);
    setState(() {});
  }

  Set<Marker> _markers() {
    final stops = widget.journeyStops;
    if (stops != null) {
      return {
        for (var i = 0; i < stops.length; i++)
          if (stops[i].place != null && hasMapPosition(stops[i].place!))
            _stopMarker(stops[i], i + 1)
      };
    }
    return clusterPlaces(widget.places, _camera.zoom).map((cluster) {
      final grouped = cluster.places.length > 1;
      if (grouped) unawaited(_prepareIcon(cluster.places.length));
      final selected =
          cluster.places.any((place) => place.id == widget.selectedId);
      return Marker(
        position: LatLng(cluster.lat, cluster.lng),
        icon: grouped
            ? (_clusterIcons[cluster.places.length] ??
                BitmapDescriptor.defaultMarker)
            : BitmapDescriptor.defaultMarkerWithHue(selected
                ? BitmapDescriptor.hueAzure
                : cluster.places.first.status == 'visited'
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueViolet),
        infoWindowEnable: false,
        onTap: (_) {
          if (grouped) {
            focus(cluster.lat, cluster.lng,
                zoom: (_camera.zoom + 2).clamp(1, 20));
          } else {
            widget.onSelect(cluster.places.first);
          }
        },
      )..setIdForCopy(grouped
          ? 'cluster_${cluster.id}'
          : 'place_${cluster.places.first.id}');
    }).toSet();
  }

  Marker _stopMarker(JourneyStop stop, int number) {
    final selected = stop.key == widget.selectedStopKey;
    unawaited(_prepareIcon(number, numbered: true, selected: selected));
    return Marker(
        position: LatLng(stop.place!.lat, stop.place!.lng),
        icon: _clusterIcons[number + 10000 + (selected ? 20000 : 0)] ??
            BitmapDescriptor.defaultMarker,
        infoWindowEnable: false,
        onTap: (_) => widget.onStopSelect?.call(stop))
      ..setIdForCopy('journey_${stop.key}');
  }

  Set<Polyline> _lines() => {
        for (final leg in widget.journeyLegs)
          if (leg.points.length > 1)
            Polyline(
                points: leg.points.map((p) => LatLng(p.lat, p.lng)).toList(),
                color: leg.toKey == widget.selectedStopKey
                    ? (context.lgIsDark
                        ? const Color(0xfff2f4f6)
                        : const Color(0xff20242b))
                    : const Color(0xff3398ae),
                width: 5,
                capType: CapType.round,
                joinType: JoinType.round,
                dashLineType: leg.mode == 'walking'
                    ? DashLineType.circle
                    : DashLineType.none)
              ..setIdForCopy('route_${leg.toKey}')
      };

  @override
  void dispose() {
    _intent++;
    _fix = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _supported,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(color: Color(0xFFE8EBEE));
        }
        if (!snapshot.data!) {
          return ColoredBox(
              color: context.lgBg,
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text('此设备暂不支持真实地图，仍可搜索和管理地点',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.lgTextSecondary)))));
        }
        return AMapWidget(
          key: const ValueKey('travel_native_surface'),
          apiKey: const AMapApiKey(androidKey: TravelMapPlatform.androidKey),
          privacyStatement: const AMapPrivacyStatement(
              hasContains: true, hasShow: true, hasAgree: true),
          initialCameraPosition: CameraPosition(
              target:
                  LatLng(widget.initialCamera.lat, widget.initialCamera.lng),
              zoom: widget.initialCamera.zoom),
          mapType: context.lgIsDark ? MapType.night : MapType.normal,
          compassEnabled: false,
          scaleEnabled: true,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer())
          },
          markers: _markers(),
          polylines: _lines(),
          myLocationStyleOptions: _locationVisible
              ? MyLocationStyleOptions(true,
                  trackingMode: MyLocationTrackingMode.show)
              : null,
          onMapCreated: (controller) {
            _controller = controller;
            widget.onReady?.call();
          },
          onCameraMove: (_) {
            _intent++;
          },
          onCameraMoveEnd: (position) {
            final bucketChanged = _camera.zoom.floor() != position.zoom.floor();
            _camera = TravelCamera(position.target.latitude,
                position.target.longitude, position.zoom);
            widget.onCameraSettled(_camera);
            if (bucketChanged && mounted) setState(() {});
          },
          onLocationChanged: (location) {
            final fix = _fix;
            final point = location.latLng;
            if (fix != null &&
                !fix.isCompleted &&
                point.latitude.isFinite &&
                point.longitude.isFinite &&
                (point.latitude != 0 || point.longitude != 0)) {
              fix.complete(point);
            }
          },
          onLongPress: (point) {
            _intent++;
            widget.onPick(PlaceChoice(
                name: '', lat: point.latitude, lng: point.longitude));
          },
          onPoiTouched: (poi) {
            if (poi.latLng != null) {
              _intent++;
              widget.onPick(PlaceChoice(
                  name: poi.name ?? '',
                  lat: poi.latLng!.latitude,
                  lng: poi.latLng!.longitude));
            }
          },
        );
      },
    );
  }
}
