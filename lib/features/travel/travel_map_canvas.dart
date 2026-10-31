import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/travel.dart' show TravelSpot;
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';
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
  final double bottomOverlay;
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
      this.onStopSelect,
      this.bottomOverlay = 0});

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
  final Map<String, BitmapDescriptor> _photoIcons = {};
  final Set<String> _pendingPhotos = {};
  final Set<String> _failedPhotos = {};
  bool _locationVisible = false;
  Completer<LatLng>? _fix;
  int _intent = 0;
  int? _logoInset;

  Future<void> setBottomOverlay(double height) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final pixels =
        ((height + 8) * MediaQuery.devicePixelRatioOf(context)).round();
    if (_logoInset == pixels) return;
    _logoInset = pixels;
    try {
      await TravelMapPlatform.setLogoBottomInset(controller.mapId, pixels);
    } catch (error) {
      _logoInset = null;
      debugPrint('Travel map overlay inset could not be applied: $error');
    }
  }

  @override
  void didUpdateWidget(covariant TravelMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bottomOverlay != widget.bottomOverlay) {
      unawaited(setBottomOverlay(widget.bottomOverlay));
    }
  }

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
    var photoCount = 0;
    return clusterPlaces(widget.places, _camera.zoom).map((cluster) {
      final grouped = cluster.places.length > 1;
      if (grouped) unawaited(_prepareIcon(cluster.places.length));
      final selected =
          cluster.places.any((place) => place.id == widget.selectedId);
      final place = cluster.places.first;
      final photo = place.coverImage ??
          (place.photos.isEmpty ? null : place.photos.first);
      final photoKey = '${place.id}|${place.name}|$photo|${context.lgIsDark}';
      final showPhoto =
          !grouped && photo != null && _camera.zoom >= 11 && photoCount++ < 8;
      if (showPhoto) unawaited(_preparePhotoIcon(place, photo, photoKey));
      final photoIcon = showPhoto ? _photoIcons[photoKey] : null;
      return Marker(
        position: LatLng(cluster.lat, cluster.lng),
        anchor: photoIcon == null ? const Offset(.5, 1) : const Offset(.1, .76),
        icon: photoIcon ??
            (grouped
                ? (_clusterIcons[cluster.places.length] ??
                    BitmapDescriptor.defaultMarker)
                : BitmapDescriptor.defaultMarkerWithHue(selected
                    ? BitmapDescriptor.hueAzure
                    : cluster.places.first.status == 'visited'
                        ? BitmapDescriptor.hueGreen
                        : BitmapDescriptor.hueAzure)),
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

  Future<void> _preparePhotoIcon(
      TravelSpot place, String path, String key) async {
    if (_photoIcons.containsKey(key) ||
        _failedPhotos.contains(key) ||
        !_pendingPhotos.add(key)) {
      return;
    }
    final url = path.startsWith('http') ? path : AppConstants.baseUrl + path;
    final dark = context.lgIsDark;
    final stream = ResizeImage(CachedNetworkImageProvider(url), width: 240)
        .resolve(ImageConfiguration.empty);
    final ready = Completer<ImageInfo>();
    final listener = ImageStreamListener((info, _) {
      if (!ready.isCompleted) {
        ready.complete(info);
      } else {
        info.dispose();
      }
    }, onError: (Object error, StackTrace? stack) {
      if (!ready.isCompleted) {
        ready.completeError(error, stack);
      }
    });
    stream.addListener(listener);
    ImageInfo? photo;
    try {
      photo = await ready.future.timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final frame = RRect.fromRectAndRadius(
          const Rect.fromLTWH(6, 4, 124, 84), const Radius.circular(14));
      canvas.drawShadow(
          Path()..addRRect(frame), Colors.black.withAlpha(70), 4, true);
      canvas.drawRRect(frame, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipRRect(frame.deflate(3));
      paintImage(
          canvas: canvas,
          rect: frame.outerRect.deflate(3),
          image: photo.image,
          fit: BoxFit.cover);
      canvas.restore();
      canvas.drawCircle(
          const Offset(20, 110), 12, Paint()..color = Colors.white);
      canvas.drawCircle(
          const Offset(20, 110), 8, Paint()..color = const Color(0xff2684ff));
      final label = TextPainter(
          text: TextSpan(
              text: place.name,
              style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  color:
                      dark ? const Color(0xfff1f5fa) : const Color(0xff18212b),
                  shadows: [
                    Shadow(
                        color: dark ? Colors.black : Colors.white,
                        blurRadius: 5),
                    Shadow(
                        color: dark ? Colors.black : Colors.white,
                        blurRadius: 3)
                  ])),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…')
        ..layout(maxWidth: 158);
      label.paint(canvas, const Offset(38, 95));
      label.dispose();
      final picture = recorder.endRecording();
      final bitmap = await picture.toImage(200, 144);
      final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      bitmap.dispose();
      picture.dispose();
      if (!mounted || bytes == null) return;
      if (_photoIcons.length >= 24) _photoIcons.remove(_photoIcons.keys.first);
      setState(() => _photoIcons[key] =
          BitmapDescriptor.fromBytes(bytes.buffer.asUint8List()));
    } catch (_) {
      _failedPhotos.add(key);
    } finally {
      photo?.dispose();
      stream.removeListener(listener);
      _pendingPhotos.remove(key);
    }
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
            unawaited(setBottomOverlay(widget.bottomOverlay));
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
