import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import '../../features/creations/creation_gallery.dart';
import '../../features/creations/creation_document.dart';
import '../../features/creations/creation_files.dart';
import '../../features/creations/creation_preview.dart';
import '../photo/legacy_photo_screen.dart';
import '../cooking/cooking_log_screen.dart';
import '../mood/mood_screen.dart';
import '../report/annual_report_screen.dart';
import '../report/monthly_report_screen.dart';
import '../timeline/timeline_screen.dart';

class MemoriesScreen extends StatefulWidget {
  final ApiService? api;
  const MemoriesScreen({super.key, this.api});
  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  late final _api = widget.api ?? ApiService();
  final _pager = PageController(viewportFraction: .82);
  List<CreationWork> _works = [];
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  final _errors = <String>[];
  final _backs = <int>{};
  int? _account;
  int _request = 0;
  String? _month;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = context.watch<AuthProvider>().userId;
    if (_request == 0 || account != _account) {
      _account = account;
      _request++;
      _works = [];
      _photos = [];
      _backs.clear();
      _month = null;
      _page = 0;
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && account == _account) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    final errors = <String>[];
    Future<dynamic> read(Future<dynamic> response, String name) async {
      try {
        final data = (await response).data['data'];
        if (data is! List) throw const FormatException('Invalid collection');
        return data;
      } catch (_) {
        errors.add(name);
        return null;
      }
    }

    final values = await Future.wait(
        [read(_api.getCreations(), '作品'), read(_api.getPhotos(), '原照片')]);
    if (!mounted || request != _request) return;
    final works = <CreationWork>[];
    if (values[0] is List) {
      for (final row in values[0]) {
        try {
          works.add(CreationWork.fromJson(Map<String, dynamic>.from(row)));
        } catch (_) {
          if (!errors.contains('部分作品')) errors.add('部分作品');
        }
      }
    }
    setState(() {
      if (values[0] != null) _works = works;
      if (values[1] != null) {
        _photos = (values[1] as List)
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList();
      }
      _errors
        ..clear()
        ..addAll(errors);
      _loading = false;
      _page = 0;
    });
    if (_pager.hasClients) _pager.jumpToPage(0);
  }

  String? _key(dynamic raw) {
    final date = DateTime.tryParse('$raw'.replaceFirst(' ', 'T'));
    return date == null
        ? null
        : '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  bool _inMonth(dynamic raw) => _month == null || _key(raw) == _month;
  List<CreationWork> get _polaroids => _works
      .where((w) => w.document.kind == 'polaroid' && _inMonth(w.document.date))
      .toList();
  List<CreationWork> get _tickets => _works
      .where((w) => w.document.kind == 'ticket' && _inMonth(w.document.date))
      .toList();
  List<Map<String, dynamic>> get _originals => _photos
      .where((p) => _inMonth(p['photo_date'] ?? p['created_at']))
      .toList();
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  void _album() => _open(CreationGallery(
      initialMonth: _month,
      initialSection: _polaroids.isEmpty && _originals.isNotEmpty ? 2 : 0));
  void _new() => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
          minimum: const EdgeInsets.only(bottom: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final kind in [
              ('polaroid', '制作拍立得', Icons.photo_outlined),
              ('ticket', '制作票根', Icons.confirmation_number_outlined)
            ])
              ListTile(
                  leading: Icon(kind.$3),
                  title: Text(kind.$2),
                  onTap: () {
                    Navigator.pop(sheet);
                    _open(CreationGallery(kind: kind.$1, createOnOpen: true));
                  }),
          ])));
  Future<void> _chooseMonth() async {
    final months = <String>{
      for (final w in _works)
        if (_key(w.document.date) != null) _key(w.document.date)!,
      for (final p in _photos)
        if (_key(p['photo_date'] ?? p['created_at']) != null)
          _key(p['photo_date'] ?? p['created_at'])!,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final result = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
            minimum: const EdgeInsets.only(bottom: 24),
            child: ListView(shrinkWrap: true, children: [
              for (final value in ['', ...months])
                ListTile(
                    title: Text(value.isEmpty
                        ? '全部回忆'
                        : '${value.substring(0, 4)}年${int.parse(value.substring(5))}月'),
                    trailing: (_month ?? '') == value
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(sheet, value)),
            ])));
    if (result == null || !mounted) return;
    setState(() {
      _month = result.isEmpty ? null : result;
      _page = 0;
      _backs.clear();
    });
    if (_pager.hasClients) _pager.jumpToPage(0);
  }

  Widget _title(String name, VoidCallback onAll) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 4),
      child: Row(children: [
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700))),
        TextButton(
            style: rebuildTextStyle(context),
            onPressed: onAll,
            child: const Text('查看全部 ›'))
      ]));
  Widget _published(CreationWork work) => CreationFlip(
      work: work,
      back: _backs.contains(work.id),
      onFlip: () {
        HapticFeedback.selectionClick();
        setState(() => _backs.contains(work.id)
            ? _backs.remove(work.id)
            : _backs.add(work.id));
      },
      onInspect: () => _open(CreationPreview(
          document: work.document,
          front: CachedNetworkImage(
              imageUrl: creationUrl(work.previewUrl), fit: BoxFit.contain))));

  Widget _shelf() {
    final works = _polaroids;
    final originals = _originals;
    final count = works.length + originals.length;
    if (_loading && count == 0) {
      return const SizedBox(
          height: 320, child: Center(child: CircularProgressIndicator()));
    }
    if (count == 0) {
      return SizedBox(
          height: 300,
          child: Center(
              child: RebuildGlass(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.photo_library_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text(_errors.isEmpty ? '把一张照片，留成回忆' : '相册暂时没能读取'),
                    const SizedBox(height: 12),
                    RebuildGlassButton(
                        label: '制作拍立得',
                        icon: Icons.add,
                        showLabel: true,
                        onPressed: () =>
                            _open(const CreationGallery(createOnOpen: true))),
                  ]))));
    }
    return Column(children: [
      SizedBox(
          height: (MediaQuery.sizeOf(context).width * .82 - 16) * 107 / 88 + 16,
          child: PageView.builder(
              controller: _pager,
              itemCount: count,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  child: Transform.rotate(
                      angle: rebuildReduceMotion(context)
                          ? 0
                          : (index - _page).clamp(-1, 1) * .06,
                      child: index < works.length
                          ? _published(works[index])
                          : legacyMemoryPolaroid(
                              originals[index - works.length],
                              onEdit: () => _open(const LegacyPhotoScreen()),
                              onInspect: () =>
                                  _open(const LegacyPhotoScreen())))))),
      Text('轻触翻面 · 左右滑动查看  ${_page + 1}/$count',
          style: TextStyle(fontSize: 11, color: context.lgTextSecondary)),
    ]);
  }

  Widget _ticketShelf() {
    final tickets = _tickets;
    if (tickets.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: RebuildGlass(
              child: ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title:
                      Text(_errors.contains('作品') ? '票根暂时没能读取' : '留一张属于你们的票根'),
                  trailing: const Icon(Icons.add),
                  onTap: () => _open(const CreationGallery(
                      kind: 'ticket', createOnOpen: true)))));
    }
    return SizedBox(
        height: 140,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) => SizedBox(
                width: math.min(290, 120 * tickets[index].document.aspectRatio),
                child: _published(tickets[index]))));
  }

  Widget _fragments() {
    final images = <String>{
      for (final p in _originals)
        if ('${p['url'] ?? p['image'] ?? ''}'.isNotEmpty)
          '${p['url'] ?? p['image']}',
      for (final w in _polaroids) ...w.sourceUrls,
    }.take(12).toList();
    if (images.isEmpty) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('照片会在这里连成这个月的片段',
              style: TextStyle(color: context.lgTextSecondary, fontSize: 13)));
    }
    return SizedBox(
        height: 132,
        child: Transform.rotate(
            angle: rebuildReduceMotion(context) ? 0 : -.018,
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: ShapeDecoration(
                    color: context.lgPaper,
                    shape: const _FilmStripBorder(),
                    shadows: [
                      BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 12,
                          offset: const Offset(0, 5))
                    ]),
                child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => SizedBox(
                        width: 115,
                        child: InkWell(
                            onTap: _album,
                            child: CachedNetworkImage(
                                imageUrl: creationUrl(images[i]),
                                fit: BoxFit.cover,
                                memCacheWidth: 350,
                                errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons
                                        .image_not_supported_outlined)))))))));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context.lgBg,
      body: Stack(children: [
        Positioned.fill(
            child: Image.asset('assets/images/clear_app/memories_linen.png',
                fit: BoxFit.cover,
                cacheWidth: 720,
                excludeFromSemantics: true)),
        if (context.lgIsDark)
          Positioned.fill(child: ColoredBox(color: const Color(0xe51a222b))),
        SafeArea(
            bottom: false,
            child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 28),
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(children: [
                            const Expanded(
                                child: Text('回忆',
                                    style: TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800))),
                            RebuildGlass(
                                child: TextButton(
                                    style: rebuildTextStyle(context),
                                    onPressed: _chooseMonth,
                                    child: Text(_month == null
                                        ? '全部月份 ▾'
                                        : '${_month!.substring(0, 4)}年${int.parse(_month!.substring(5))}月 ▾'))),
                            const SizedBox(width: 8),
                            RebuildGlassButton(
                                label: '新增回忆',
                                icon: Icons.add,
                                onPressed: _new),
                          ])),
                      if (_errors.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(children: [
                              Expanded(
                                  child: Text('${_errors.join('、')}加载失败，已有内容保留',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: context.lgTextSecondary))),
                              TextButton(
                                  style: rebuildTextStyle(context),
                                  onPressed: _load,
                                  child: const Text('重试'))
                            ])),
                      _title('相册', _album),
                      _shelf(),
                      _title(
                          '票根收藏',
                          () => _open(CreationGallery(
                              kind: 'ticket', initialMonth: _month))),
                      _ticketShelf(),
                      _title(_month == null ? '照片片段' : '这个月的片段', _album),
                      _fragments(),
                      const SizedBox(height: 16),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final item in [
                              (Icons.history, '时光轴', TimelineScreen()),
                              (Icons.mood_outlined, '心情', const MoodScreen()),
                              (
                                Icons.restaurant_outlined,
                                '美食手账',
                                const CookingLogScreen()
                              )
                            ])
                              OutlinedButton.icon(
                                  style: rebuildOutlinedStyle(context),
                                  onPressed: () => _open(item.$3),
                                  icon: Icon(item.$1, size: 18),
                                  label: Text(item.$2)),
                            OutlinedButton.icon(
                                style: rebuildOutlinedStyle(context),
                                onPressed: () => _openReports(context),
                                icon: const Icon(Icons.auto_stories_outlined,
                                    size: 18),
                                label: const Text('回忆报告')),
                          ])),
                    ]))),
      ]));
  void _openReports(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in <(String, Widget)>[
              ('月度小报', const MonthlyReportScreen()),
              ('年度报告', const AnnualReportScreen()),
            ])
              ListTile(
                title: Text(entry.$1),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => entry.$2),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FilmStripBorder extends ShapeBorder {
  const _FilmStripBorder();
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  ShapeBorder scale(double t) => this;
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect);
    for (var x = rect.left + 6; x + 5 < rect.right; x += 12) {
      for (final y in [rect.top + 4, rect.bottom - 10]) {
        path.addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 5, 6), const Radius.circular(1)));
      }
    }
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    canvas.drawPath(
        getOuterPath(rect),
        Paint()
          ..color = Colors.black.withAlpha(16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .5);
  }
}
