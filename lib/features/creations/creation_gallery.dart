import '../../widgets/rebuild_controls.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/photo/legacy_photo_screen.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import 'creation_camera.dart';
import 'creation_canvas.dart';
import 'creation_catalog.dart';
import 'creation_document.dart';
import 'creation_drafts.dart';
import 'creation_editor.dart';
import 'creation_files.dart';
import 'creation_material.dart';
import 'creation_preview.dart';

class CreationGallery extends StatefulWidget {
  final String kind;
  final int? tripId;
  final String? tripTitle;
  final String? tripDate;
  final ApiService? api;
  final CreationDrafts? drafts;
  const CreationGallery(
      {super.key,
      this.kind = 'polaroid',
      this.tripId,
      this.tripTitle,
      this.tripDate,
      this.api,
      this.drafts});
  @override
  State<CreationGallery> createState() => _CreationGalleryState();
}

class _CreationGalleryState extends State<CreationGallery> {
  late final _api = widget.api ?? ApiService();
  final _pager = PageController(viewportFraction: .94, keepPage: false);
  late final CreationDrafts _store;
  List<CreationWork> _works = [];
  List<CreationDraft> _drafts = [];
  List<Map<String, dynamic>> _old = [];
  int _section = 0;
  bool _loading = true;
  bool _busy = false;
  int _page = 0;
  int? _exportingId;
  final _backWorks = <int>{};
  String? _error;
  String? _month;
  int get _owner => context.read<AuthProvider>().userId ?? 0;
  bool get _ticket => widget.kind == 'ticket';

  @override
  void initState() {
    super.initState();
    _store = widget.drafts ?? CreationDrafts(_owner);
    unawaited(_load());
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _load() async {
    final previousWorks = _works.map((w) => '${w.id}_${w.revision}').join(',');
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final results = await Future.wait([
      _api
          .getCreations()
          .then<dynamic>((r) => r.data['data'])
          .catchError((Object e) => e),
      _store
          .list(kind: widget.kind)
          .then<dynamic>((v) => v)
          .catchError((Object e) => e),
      if (!_ticket)
        _api
            .getPhotos()
            .then<dynamic>((r) => r.data['data'])
            .catchError((Object e) => e),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0] is List) {
        _works = (results[0] as List)
            .map((e) => CreationWork.fromJson(Map<String, dynamic>.from(e)))
            .where((e) =>
                e.document.kind == widget.kind &&
                (widget.tripId == null || e.tripId == widget.tripId))
            .toList();
        if (_works.map((w) => '${w.id}_${w.revision}').join(',') !=
            previousWorks) {
          _page = 0;
        }
      } else {
        _error = '作品加载失败，已有内容和私密草稿仍可查看';
      }
      if (results[1] is List<CreationDraft>) {
        _drafts = results[1] as List<CreationDraft>;
      } else {
        _error = '本机草稿读取失败，请重试';
      }
      if (!_ticket && results[2] is List) {
        _old = (results[2] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (_store.unreadable.isNotEmpty) {
        _error = '有 ${_store.unreadable.length} 份草稿损坏，其他草稿可继续编辑';
      }
      _loading = false;
    });
  }

  Future<void> _edit(CreationDraft draft) async {
    if (!mounted) return;
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreationEditor(draft: draft, store: _store)));
    if (result is CreationDraft && mounted) {
      await _edit(result);
      return;
    }
    if (result == true && mounted) {
      setState(() {
        _section = 0;
        _month = null;
        _page = 0;
      });
    }
    if (mounted) await _load();
  }

  Future<void> _new() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      String template = _ticket ? 'landscape' : 'classic';
      if (_ticket) {
        final choice = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => SafeArea(
                minimum: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: Column(children: [
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('选择票根版式',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700))),
                      Expanded(
                          child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: ticketTemplates.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1.2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12),
                              itemBuilder: (_, i) {
                                final t = ticketTemplates[i];
                                return InkWell(
                                    onTap: () => Navigator.pop(context, t.id),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                        decoration: BoxDecoration(
                                            color: context.lgCard,
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        padding: const EdgeInsets.all(10),
                                        child: Column(children: [
                                          Expanded(
                                              child: FittedBox(
                                                  child: SizedBox(
                                                      width: 150,
                                                      height:
                                                          150 / t.aspectRatio,
                                                      child: CustomPaint(
                                                          painter: CreationPainter(
                                                              CreationDocument(
                                                                  kind:
                                                                      'ticket',
                                                                  templateId:
                                                                      t.id,
                                                                  title:
                                                                      '我们的旅行',
                                                                  date:
                                                                      '2026.10'),
                                                              const []))))),
                                          const SizedBox(height: 8),
                                          Text(
                                              '${t.label}${t.minimumPhotos > 1 ? ' · 双图' : ''}',
                                              style:
                                                  const TextStyle(fontSize: 12))
                                        ])));
                              })),
                    ]))));
        if (choice == null || !mounted) return;
        template = choice;
      }
      if (!mounted) return;
      final minPhotos = _ticket
          ? ticketTemplates.firstWhere((t) => t.id == template).minimumPhotos
          : 1;
      final source = minPhotos > 1
          ? 'import'
          : await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (context) => SafeArea(
                  minimum: const EdgeInsets.only(bottom: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (minPhotos == 1)
                      ListTile(
                          leading: const Icon(Icons.camera_alt_outlined),
                          title: const Text('拍下这一刻'),
                          onTap: () => Navigator.pop(context, 'camera')),
                    ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: Text(minPhotos == 1 ? '从相册选择照片' : '选择两张照片'),
                        onTap: () => Navigator.pop(context, 'import')),
                  ])));
      if (source == null || !mounted) return;
      List<String> paths;
      String look = 'instant_clear';
      if (source == 'camera') {
        final result = await Navigator.push<CreationCapture>(
            context, MaterialPageRoute(builder: (_) => const CreationCamera()));
        if (result == null) return;
        paths = [result.path];
        look = result.lookId;
      } else if (minPhotos > 1) {
        final picks = await ImagePicker().pickMultiImage(
            maxWidth: 2400, maxHeight: 2400, imageQuality: 95, limit: 2);
        if (picks.isEmpty) return;
        if (picks.length != 2) {
          _message('这个版式需要恰好两张照片，请重新选择');
          return;
        }
        paths = picks.map((e) => e.path).toList();
      } else {
        final pick = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 2400,
            maxHeight: 2400,
            imageQuality: 95);
        if (pick == null) return;
        paths = [pick.path];
      }
      final draft = await _store.create(
          CreationDocument(
              kind: widget.kind,
              templateId: template,
              lookId: look,
              title: widget.tripTitle ?? '',
              date: (_ticket ? widget.tripDate : null) ??
                  DateTime.now().toIso8601String().substring(0, 10),
              transforms: paths.map((_) => const CreationCrop()).toList()),
          paths,
          tripId: widget.tripId,
          tripTitle: widget.tripTitle);
      await _edit(draft);
    } catch (_) {
      _message('照片未能打开，请重试；已有草稿仍然保留');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editWork(CreationWork work) async {
    if (_busy || work.ownerId != _owner) return;
    setState(() => _busy = true);
    try {
      final existing = _drafts.where((d) => d.workId == work.id);
      final draft = existing.isNotEmpty
          ? existing.first
          : await draftFromRemote(_store, work.document, work.sourceUrls,
              workId: work.id,
              revision: work.revision,
              tripId: work.tripId,
              tripTitle: work.tripTitle);
      await _edit(draft);
    } catch (_) {
      _message('原图读取失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _oldPhoto(Map<String, dynamic> photo) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = (photo['url'] ?? photo['image'] ?? '').toString();
      final draft = await draftFromRemote(
          _store,
          CreationDocument(
            title: photo['frame_note']?.toString() ?? '',
            note: photo['back_message']?.toString() ??
                photo['description']?.toString() ??
                '',
            date: (photo['photo_date'] ?? photo['created_at'])
                ?.toString()
                .split('T')
                .first
                .split(' ')
                .first,
          ),
          [url]);
      await _edit(draft);
    } catch (_) {
      _message('原照片未能读取，请重试；旧相册没有变化');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteWork(CreationWork work) async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('删除这份作品？'),
                content: const Text('两个人的收藏中都会移除，原相册照片不会删除。'),
                actions: [
                  TextButton(
                      style: rebuildTextStyle(context),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('保留')),
                  TextButton(
                      style: rebuildTextStyle(context),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('删除'))
                ]));
    if (accepted != true || !mounted) return;
    try {
      await _api.deleteCreation(work.id, work.revision);
      await _load();
    } catch (_) {
      _message('删除失败，作品仍然保留；请刷新后重试');
    }
  }

  Future<void> _export(CreationWork work) async {
    if (_exportingId != null) return;
    setState(() => _exportingId = work.id);
    try {
      final back = _backWorks.contains(work.id);
      final bytes = back
          ? await renderCreation(work.document, const [], back: true)
          : Uint8List.fromList((await Dio().get<List<int>>(
                  creationUrl(work.previewUrl),
                  options: Options(responseType: ResponseType.bytes)))
              .data!);
      await Gal.putImageBytes(bytes,
          name: 'LoveGirl_${work.id}_${back ? 'back' : 'front'}');
      _message('已保存到相册');
    } catch (_) {
      _message('未能写入系统相册，请检查相册权限后重试');
    } finally {
      if (mounted) setState(() => _exportingId = null);
    }
  }

  void _flip(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_backWorks.add(id)) _backWorks.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final months = _works
        .map((w) => (w.document.date?.isNotEmpty == true
                ? w.document.date!
                : w.updatedAt.toIso8601String())
            .substring(0, 7))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final works = _works
        .where((w) =>
            _month == null ||
            (w.document.date?.isNotEmpty == true
                    ? w.document.date!
                    : w.updatedAt.toIso8601String())
                .startsWith(_month!))
        .toList();
    final selectedWork =
        works.isEmpty ? null : works[_page.clamp(0, works.length - 1)];
    return Scaffold(
      backgroundColor: context.lgBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: context.lgIsDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          title: Text(_ticket ? '旅行票根' : '我们的相片',
              style:
                  const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          actions: [
            if (_ticket && _section == 0 && works.isNotEmpty)
              IconButton(
                  tooltip: '制作票根',
                  onPressed: _busy ? null : _new,
                  icon: const Icon(Icons.add)),
            IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh)),
            if (!_ticket)
              IconButton(
                  tooltip: '原相册与翻页书',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LegacyPhotoScreen())),
                  icon: const Icon(Icons.photo_album_outlined))
          ]),
      body: Stack(children: [
        Positioned.fill(
            child: CreationBackdrop(
                imageUrl: _section == 0 && selectedWork != null
                    ? creationUrl(selectedWork.sourceUrls.isEmpty
                        ? selectedWork.previewUrl
                        : selectedWork.sourceUrls.first)
                    : null)),
        SafeArea(
            minimum: const EdgeInsets.only(bottom: 24),
            child: Column(children: [
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final s in [
                          (0, _loading ? '收藏' : '收藏 ${_works.length}'),
                          (1, _loading ? '草稿' : '草稿 ${_drafts.length}'),
                          if (!_ticket)
                            (2, _loading ? '原照片' : '原照片 ${_old.length}')
                        ])
                          Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: RebuildChoiceChip(
                                  label: Text(s.$2),
                                  selected: _section == s.$1,
                                  onSelected: (_) => _showSection(s.$1))),
                        const SizedBox(width: 2),
                        if (_section == 0 && months.isNotEmpty)
                          PopupMenuButton<String>(
                              tooltip: '按月浏览',
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  child: RebuildGlass(
                                      radius: 24,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                _month == null
                                                    ? '月份'
                                                    : '${_month!.substring(5)}月',
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.expand_more,
                                                size: 16)
                                          ]))),
                              onSelected: (v) => setState(() {
                                    final month = v.isEmpty ? null : v;
                                    if (month != _month) _page = 0;
                                    _month = month;
                                  }),
                              itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: '', child: Text('全部月份')),
                                    ...months.map((m) =>
                                        PopupMenuItem(value: m, child: Text(m)))
                                  ]),
                      ]))),
              if (_loading || _busy)
                LinearProgressIndicator(
                    minHeight: 2,
                    color: context.lgInk,
                    backgroundColor: context.lgSeparator),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(fontSize: 12))),
                      TextButton(
                          style: rebuildTextStyle(context),
                          onPressed: _load,
                          child: const Text('重试'))
                    ])),
              Expanded(
                child: _loading &&
                        _works.isEmpty &&
                        _drafts.isEmpty &&
                        _old.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: context.lgInk, strokeWidth: 2)),
                        const SizedBox(height: 14),
                        Text('正在取回你的回忆',
                            style: TextStyle(
                                fontSize: 13, color: context.lgTextSecondary))
                      ]))
                    : _section == 0
                        ? works.isEmpty
                            ? _empty('还没有收藏的${_ticket ? '票根' : '拍立得'}',
                                '拍摄或导入一张照片，制作第一份回忆')
                            : PageView.builder(
                                key: ValueKey(
                                    '$_month:${works.map((w) => '${w.id}_${w.revision}').join(',')}'),
                                controller: _pager,
                                onPageChanged: (value) =>
                                    setState(() => _page = value),
                                itemCount: works.length,
                                itemBuilder: (_, index) =>
                                    _workPage(works, index))
                        : _section == 1
                            ? _drafts.isEmpty
                                ? _empty('还没有草稿', '编辑过程中会自动保存在这台设备')
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _drafts.length,
                                    itemBuilder: (_, i) {
                                      final d = _drafts[i];
                                      return Card(
                                          child: ListTile(
                                              leading: const Icon(
                                                  Icons.drafts_outlined),
                                              title: Text(
                                                  d.document.title.isEmpty
                                                      ? '未完成的回忆'
                                                      : d.document.title),
                                              subtitle: Text(
                                                  '${d.document.kind == 'ticket' ? d.document.ticket.label : d.document.paper.label} · ${d.updatedAt.toLocal().toString().substring(0, 16)}'),
                                              onTap: () => _edit(d),
                                              trailing: IconButton(
                                                  tooltip: '删除私密草稿',
                                                  icon: const Icon(
                                                      Icons.delete_outline),
                                                  onPressed: () async {
                                                    final yes = await showDialog<
                                                            bool>(
                                                        context: context,
                                                        builder: (context) =>
                                                            AlertDialog(
                                                                title: const Text(
                                                                    '删除这份草稿？'),
                                                                content: const Text(
                                                                    '已收藏的作品和原相册不会受影响。'),
                                                                actions: [
                                                                  TextButton(
                                                                      style: rebuildTextStyle(
                                                                          context),
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          false),
                                                                      child: const Text(
                                                                          '保留')),
                                                                  TextButton(
                                                                      style: rebuildTextStyle(
                                                                          context),
                                                                      onPressed: () => Navigator.pop(
                                                                          context,
                                                                          true),
                                                                      child: const Text(
                                                                          '删除'))
                                                                ]));
                                                    if (yes == true) {
                                                      await _store.delete(d.id);
                                                      await _load();
                                                    }
                                                  })));
                                    })
                            : _old.isEmpty
                                ? _empty('原相册还没有照片', '可以拍摄或导入照片，直接制作拍立得')
                                : GridView.builder(
                                    padding: const EdgeInsets.all(20),
                                    itemCount: _old.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            childAspectRatio: .65,
                                            mainAxisSpacing: 18,
                                            crossAxisSpacing: 20),
                                    itemBuilder: (_, i) =>
                                        _sourcePhotoTile(_old[i])),
              ),
              if (!_ticket || _section != 0 || works.isEmpty)
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: RebuildGlass(
                        padding: const EdgeInsets.all(8),
                        child: Row(children: [
                          RebuildGlassButton(
                              label: _section == 1 ? '查看收藏' : '私密草稿',
                              icon: _section == 1
                                  ? Icons.collections_outlined
                                  : Icons.drafts_outlined,
                              onPressed: () =>
                                  _showSection(_section == 1 ? 0 : 1)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: FilledButton.icon(
                                  style: rebuildFilledStyle(context),
                                  onPressed: _busy ? null : _new,
                                  icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 20),
                                  label: Text(_ticket ? '制作票根' : '制作拍立得'))),
                        ]))),
            ])),
      ]),
    );
  }

  void _showSection(int section) => setState(() {
        if (section != _section) _page = 0;
        _section = section;
      });

  Widget _sourcePhotoTile(Map<String, dynamic> photo) {
    final document = CreationDocument(
        title: photo['frame_note']?.toString() ?? '',
        date: (photo['photo_date'] ?? photo['created_at'])
            ?.toString()
            .split('T')
            .first
            .split(' ')
            .first);
    final window = CreationPainter.photoWindows(document).first;
    return InkWell(
        onTap: _busy ? null : () => _oldPhoto(photo),
        borderRadius: BorderRadius.circular(6),
        child: Column(children: [
          Expanded(
              child: Center(
                  child: AspectRatio(
                      aspectRatio: document.aspectRatio,
                      child: CreationMaterial(
                          document: document,
                          lift: .55,
                          child: LayoutBuilder(
                              builder: (context, box) =>
                                  Stack(fit: StackFit.expand, children: [
                                    CustomPaint(
                                        painter: CreationPainter(
                                            document, const [])),
                                    Positioned(
                                        left: window.left / 880 * box.maxWidth,
                                        top: window.top /
                                            (880 / document.aspectRatio) *
                                            box.maxHeight,
                                        width:
                                            window.width / 880 * box.maxWidth,
                                        height: window.height /
                                            (880 / document.aspectRatio) *
                                            box.maxHeight,
                                        child: CachedNetworkImage(
                                            imageUrl: creationUrl(
                                                (photo['url'] ??
                                                        photo['image'] ??
                                                        '')
                                                    .toString()),
                                            fit: BoxFit.cover,
                                            memCacheWidth: 500,
                                            placeholder: (_, __) => ColoredBox(
                                                color: context.lgPrimarySoft,
                                                child: Center(
                                                    child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                            strokeWidth: 1.5,
                                                            color: context
                                                                .lgInk)))),
                                            errorWidget: (_, __, ___) =>
                                                const Icon(Icons.broken_image_outlined))),
                                  ])))))),
          const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 4),
              child: Text('用这张制作拍立得', style: TextStyle(fontSize: 11))),
        ]));
  }

  Widget _workPage(List<CreationWork> works, int index) {
    final work = works[index];
    final behind = works[(index + 1) % works.length];
    final back = _backWorks.contains(work.id);
    void inspect() => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreationPreview(
                document: work.document,
                initialBack: back,
                front: CachedNetworkImage(
                    imageUrl: creationUrl(work.previewUrl),
                    fit: BoxFit.contain))));
    return Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
              fit: _ticket ? FlexFit.loose : FlexFit.tight,
              child: Center(
                  heightFactor: _ticket ? 1 : null,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final width = math.max(
                        1.0,
                        math.min(
                            constraints.maxWidth - 12,
                            (constraints.maxHeight - 32) *
                                work.document.aspectRatio));
                    return SizedBox(
                        width: width,
                        height: width / work.document.aspectRatio,
                        child: AnimatedBuilder(
                            animation: _pager,
                            builder: (context, _) {
                              final delta = _pager.positions.length == 1 &&
                                      _pager.position.haveDimensions
                                  ? ((_pager.page ?? 0) - index)
                                      .clamp(-1.0, 1.0)
                                  : 0.0;
                              final angle =
                                  MediaQuery.disableAnimationsOf(context)
                                      ? 0.0
                                      : (_ticket ? .045 : -.025) + delta * .035;
                              return Stack(
                                  clipBehavior: Clip.none,
                                  fit: StackFit.expand,
                                  children: [
                                    if (!_ticket && works.length > 1)
                                      IgnorePointer(
                                          child: Transform.translate(
                                              offset: const Offset(-10, 5),
                                              child: Transform.rotate(
                                                  angle: -.075,
                                                  child: CreationMaterial(
                                                      document: behind.document,
                                                      child: CachedNetworkImage(
                                                          imageUrl: creationUrl(
                                                              behind
                                                                  .previewUrl),
                                                          memCacheWidth: 650,
                                                          fit: BoxFit.contain,
                                                          errorWidget: (_, __,
                                                                  ___) =>
                                                              const SizedBox()))))),
                                    Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..setEntry(3, 2, .0008)
                                          ..rotateY(
                                              MediaQuery.disableAnimationsOf(
                                                      context)
                                                  ? 0
                                                  : delta * .1)
                                          ..rotateZ(angle),
                                        child: Padding(
                                            padding: EdgeInsets.only(
                                                right: _ticket ? 0 : 14,
                                                bottom: _ticket
                                                    ? 0
                                                    : 14 /
                                                        work.document
                                                            .aspectRatio),
                                            child: CreationFlip(
                                                work: work,
                                                lightShift: MediaQuery
                                                        .disableAnimationsOf(
                                                            context)
                                                    ? 0
                                                    : delta,
                                                back: back,
                                                onInspect: inspect,
                                                onFlip: () => _flip(work.id)))),
                                    if (!_ticket)
                                      Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: RebuildGlassButton(
                                              label: back ? '翻到正面' : '翻到背面',
                                              icon: Icons.flip,
                                              onPressed: () => _flip(work.id))),
                                  ]);
                            }));
                  }))),
          if (_ticket)
            Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 14),
                child: _ticketInfo(work)),
          if (!_ticket && work.tripTitle != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: context.lgTextSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                      child: Text(work.tripTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: context.lgInk))),
                ])),
          if (_ticket)
            _ticketActions(work)
          else
            RebuildGlass(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (work.ownerId == _owner)
                    Expanded(
                        child: TextButton.icon(
                            style: rebuildTextStyle(context),
                            onPressed: _busy ? null : () => _editWork(work),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('继续制作'))),
                  if (work.document.note.isNotEmpty)
                    IconButton(
                        tooltip: '故事',
                        onPressed: () => _showStory(work),
                        icon: const Icon(Icons.notes_outlined, size: 21)),
                  IconButton(
                      tooltip: '保存图片',
                      onPressed:
                          _exportingId != null ? null : () => _export(work),
                      icon: _exportingId == work.id
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.file_download_outlined, size: 22)),
                  if (work.ownerId == _owner)
                    IconButton(
                        tooltip: '删除作品',
                        onPressed: () => _deleteWork(work),
                        icon: const Icon(Icons.delete_outline, size: 21)),
                ])),
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('${index + 1} / ${works.length}  ·  左右滑动  ·  长按放大',
                  style: TextStyle(fontSize: 11, color: context.lgInk))),
        ]));
  }

  Widget _ticketInfo(CreationWork work) {
    final date = work.document.date ?? '';
    final back = _backWorks.contains(work.id);
    return RebuildGlass(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(
                    work.document.title.isEmpty ? '我们的纪念' : work.document.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.lgInk))),
            const SizedBox(width: 4),
            RebuildGlassButton(
                label: back ? '翻到正面' : '翻到背面',
                icon: Icons.flip,
                onPressed: () => _flip(work.id)),
            PopupMenuButton<String>(
                tooltip: '作品更多',
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  if (value == 'story') _showStory(work);
                  if (value == 'delete') unawaited(_deleteWork(work));
                },
                itemBuilder: (_) => [
                      const PopupMenuItem(value: 'story', child: Text('查看记录')),
                      if (work.ownerId == _owner)
                        const PopupMenuItem(
                            value: 'delete', child: Text('删除作品')),
                    ]),
          ]),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: context.lgInk),
              const SizedBox(width: 9),
              Text(date.replaceAll('-', '.'),
                  style: TextStyle(fontSize: 13, color: context.lgInk))
            ]),
          ],
          if (work.tripTitle?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.link, size: 16, color: context.lgInk),
              const SizedBox(width: 9),
              Expanded(
                  child: Text(work.tripTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: context.lgInk)))
            ]),
          ],
          if (work.document.note.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(work.document.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, height: 1.5, color: context.lgInk))),
        ]));
  }

  Widget _ticketActions(CreationWork work) => Row(children: [
        if (work.ownerId == _owner) ...[
          Expanded(
              child: RebuildGlassButton(
                  label: '继续编辑',
                  icon: Icons.edit_outlined,
                  showLabel: true,
                  onPressed: _busy ? null : () => _editWork(work))),
          const SizedBox(width: 10),
        ],
        Expanded(
            child: FilledButton.icon(
                style: rebuildFilledStyle(context),
                onPressed: _exportingId != null ? null : () => _export(work),
                icon: _exportingId == work.id
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_download_outlined, size: 18),
                label: Text(_exportingId == work.id ? '正在导出' : '导出图片'))),
      ]);

  void _showStory(CreationWork work) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
          minimum: const EdgeInsets.only(bottom: 24),
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                            work.document.title.isEmpty
                                ? '这一份回忆'
                                : work.document.title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        if (work.document.date?.isNotEmpty == true)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  work.document.date!.replaceAll('-', '.'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: context.lgTextSecondary))),
                        if (work.tripTitle?.isNotEmpty == true)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(work.tripTitle!)),
                        const SizedBox(height: 20),
                        SelectableText(
                            work.document.note.isEmpty
                                ? '还没有写下记录'
                                : work.document.note,
                            style: const TextStyle(fontSize: 16, height: 1.7)),
                      ])))));

  Widget _empty(String title, String hint) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 136,
                height: _ticket ? 70 : 165,
                child: Transform.rotate(
                    angle: -.06,
                    child: CreationMaterial(
                        document: CreationDocument(kind: widget.kind),
                        child: CustomPaint(
                            painter: CreationPainter(
                                CreationDocument(kind: widget.kind),
                                const []))))),
            const SizedBox(height: 30),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.lgTextSecondary)),
            if (!_ticket && _old.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                  style: rebuildTextStyle(context),
                  onPressed: () => _showSection(2),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('从原照片开始')),
            ],
          ])));
}

class CreationFlip extends StatelessWidget {
  final CreationWork work;
  final bool back;
  final VoidCallback onFlip;
  final VoidCallback? onInspect;
  final double lightShift;
  const CreationFlip(
      {super.key,
      required this.work,
      required this.back,
      required this.onFlip,
      this.onInspect,
      this.lightShift = 0});
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label:
          '${work.document.title}，${work.document.kind == 'ticket' ? '票根' : '照片'}${back ? '背面，轻触查看正面' : '正面，轻触查看背面'}',
      child: GestureDetector(
        onTap: onFlip,
        onLongPress: onInspect,
        child: TweenAnimationBuilder<double>(
            tween: Tween(end: back ? math.pi : 0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            builder: (_, angle, __) {
              final back = angle > math.pi / 2;
              return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0015)
                    ..rotateY(back ? angle - math.pi : angle),
                  child: CreationMaterial(
                      document: work.document,
                      glossy: !back,
                      lightShift: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : lightShift + math.sin(angle) * .7,
                      lift: 1 + math.sin(angle).abs() * .2,
                      child: back
                          ? CustomPaint(
                              painter: CreationPainter(work.document, const [],
                                  back: true))
                          : CachedNetworkImage(
                              imageUrl: creationUrl(work.previewUrl),
                              fit: BoxFit.contain,
                              memCacheWidth: 1200,
                              placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined)))));
            }),
      ));
}
