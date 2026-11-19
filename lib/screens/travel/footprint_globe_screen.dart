import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_globe/flutter_globe.dart';

import '../../features/travel/travel_workspace.dart' show hasMapPosition;
import '../../models/travel.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/glass_feature_icon.dart';
import '../../widgets/rebuild_controls.dart';
import 'china_memory_map_screen.dart';
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

  GlobeCoordinate _coordinate(TravelSpot s) =>
      GlobeCoordinate(latitude: s.lat, longitude: s.lng);

  @override
  void initState() {
    super.initState();
    final cities = _cities;
    _selected = cities.keys.firstOrNull;
    _globe.lookAt(_selected == null
        ? const GlobeCoordinate(latitude: 32, longitude: 104)
        : _coordinate(cities[_selected]!.first));
  }

  @override
  void dispose() {
    _globe.dispose();
    super.dispose();
  }

  void _updated(TravelSpot spot) {
    widget.onChanged(spot);
    if (mounted) setState(() => _updates[spot.id] = spot);
  }

  @override
  Widget build(BuildContext context) {
    final cities = _cities;
    final active =
        cities.containsKey(_selected) ? _selected : cities.keys.firstOrNull;
    final places = cities[active] ?? const <TravelSpot>[];
    final count =
        cities.values.fold<int>(0, (count, spots) => count + spots.length);
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: context.lgIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: const Text('足迹地球'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChinaMemoryMapScreen(
                spots: _spots,
                onChanged: _updated,
                onShowOnMap: widget.onShowOnMap,
              ),
            )),
            child: const Text('省市总览'),
          ),
        ],
      ),
      body: RebuildPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text('${cities.length} 座城市 · $count 个已去地点',
                style: TextStyle(color: context.lgTextSecondary)),
            AspectRatio(
              aspectRatio: 1,
              child: Globe(
                controller: _globe,
                skin: GlobeSkins.realistic,
                autoRotate: false,
                enableZoom: true,
                semanticLabel: '旋转或缩放足迹地球',
                markers: [
                  for (final entry in cities.entries)
                    GlobeMarker(
                      coordinate: _coordinate(entry.value.first),
                      label: entry.key == active ? entry.key : null,
                      pulse: false,
                      size: entry.key == active ? 7 : 4,
                      color: const Color(0xff1d78be),
                      onTap: () => setState(() => _selected = entry.key),
                    ),
                ],
              ),
            ),
            if (cities.isEmpty)
              const ListTile(
                leading: GlassFeatureIcon(GlassFeature.footprint),
                title: Text('还没有点亮的足迹'),
                subtitle: Text('在旅行地图把地点标为「已去」，这里就会出现它。'),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in cities.entries)
                    RebuildChoiceChip(
                      label: Text(entry.key),
                      selected: entry.key == active,
                      onSelected: (_) {
                        setState(() => _selected = entry.key);
                        _globe.lookAt(_coordinate(entry.value.first));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final place in places)
                ListTile(
                  title: Text(place.name),
                  subtitle: place.visitedDate == null
                      ? null
                      : Text(place.visitedDate!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TravelMemoryScreen(
                      spot: place,
                      onChanged: _updated,
                      onShowOnMap: widget.onShowOnMap,
                    ),
                  )),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
