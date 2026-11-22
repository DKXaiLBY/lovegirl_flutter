import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/creations/creation_document.dart';
import '../../features/creations/creation_files.dart';
import '../../features/creations/creation_preview.dart';
import '../../services/api_service.dart';
import '../../services/app_storage.dart';
import '../../widgets/rebuild_controls.dart';
import '../photo/legacy_photo_screen.dart';

DateTime? memoryDate(Object? value) =>
    value == null ? null : DateTime.tryParse('$value'.replaceFirst(' ', 'T'));

class MemorySearchScreen extends StatefulWidget {
  final List<CreationWork> works;
  final List<Map<String, dynamic>> photos;
  final ApiService api;

  const MemorySearchScreen(
      {super.key,
      required this.works,
      required this.photos,
      required this.api});

  @override
  State<MemorySearchScreen> createState() => _MemorySearchScreenState();
}

class _MemorySearchScreenState extends State<MemorySearchScreen> {
  final _text = TextEditingController();
  final _place = TextEditingController();
  final _trips = <int, String>{};
  final _places = <String, Set<String>>{};
  DateTimeRange? _dates;
  String? _kind;
  bool _locationError = false;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _text.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    Future<List> read(Future<dynamic> Function() request) async {
      final result = await request();
      final data = result.data['data'];
      final list = data is Map ? data['list'] : data;
      if (list is! List) throw const FormatException('Invalid location data');
      return list;
    }

    final tasks = await Future.wait([
      read(widget.api.getJourneys)
          .then<List?>((value) => value, onError: (_) => null),
      read(widget.api.getTravelSpots)
          .then<List?>((value) => value, onError: (_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _locationError = tasks.any((value) => value == null);
      for (final journey in (tasks[0] ?? []).whereType<Map>()) {
        final id = int.tryParse('${journey['id']}');
        if (id != null) {
          _trips[id] = _words([journey['city'], journey['title']]);
        }
      }
      for (final spot in (tasks[1] ?? []).whereType<Map>()) {
        final name = _words([spot['city'], spot['name'], spot['address']]);
        final photos = spot['photos'];
        for (final path in [
          spot['cover_image'] ?? spot['coverImage'],
          if (photos is List) ...photos,
        ].whereType<String>().where((path) => path.isNotEmpty)) {
          (_places[creationUrl(path)] ??= {}).add(name);
        }
      }
    });
  }

  String _words(Iterable<Object?> values) => values
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' · ');

  String _locationForPath(String path) =>
      _places[creationUrl(path)]?.join(' · ') ?? '';

  Iterable<
      ({
        String kind,
        String title,
        String note,
        String location,
        String image,
        DateTime? date,
        Widget Function() open
      })> get _results sync* {
    for (final work in widget.works) {
      final document = work.document;
      yield (
        kind: document.kind,
        title: document.title.trim().isNotEmpty
            ? document.title
            : document.kind == 'ticket'
                ? '票根'
                : '拍立得',
        note: document.note,
        location: _words([
          _trips[work.tripId] ?? work.tripTitle,
          for (final path in work.sourceUrls) _locationForPath(path)
        ]),
        image: work.previewUrl,
        date: memoryDate(document.date) ?? work.updatedAt,
        open: () => CreationPreview(
            document: document,
            front: CachedNetworkImage(
                cacheManager: MediaCache.instance,
                imageUrl: creationUrl(work.previewUrl),
                fit: BoxFit.contain)),
      );
    }
    for (final photo in widget.photos) {
      final path = (photo['url'] ?? photo['image'] ?? '').toString();
      if (path.isEmpty) continue;
      final description = photo['description']?.toString().trim() ?? '';
      yield (
        kind: 'original',
        title: description.isEmpty ? '原照片' : description,
        note: (photo['back_message'] ?? photo['frame_note'] ?? '').toString(),
        location:
            _words([photo['city'], photo['location'], _locationForPath(path)]),
        image: (photo['thumbnail_url'] ?? path).toString(),
        date: memoryDate(photo['photo_date'] ?? photo['created_at']),
        open: () => Scaffold(
              appBar: AppBar(
                  title: const Text('原照片'),
                  flexibleSpace: const RebuildGlassHeader()),
              body: RebuildPageBackground(
                  child: LayoutBuilder(
                      builder: (context, box) => Center(
                            child: SizedBox(
                                width: (box.maxWidth - 40)
                                    .clamp(0, 400)
                                    .toDouble(),
                                height: (box.maxHeight - 32)
                                    .clamp(0, 560)
                                    .toDouble(),
                                child: legacyMemoryPolaroid(photo,
                                    onEdit: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LegacyPhotoScreen())),
                                    onInspect: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LegacyPhotoScreen())))),
                          ))),
            ),
      );
    }
  }

  bool _matchesDate(DateTime? date) {
    final range = _dates;
    if (range == null) return true;
    if (date == null) return false;
    final day = DateUtils.dateOnly(date.toLocal());
    return !day.isBefore(range.start) && !day.isAfter(range.end);
  }

  Future<void> _pickDates() async {
    final dates = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
        initialDateRange: _dates);
    if (mounted && dates != null) setState(() => _dates = dates);
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _text.text.trim().toLowerCase();
    final location = _place.text.trim().toLowerCase();
    final visible = _results
        .where(
          (entry) =>
              (_kind == null || entry.kind == _kind) &&
              _matchesDate(entry.date) &&
              entry.location.toLowerCase().contains(location) &&
              '${entry.title} ${entry.note} ${entry.location}'
                  .toLowerCase()
                  .contains(keyword),
        )
        .toList()
      ..sort((a, b) => (b.date?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.date?.millisecondsSinceEpoch ?? 0));
    String dateLabel(DateTime date) => date.toIso8601String().split('T').first;
    return Scaffold(
      appBar: AppBar(
          title: const Text('查找回忆'),
          flexibleSpace: const RebuildGlassHeader(),
          actions: [
            TextButton(
                onPressed: () => setState(() {
                      _text.clear();
                      _place.clear();
                      _dates = null;
                      _kind = null;
                    }),
                child: const Text('清除条件'))
          ]),
      body: RebuildPageBackground(
          child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: visible.isEmpty ? 2 : visible.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                      controller: _text,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: '搜索标题或留言',
                          prefixIcon: Icon(Icons.search))),
                  const SizedBox(height: 8),
                  TextField(
                      controller: _place,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: '地点或旅行',
                          prefixIcon: Icon(Icons.place_outlined))),
                  if (_locationError)
                    TextButton(
                        onPressed: _loadPlaces,
                        child: const Text('部分关联地点暂未读取，重试')),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final option in [
                      (null, '全部'),
                      ('polaroid', '拍立得'),
                      ('ticket', '票根'),
                      ('original', '原照片')
                    ])
                      RebuildChoiceChip(
                          label: Text(option.$2),
                          selected: option.$1 == _kind,
                          onSelected: (_) => setState(() => _kind = option.$1)),
                  ]),
                  TextButton.icon(
                      onPressed: _pickDates,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_dates == null
                          ? '选择日期范围'
                          : '${dateLabel(_dates!.start)} 至 ${dateLabel(_dates!.end)}')),
                ]);
          }
          if (visible.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(24), child: Text('没有符合条件的回忆'));
          }
          final entry = visible[index - 1];
          final meta = _words([
            entry.date == null ? null : dateLabel(entry.date!),
            entry.location
          ]);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 48,
                  child: CachedNetworkImage(
                      cacheManager: MediaCache.instance,
                      imageUrl: creationUrl(entry.image),
                      memCacheWidth: 144,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.photo_outlined)),
                )),
            title:
                Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: meta.isEmpty
                ? null
                : Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => entry.open())),
          );
        },
      )),
    );
  }
}
