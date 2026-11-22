import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/creations/creation_document.dart';
import '../../features/creations/creation_files.dart';
import '../../features/creations/creation_preview.dart';
import '../../features/travel/journey.dart';
import '../../models/travel.dart';
import '../../services/api_service.dart';
import '../../services/app_storage.dart';
import '../../widgets/rebuild_controls.dart';
import 'travel_memory_screen.dart';

class JourneyRecapScreen extends StatefulWidget {
  final Journey journey;
  final ApiService api;
  final int account;

  const JourneyRecapScreen(
      {super.key,
      required this.journey,
      required this.api,
      required this.account});

  @override
  State<JourneyRecapScreen> createState() => _JourneyRecapScreenState();
}

class _RecapEntry {
  final String key;
  final String title;
  final String description;
  final String? image;
  final Widget Function() open;

  const _RecapEntry(
      this.key, this.title, this.description, this.image, this.open);
}

class _JourneyRecapScreenState extends State<JourneyRecapScreen> {
  late final _title = TextEditingController(text: widget.journey.title);
  late final _note = TextEditingController(text: widget.journey.description);
  final _removed = <String>{};
  final _order = <String>[];
  var _entries = <_RecapEntry>[];
  bool _loading = true;
  bool _saving = false;
  bool _incomplete = false;
  bool _dirty = false;
  bool _draftUnreadable = false;

  String get _cacheKey =>
      'journey_recap_${widget.account}_${widget.journey.id}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var malformed = false;
    if (_entries.isEmpty && !_dirty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_cacheKey);
        if (!mounted) return;
        if (raw != null) {
          final saved = Map<String, dynamic>.from(jsonDecode(raw));
          final removed = (saved['removed'] as List).whereType<String>();
          final order = (saved['order'] as List).whereType<String>();
          _title.text = saved['title'] as String;
          _note.text = saved['note'] as String;
          _removed
            ..clear()
            ..addAll(removed);
          _order
            ..clear()
            ..addAll(order);
        }
      } catch (_) {
        malformed = true;
      }
    }
    final j = widget.journey;
    final entries = <_RecapEntry>[];
    final places = <int, TravelSpot>{};
    for (final stop in j.stops) {
      final spot = stop.place;
      if (spot == null) continue;
      places.putIfAbsent(spot.id, () => spot);
      final day = stop.day;
      entries.add(_RecapEntry(
          'stop_${stop.key}',
          spot.name,
          [
            if (day != null) '第 ${day + 1} 天',
            if (spot.status == 'visited') '已去',
            if (stop.note.isNotEmpty) stop.note
          ].join(' · '),
          spot.coverImage ?? spot.photos.firstOrNull,
          () => TravelMemoryScreen(spot: spot)));
    }
    var incomplete = false;
    Future<List> read(Future<dynamic> Function() request) async {
      try {
        final response = await request();
        final data = response.data['data'];
        if (data is List) return data;
        throw const FormatException('Missing source data');
      } catch (_) {
        incomplete = true;
        return [];
      }
    }

    final works = read(widget.api.getCreations);
    final visited =
        places.values.where((spot) => spot.status == 'visited').toList();
    for (var offset = 0; offset < visited.length; offset += 6) {
      final group = visited.skip(offset).take(6).toList();
      final photos = await Future.wait(
          group.map((spot) => read(() => widget.api.getTravelPhotos(spot.id))));
      if (!mounted) return;
      for (var i = 0; i < group.length; i++) {
        final spot = group[i];
        final urls = <String>{
          ...spot.photos,
          for (final row in photos[i].whereType<Map>())
            (row['url'] ?? row['image'] ?? '').toString(),
        }..remove('');
        for (final url in urls) {
          entries.add(_RecapEntry(
              'photo_${spot.id}_$url',
              spot.name,
              '旅行照片',
              url,
              () => Scaffold(
                    appBar: AppBar(
                        title: Text(spot.name),
                        flexibleSpace: const RebuildGlassHeader()),
                    body: RebuildPageBackground(
                        child: Center(
                            child: InteractiveViewer(
                      child: CachedNetworkImage(
                          cacheManager: MediaCache.instance,
                          imageUrl: creationUrl(url),
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Text('照片暂未读取')),
                    ))),
                  )));
        }
      }
    }
    for (final row in (await works).whereType<Map>()) {
      try {
        final work = CreationWork.fromJson(Map<String, dynamic>.from(row));
        if (work.tripId != j.id) continue;
        final doc = work.document;
        final label = doc.kind == 'ticket' ? '票根' : '拍立得';
        entries.add(_RecapEntry(
            'work_${work.id}',
            doc.title.isEmpty ? label : doc.title,
            label,
            work.previewUrl,
            () => CreationPreview(
                document: doc,
                front: CachedNetworkImage(
                    cacheManager: MediaCache.instance,
                    imageUrl: creationUrl(work.previewUrl),
                    fit: BoxFit.contain))));
      } catch (_) {
        incomplete = true;
      }
    }
    if (!mounted) return;
    setState(() {
      final keyed = {for (final entry in entries) entry.key: entry};
      for (final key in _order) {
        if (keyed.containsKey(key)) continue;
        final existing =
            _entries.where((entry) => entry.key == key).firstOrNull;
        if (incomplete && existing != null) keyed[key] = existing;
      }
      _entries = [
        for (final key in _order)
          if (keyed.containsKey(key)) keyed.remove(key)!,
        ...keyed.values
      ];
      if (!incomplete) {
        _order
          ..clear()
          ..addAll(_entries.map((entry) => entry.key));
      }
      _loading = false;
      _incomplete = incomplete;
      _draftUnreadable = malformed;
    });
  }

  Future<bool> _save() async {
    if (_saving || _draftUnreadable) return false;
    setState(() => _saving = true);
    final entryKeys = _entries.map((entry) => entry.key).toSet();
    final order = [
      ...entryKeys,
      if (_incomplete) ..._order.where((key) => !entryKeys.contains(key)),
    ];
    final state = jsonEncode({
      'title': _title.text,
      'note': _note.text,
      'removed': _removed.toList(),
      'order': order,
    });
    var ok = false;
    try {
      ok = await (await SharedPreferences.getInstance())
          .setString(_cacheKey, state);
    } catch (_) {
      ok = false;
    }
    if (mounted) {
      setState(() {
        _saving = false;
        if (ok) {
          _order
            ..clear()
            ..addAll(order);
          _dirty = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '旅行回顾已存为本机草稿' : '暂未保存，请重试')));
    }
    return ok;
  }

  Future<void> _back() async {
    if (_saving) return;
    if (!_dirty || await _save()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _entries.where((entry) => !_removed.contains(entry.key)).toList();
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _back();
      },
      child: Scaffold(
        appBar: AppBar(
            title: const Text('旅行回顾'),
            flexibleSpace: const RebuildGlassHeader(),
            actions: [
              TextButton(
                  onPressed:
                      _saving || _loading || _draftUnreadable ? null : _save,
                  child: Text(_saving ? '保存中…' : '保存'))
            ]),
        body: RebuildPageBackground(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    buildDefaultDragHandles: false,
                    header: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('本机草稿'),
                          if (_draftUnreadable)
                            const Text('已有草稿暂时无法读取，原草稿已保留。'),
                          if (_incomplete)
                            TextButton(
                                onPressed: () {
                                  setState(() => _loading = true);
                                  _load();
                                },
                                child: const Text('部分来源暂未读取，重试')),
                          const SizedBox(height: 8),
                          TextField(
                              controller: _title,
                              enabled: !_saving && !_draftUnreadable,
                              maxLength: 100,
                              onChanged: (_) => setState(() => _dirty = true),
                              decoration:
                                  const InputDecoration(labelText: '回顾名称')),
                          TextField(
                              controller: _note,
                              enabled: !_saving && !_draftUnreadable,
                              maxLength: 3000,
                              minLines: 2,
                              maxLines: 6,
                              onChanged: (_) => setState(() => _dirty = true),
                              decoration:
                                  const InputDecoration(labelText: '旅行记下的话')),
                          if (visible.isEmpty)
                            const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text('这份行程暂时没有可加入的记录')),
                        ]),
                    itemCount: visible.length,
                    onReorder: (from, to) {
                      if (_saving || _draftUnreadable) return;
                      final item = visible.removeAt(from);
                      visible.insert(to > from ? to - 1 : to, item);
                      setState(() {
                        _entries = [
                          ...visible,
                          ..._entries
                              .where((entry) => _removed.contains(entry.key))
                        ];
                        _dirty = true;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return ListTile(
                        key: ValueKey(item.key),
                        title: Text(item.title),
                        subtitle: item.description.isEmpty
                            ? null
                            : Text(item.description),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => item.open())),
                        leading: item.image == null || item.image!.isEmpty
                            ? const Icon(Icons.place_outlined)
                            : SizedBox.square(
                                dimension: 44,
                                child: CachedNetworkImage(
                                    cacheManager: MediaCache.instance,
                                    imageUrl: creationUrl(item.image!),
                                    memCacheWidth: 132,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.photo_outlined))),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              tooltip: '从回顾中移除',
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _saving || _draftUnreadable
                                  ? null
                                  : () {
                                      setState(() {
                                        _removed.add(item.key);
                                        _dirty = true;
                                      });
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: const Text('已从回顾中移除'),
                                              action: SnackBarAction(
                                                  label: '撤销',
                                                  onPressed: () {
                                                    if (mounted && !_saving) {
                                                      setState(() {
                                                        _removed
                                                            .remove(item.key);
                                                        _dirty = true;
                                                      });
                                                    }
                                                  })));
                                    }),
                          if (!_saving && !_draftUnreadable)
                            ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.drag_handle))),
                        ]),
                      );
                    },
                  )),
      ),
    );
  }
}
