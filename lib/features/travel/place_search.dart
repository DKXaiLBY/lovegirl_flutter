import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import 'travel_workspace.dart';

class PlaceSearchController extends ChangeNotifier {
  final ApiService api;
  PlaceSearchController({ApiService? api}) : api = api ?? ApiService();
  List<PlaceChoice> results = const [];
  bool loading = false;
  String? error;
  Timer? _debounce;
  int _generation = 0;
  bool _disposed = false;

  void search(String value) {
    _debounce?.cancel();
    final query = value.trim();
    final generation = ++_generation;
    results = const [];
    error = null;
    loading = query.isNotEmpty;
    notifyListeners();
    if (query.isEmpty) return;
    _debounce = Timer(
        const Duration(milliseconds: 350), () => _fetch(query, generation));
  }

  Future<void> _fetch(String query, int generation) async {
    try {
      final response = await api.searchAmapPoi(query);
      final data = response.data?['data'];
      final rows = data is Map ? data['list'] : null;
      if (rows is! List) throw const FormatException('Invalid search response');
      final next = <PlaceChoice>[];
      for (final row in rows.whereType<Map>()) {
        final lat = double.tryParse(row['lat'].toString());
        final lng = double.tryParse(row['lng'].toString());
        if (lat == null ||
            lng == null ||
            !lat.isFinite ||
            !lng.isFinite ||
            lat.abs() > 90 ||
            lng.abs() > 180 ||
            (lat == 0 && lng == 0)) {
          continue;
        }
        next.add(PlaceChoice(
            name: row['name']?.toString() ?? '',
            city: row['city'] is String ? row['city'] as String : '',
            address: row['address'] is String ? row['address'] as String : '',
            lat: lat,
            lng: lng));
      }
      if (_disposed || generation != _generation) return;
      results = next;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = extractServerMessage(failure, fallback: '搜索失败，请重新搜索');
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    super.dispose();
  }
}

class TravelPlaceSearch extends StatefulWidget {
  final TravelWorkspace workspace;
  const TravelPlaceSearch({super.key, required this.workspace});
  @override
  State<TravelPlaceSearch> createState() => _TravelPlaceSearchState();
}

class _TravelPlaceSearchState extends State<TravelPlaceSearch> {
  late final PlaceSearchController _search =
      PlaceSearchController(api: widget.workspace.api);
  final _text = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
          systemOverlayStyle: context.lgIsDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          title: const Text('搜索地点')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _search.search,
                decoration: const InputDecoration(
                    hintText: '搜索名称、城市或地址', prefixIcon: Icon(Icons.search)))),
        Expanded(
            child: AnimatedBuilder(
                animation: _search,
                builder: (context, _) {
                  final query = _text.text.trim().toLowerCase();
                  final saved = query.isEmpty
                      ? widget.workspace.places.take(8).toList()
                      : widget.workspace.places
                          .where((place) =>
                              (place.name + place.city + place.address)
                                  .toLowerCase()
                                  .contains(query))
                          .toList();
                  return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        if (saved.isNotEmpty) ...[
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('已记录的地点')),
                          for (final place in saved)
                            ListTile(
                                leading: const Icon(Icons.bookmark_outline),
                                title: Text(place.name),
                                subtitle: Text(place.city),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(
                                    context, PlaceChoice.fromSpot(place))),
                        ],
                        if (query.isEmpty && saved.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('输入想找的地方，找到后可以记下来')),
                        if (_search.loading)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child:
                                  Center(child: CircularProgressIndicator())),
                        if (_search.error != null)
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: [
                                Text(_search.error!),
                                TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: context.lgInk),
                                    onPressed: () => _search.search(_text.text),
                                    child: const Text('重试'))
                              ])),
                        if (_search.results.isNotEmpty)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('搜索结果')),
                        for (final place in _search.results)
                          ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(place.name),
                              subtitle: Text([place.city, place.address]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · ')),
                              onTap: () => Navigator.pop(context, place)),
                        if (query.isNotEmpty &&
                            !_search.loading &&
                            _search.error == null &&
                            _search.results.isEmpty &&
                            saved.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('没有找到，试试城市名加地点名')),
                      ]);
                })),
      ]),
    );
  }
}
