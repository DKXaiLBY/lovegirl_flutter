import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/travel.dart' show TravelSpot;
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import 'place_search.dart';
import 'travel_map_canvas.dart';
import 'travel_workspace.dart';

class TravelPlacePicker extends StatefulWidget {
  final ApiService api;
  final PlaceChoice? initial;
  final TravelCamera? initialCamera;
  const TravelPlacePicker(
      {super.key, required this.api, this.initial, this.initialCamera});
  @override
  State<TravelPlacePicker> createState() => _TravelPlacePickerState();
}

class _TravelPlacePickerState extends State<TravelPlacePicker> {
  final _map = GlobalKey<TravelMapCanvasState>();
  late final _searchSpace = TravelWorkspace(api: widget.api);
  late PlaceChoice? _picked = widget.initial;
  int _lookup = 0;
  late TravelCamera _camera = widget.initial == null
      ? widget.initialCamera ?? const TravelCamera(35.86, 104.20, 4)
      : TravelCamera(widget.initial!.lat, widget.initial!.lng, 15);

  Future<void> _pick(PlaceChoice point) async {
    final generation = ++_lookup;
    setState(() => _picked =
        PlaceChoice(name: point.name, lat: point.lat, lng: point.lng));
    try {
      final response = await widget.api.regeoAmap(point.lat, point.lng);
      if (!mounted || generation != _lookup) return;
      final data = response.data?['data'];
      if (data is Map) {
        setState(() => _picked = PlaceChoice(
            name: point.name,
            city: data['city']?.toString() ?? '',
            address: data['address']?.toString() ?? '',
            lat: point.lat,
            lng: point.lng));
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    final value = await Navigator.of(context).push<PlaceChoice>(
        MaterialPageRoute(
            builder: (_) => TravelPlaceSearch(workspace: _searchSpace)));
    if (value == null || !mounted) return;
    _lookup++;
    setState(() => _picked = value);
    _map.currentState?.focus(value.lat, value.lng);
  }

  @override
  void dispose() {
    _lookup++;
    _searchSpace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(
          systemOverlayStyle: context.lgIsDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          title: const Text('选择位置'),
          actions: [
            IconButton(
                tooltip: '搜索地点',
                onPressed: _search,
                icon: const Icon(Icons.search)),
          ]),
      body: Stack(children: [
        Positioned.fill(
            child: TravelMapCanvas(
                key: _map,
                initialCamera: _camera,
                places: picked == null
                    ? const []
                    : [
                        TravelSpot(
                            id: 0,
                            name: picked.name,
                            lat: picked.lat,
                            lng: picked.lng)
                      ],
                selectedId: 0,
                onCameraSettled: (camera) => _camera = camera,
                onSelect: (_) {},
                onPick: _pick)),
        Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
                color: context.lgPaper,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          picked == null
                              ? '长按地图或点击地图上的地点'
                              : picked.address.isNotEmpty
                                  ? picked.address
                                  : picked.name.isNotEmpty
                                      ? picked.name
                                      : '已选中位置，可在保存时补充名称',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: context.lgInk,
                                  foregroundColor: context.lgPaper),
                              onPressed: picked == null
                                  ? null
                                  : () => Navigator.pop(context, picked),
                              child: const Text('确认这个位置'))),
                    ])))),
      ]),
    );
  }
}
