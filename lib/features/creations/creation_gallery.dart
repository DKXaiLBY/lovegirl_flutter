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

class CreationGallery extends StatefulWidget {
  final String kind;
  final int? tripId;
  const CreationGallery({super.key, this.kind = 'polaroid', this.tripId});
  @override
  State<CreationGallery> createState() => _CreationGalleryState();
}

class _CreationGalleryState extends State<CreationGallery> {
  final _api = ApiService();
  final _pager = PageController(viewportFraction: .87, keepPage: false);
  late final CreationDrafts _store;
  List<CreationWork> _works = [];
  List<CreationDraft> _drafts = [];
  List<Map<String, dynamic>> _old = [];
  int _section = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _month;
  int get _owner => context.read<AuthProvider>().userId ?? 0;
  bool get _ticket => widget.kind == 'ticket';

  @override
  void initState() {
    super.initState();
    _store = CreationDrafts(_owner);
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
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreationEditor(draft: draft, store: _store)));
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
      final source = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
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
        final picks = await ImagePicker()
            .pickMultiImage(maxWidth: 2400, maxHeight: 2400, imageQuality: 95);
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
              date: DateTime.now().toIso8601String().substring(0, 10),
              transforms: paths.map((_) => const CreationCrop()).toList()),
          paths,
          tripId: widget.tripId);
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
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('保留')),
                  TextButton(
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
    try {
      final r = await Dio().get<List<int>>(creationUrl(work.previewUrl),
          options: Options(responseType: ResponseType.bytes));
      await Gal.putImageBytes(Uint8List.fromList(r.data!),
          name: 'LoveGirl_${work.id}');
      _message('已保存到相册');
    } catch (_) {
      _message('未能写入系统相册，请检查相册权限后重试');
    }
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
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(title: Text(_ticket ? '旅行票根' : '两个人的影像'), actions: [
        IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh)),
        if (!_ticket)
          IconButton(
              tooltip: '原相册与翻页书',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LegacyPhotoScreen())),
              icon: const Icon(Icons.photo_album_outlined))
      ]),
      body: SafeArea(
          child: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_ticket ? '把旅途，留下来。' : '让回忆，握在手里。',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('成品双人可见 · 草稿只属于你',
                        style: TextStyle(
                            fontSize: 12, color: context.lgTextSecondary))
                  ])),
              FilledButton.icon(
                  onPressed: _busy ? null : _new,
                  icon: const Icon(Icons.add),
                  label: const Text('制作'))
            ])),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              for (final s in [
                (0, '收藏 ${_works.length}'),
                (1, '草稿 ${_drafts.length}'),
                if (!_ticket) (2, '原照片 ${_old.length}')
              ])
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(s.$2),
                        selected: _section == s.$1,
                        onSelected: (_) => setState(() => _section = s.$1))),
              const Spacer(),
              if (_section == 0 && months.isNotEmpty)
                PopupMenuButton<String>(
                    tooltip: '按月浏览',
                    icon: const Icon(Icons.filter_list, size: 20),
                    onSelected: (v) =>
                        setState(() => _month = v.isEmpty ? null : v),
                    itemBuilder: (_) => [
                          const PopupMenuItem(value: '', child: Text('全部月份')),
                          ...months.map(
                              (m) => PopupMenuItem(value: m, child: Text(m)))
                        ]),
            ])),
        if (_loading || _busy) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: Text(_error!, style: const TextStyle(fontSize: 12))),
                TextButton(onPressed: _load, child: const Text('重试'))
              ])),
        Expanded(
          child: _section == 0
              ? works.isEmpty
                  ? _empty(
                      '还没有收藏的${_ticket ? '票根' : '拍立得'}', '拍摄或导入一张照片，制作第一份回忆')
                  : PageView.builder(
                      key: ValueKey(
                          '$_month:${works.map((w) => '${w.id}_${w.revision}').join(',')}'),
                      controller: _pager,
                      itemCount: works.length,
                      itemBuilder: (_, i) {
                        final work = works[i];
                        return Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                            child: Column(children: [
                              Expanded(
                                  child: Center(
                                      child: AspectRatio(
                                          aspectRatio:
                                              work.document.aspectRatio,
                                          child: CreationFlip(work: work)))),
                              const SizedBox(height: 16),
                              Text(
                                  work.document.title.isEmpty
                                      ? '未命名的回忆'
                                      : work.document.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700)),
                              if (work.tripTitle != null)
                                Text(work.tripTitle!,
                                    style: TextStyle(
                                        color: context.lgTextSecondary,
                                        fontSize: 12)),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (work.ownerId == _owner)
                                      TextButton.icon(
                                          onPressed: _busy
                                              ? null
                                              : () => _editWork(work),
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18),
                                          label: const Text('继续制作')),
                                    IconButton(
                                        tooltip: '保存图片',
                                        onPressed: () => _export(work),
                                        icon: const Icon(
                                            Icons.file_download_outlined)),
                                    if (work.ownerId == _owner)
                                      IconButton(
                                          tooltip: '删除作品',
                                          onPressed: () => _deleteWork(work),
                                          icon: const Icon(Icons.more_horiz)),
                                  ]),
                              Text('${i + 1} / ${works.length}  ·  左右翻页，轻触翻面',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: context.lgTextSecondary)),
                            ]));
                      })
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
                                    leading: const Icon(Icons.drafts_outlined),
                                    title: Text(d.document.title.isEmpty
                                        ? '未完成的回忆'
                                        : d.document.title),
                                    subtitle: Text(
                                        '${d.document.kind == 'ticket' ? d.document.ticket.label : d.document.paper.label} · ${d.updatedAt.toLocal().toString().substring(0, 16)}'),
                                    onTap: () => _edit(d),
                                    trailing: IconButton(
                                        tooltip: '删除私密草稿',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final yes = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                      title:
                                                          const Text('删除这份草稿？'),
                                                      content: const Text(
                                                          '已收藏的作品和原相册不会受影响。'),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context,
                                                                    false),
                                                            child: const Text(
                                                                '保留')),
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
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
                          padding: const EdgeInsets.all(16),
                          itemCount: _old.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: .85,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12),
                          itemBuilder: (_, i) {
                            final p = _old[i];
                            return InkWell(
                                onTap: _busy ? null : () => _oldPhoto(p),
                                borderRadius: BorderRadius.circular(12),
                                child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(children: [
                                      Expanded(
                                          child: CachedNetworkImage(
                                              imageUrl: creationUrl(
                                                  (p['url'] ?? p['image'] ?? '')
                                                      .toString()),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              memCacheWidth: 500,
                                              errorWidget: (_, __, ___) =>
                                                  const Icon(Icons
                                                      .broken_image_outlined))),
                                      const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Text('用这张制作拍立得',
                                              style: TextStyle(fontSize: 12)))
                                    ])));
                          }),
        ),
      ])),
    );
  }

  Widget _empty(String title, String hint) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                _ticket
                    ? Icons.confirmation_number_outlined
                    : Icons.photo_camera_back_outlined,
                size: 54,
                color: context.lgTextMuted),
            const SizedBox(height: 18),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(hint,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.lgTextSecondary)),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _busy ? null : _new, child: const Text('开始制作'))
          ])));
}

class CreationFlip extends StatefulWidget {
  final CreationWork work;
  const CreationFlip({super.key, required this.work});
  @override
  State<CreationFlip> createState() => _CreationFlipState();
}

class _CreationFlipState extends State<CreationFlip> {
  bool _back = false;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: _back ? '照片背面，轻触查看正面' : '照片正面，轻触查看背面',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _back = !_back);
        },
        child: TweenAnimationBuilder<double>(
            tween: Tween(end: _back ? math.pi : 0),
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
                  child: back
                      ? CustomPaint(
                          painter: CreationPainter(
                              widget.work.document, const [], back: true))
                      : DecoratedBox(
                          decoration: const BoxDecoration(boxShadow: [
                            BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 24,
                                offset: Offset(0, 10))
                          ]),
                          child: CachedNetworkImage(
                              imageUrl: creationUrl(widget.work.previewUrl),
                              fit: BoxFit.contain,
                              memCacheWidth: 1200,
                              placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined)))));
            }),
      ));
}
