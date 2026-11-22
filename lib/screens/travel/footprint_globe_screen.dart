import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_globe/flutter_globe.dart';

import '../../features/creations/creation_files.dart';
import '../../features/travel/travel_map_canvas.dart';
import '../../features/travel/travel_workspace.dart'
    show TravelCamera, hasMapPosition;
import '../../models/travel.dart';
import '../../services/app_storage.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'china_memory_map_screen.dart';
import 'footprint_land.dart';
import 'travel_memory_screen.dart';

class FootprintGlobeScreen extends StatefulWidget {
  final List<TravelSpot> spots;
  final ValueChanged<TravelSpot> onChanged;
  final ValueChanged<TravelSpot> onShowOnMap;

  const FootprintGlobeScreen({
    super.key,
    required this.spots,
    required this.onChanged,
    required this.onShowOnMap,
  });

  @override
  State<FootprintGlobeScreen> createState() => _FootprintGlobeScreenState();
}

class _FootprintGlobeScreenState extends State<FootprintGlobeScreen> {
  final _globe = GlobeController(autoRotate: false);
  final _updates = <int, TravelSpot>{};
  FootprintLand? _land;
  bool _landUnavailable = false;
  String? _selected;

  List<TravelSpot> get _spots =>
      widget.spots.map((spot) => _updates[spot.id] ?? spot).toList();

  Map<String, List<TravelSpot>> get _cities {
    final visited = _spots
        .where((spot) => spot.status == 'visited' && hasMapPosition(spot))
        .toList()
      ..sort((a, b) {
        final byDate = (b.visitedDate ?? b.checkedInAt ?? '')
            .compareTo(a.visitedDate ?? a.checkedInAt ?? '');
        return byDate == 0 ? b.id.compareTo(a.id) : byDate;
      });
    final cities = <String, List<TravelSpot>>{};
    for (final spot in visited) {
      final city = spot.city.trim().isEmpty ? spot.name : spot.city.trim();
      (cities[city] ??= []).add(spot);
    }
    return cities;
  }

  GlobeCoordinate _coordinate(TravelSpot spot) =>
      GlobeCoordinate(latitude: spot.lat, longitude: spot.lng);

  @override
  void initState() {
    super.initState();
    final cities = _cities;
    _selected = cities.keys.firstOrNull;
    _reset(cities);
    _loadLand();
  }

  Future<void> _loadLand() async {
    try {
      final land = await FootprintLand.load();
      if (!mounted) {
        land.dispose();
        return;
      }
      setState(() => _land = land);
    } catch (_) {
      if (mounted) setState(() => _landUnavailable = true);
    }
  }

  void _reset(Map<String, List<TravelSpot>> cities) {
    _globe.zoom = 1;
    final first = cities[_selected]?.firstOrNull;
    _globe.lookAt(first == null
        ? const GlobeCoordinate(latitude: 30, longitude: 105)
        : _coordinate(first));
  }

  @override
  void dispose() {
    _globe.dispose();
    _land?.dispose();
    super.dispose();
  }

  void _updated(TravelSpot spot) {
    widget.onChanged(spot);
    if (mounted) setState(() => _updates[spot.id] = spot);
  }

  void _story(TravelSpot place) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TravelMemoryScreen(
            spot: place, onChanged: _updated, onShowOnMap: widget.onShowOnMap),
      ));

  void _overview() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChinaMemoryMapScreen(
            spots: _spots,
            onChanged: _updated,
            onShowOnMap: widget.onShowOnMap),
      ));

  @override
  Widget build(BuildContext context) {
    final cities = _cities;
    final active =
        cities.containsKey(_selected) ? _selected : cities.keys.firstOrNull;
    final count = cities.values.fold(0, (count, spots) => count + spots.length);
    final dark = context.lgIsDark;
    final land = _land;
    if (land != null) land.dark = dark;
    return Scaffold(
      body: RebuildPageBackground(
          child: Stack(fit: StackFit.expand, children: [
        if (land != null)
          RepaintBoundary(
              child: Globe(
            controller: _globe,
            projection: GlobeProjection.orthographic,
            layers: [land],
            radiusMultiplier: .93,
            introAnimation: GlobeIntroAnimations.none,
            theme: GlobeTheme(
              surface:
                  const GlobeSurfaceStyle(pointOpacity: 0, rearPointOpacity: 0),
              atmosphere: GlobeAtmosphereStyle(
                  color:
                      dark ? const Color(0xff366caa) : const Color(0xffa4d7f5),
                  altitude: .12,
                  glowIntensity: .35),
            ),
            autoRotate: false,
            enableZoom: true,
            semanticLabel: '旋转或缩放足迹地球',
            markers: [
              for (final entry in cities.entries)
                GlobeMarker(
                  coordinate: _coordinate(entry.value.first),
                  label: entry.key == active ? entry.key : null,
                  pulse: false,
                  size: entry.key == active ? 7 : 5,
                  color: const Color(0xff2876b4),
                  onTap: () => setState(() => _selected = entry.key),
                ),
            ],
          ))
        else
          Center(
              child: _landUnavailable
                  ? TextButton(
                      onPressed: _overview, child: const Text('查看省市足迹'))
                  : const CircularProgressIndicator()),
        SafeArea(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(children: [
            Row(children: [
              RebuildGlassButton(
                  label: '返回',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('足迹地球',
                      style: TextStyle(
                          fontSize: 23, fontWeight: FontWeight.w800))),
              RebuildGlassButton(
                  label: '省市总览',
                  showLabel: true,
                  icon: Icons.map_outlined,
                  onPressed: _overview),
            ]),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: RebuildGlass(
                  radius: 20,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  child: Text('$count 个已去地点 · ${cities.length} 个地区'),
                )),
            const Spacer(),
            if (land != null)
              Align(
                  alignment: Alignment.centerRight,
                  child: RebuildGlassButton(
                      label: '复位地球',
                      icon: Icons.public,
                      onPressed: () => _reset(cities))),
            const SizedBox(height: 8),
            if (active == null)
              RebuildGlass(
                  radius: 22,
                  child: const ListTile(
                    title: Text('还没有点亮的足迹'),
                    subtitle: Text('把地点标为「已去」，就会出现在这里。'),
                  ))
            else
              _placeSheet(active, cities[active]!),
          ]),
        )),
      ])),
    );
  }

  Widget _placeSheet(String city, List<TravelSpot> places) => RebuildGlass(
        radius: 22,
        child: ListTile(
          title: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: _thumbnail(places.first),
          subtitle: Text('${places.length} 个地点 · 放大查看'),
          trailing: const Icon(Icons.open_in_full_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  _FootprintCity(city: city, places: places, onPlace: _story))),
        ),
      );
}

Widget _thumbnail(TravelSpot place) {
  final cover = place.coverImage ?? place.photos.firstOrNull;
  return ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: SizedBox.square(
      dimension: 42,
      child: cover == null || cover.isEmpty
          ? const Icon(Icons.location_on_outlined)
          : CachedNetworkImage(
              cacheManager: MediaCache.instance,
              imageUrl: creationUrl(cover),
              fit: BoxFit.cover,
              memCacheWidth: 128,
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.location_on_outlined)),
    ),
  );
}

class _FootprintCity extends StatefulWidget {
  final String city;
  final List<TravelSpot> places;
  final ValueChanged<TravelSpot> onPlace;
  const _FootprintCity(
      {required this.city, required this.places, required this.onPlace});

  @override
  State<_FootprintCity> createState() => _FootprintCityState();
}

class _FootprintCityState extends State<_FootprintCity> {
  final _canvas = GlobalKey<TravelMapCanvasState>();
  late TravelSpot _selected = widget.places.first;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.city),
            flexibleSpace: const RebuildGlassHeader()),
        body: Stack(fit: StackFit.expand, children: [
          TravelMapCanvas(
            key: _canvas,
            places: widget.places,
            selectedId: _selected.id,
            initialCamera: TravelCamera(_selected.lat, _selected.lng, 14),
            onCameraSettled: (_) {},
            onPick: (_) {},
            onSelect: (place) => setState(() => _selected = place),
            onReady: () => _canvas.currentState?.fitJourney(widget.places,
                top: 24, bottom: 155, animated: false),
            bottomOverlay: 115,
          ),
          Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: RebuildGlass(
                    radius: 22,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: _thumbnail(_selected),
                          title: Text(_selected.name),
                          subtitle: Text(_selected.visitedDate
                                  ?.split('T')
                                  .first
                                  .split(' ')
                                  .first ??
                              '已去地点'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onPlace(_selected),
                        ),
                        SizedBox(
                            height: 48,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              itemCount: widget.places.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final spot = widget.places[index];
                                return RebuildChoiceChip(
                                    label: Text(spot.name),
                                    selected: spot.id == _selected.id,
                                    onSelected: (_) {
                                      setState(() => _selected = spot);
                                      _canvas.currentState
                                          ?.focus(spot.lat, spot.lng);
                                    });
                              },
                            )),
                      ],
                    )),
              )),
        ]),
      );
}
