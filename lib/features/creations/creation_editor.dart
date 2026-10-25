import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../travel/journey.dart';
import 'creation_canvas.dart';
import 'creation_catalog.dart';
import 'creation_document.dart';
import 'creation_drafts.dart';
import 'creation_files.dart';

class CreationEditor extends StatefulWidget {
  final CreationDraft draft;
  final CreationDrafts store;
  const CreationEditor({super.key, required this.draft, required this.store});
  @override
  State<CreationEditor> createState() => _CreationEditorState();
}

class _CreationEditorState extends State<CreationEditor> {
  late CreationDraft _draft = widget.draft;
  List<ui.Image> _images = [];
  final _api = ApiService();
  final _undo = <CreationDocument>[];
  final _redo = <CreationDocument>[];
  int _tab = 0;
  int _cropIndex = 0;
  bool _back = false;
  bool _eraser = false;
  bool _busy = false;
  bool _loading = true;
  bool _saved = true;
  bool _saveFailed = false;
  double _penWidth = .006;
  Color _penColor = const Color(0xff22252b);
  CreationInk? _active;
  CreationCrop _cropStart = const CreationCrop();
  Offset _cropFocal = Offset.zero;
  String? _loadError;
  int _saveGeneration = 0;
  CreationDocument get _d => _draft.document;
  bool get _drawing => _tab == 2;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final images = await decodeCreationImages(_draft.sourcePaths);
      if (!mounted) {
        for (final i in images) {
          i.dispose();
        }
        return;
      }
      setState(() {
        _images = images;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = '原图读取失败，草稿仍然保留';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final image in _images) {
      image.dispose();
    }
    super.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _change(CreationDocument document, {bool history = true}) {
    if (_busy) return;
    if (history) {
      _undo.add(_d);
      if (_undo.length > 60) _undo.removeAt(0);
      _redo.clear();
    }
    setState(() {
      _draft = _draft.copyWith(document: document);
      _saved = false;
    });
    unawaited(_save());
  }

  Future<void> _save() async {
    final generation = ++_saveGeneration;
    try {
      await widget.store.save(_draft);
      if (mounted && generation == _saveGeneration) {
        setState(() {
          _saved = true;
          _saveFailed = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _saveGeneration) {
        setState(() {
          _saved = false;
          _saveFailed = true;
        });
      }
    }
  }

  void _history(bool redo) {
    final from = redo ? _redo : _undo;
    if (from.isEmpty) return;
    (redo ? _undo : _redo).add(_d);
    _change(from.removeLast(), history: false);
  }

  Future<void> _text() async {
    final title = TextEditingController(text: _d.title);
    final note = TextEditingController(text: _d.note);
    String? date = _d.date;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: const Text('记录这一刻'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: title,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: '正面标题')),
                    TextField(
                        controller: note,
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 7,
                        decoration: InputDecoration(
                            labelText:
                                _d.kind == 'ticket' ? '票根文字／背面故事' : '背面故事')),
                    TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.tryParse(date ?? '') ??
                                  DateTime.now(),
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100));
                          if (picked != null) {
                            setDialog(() => date =
                                picked.toIso8601String().substring(0, 10));
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(date?.isNotEmpty == true ? date! : '选择日期')),
                    TextButton(
                        onPressed: () => setDialog(() => date = ''),
                        child: const Text('不显示日期')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('完成'))
                  ],
                )));
    if (accepted == true && mounted) {
      _change(_d.copyWith(
          title: title.text.trim(), note: note.text.trim(), date: date));
    }
    title.dispose();
    note.dispose();
  }

  Future<void> _link() async {
    try {
      final response = await _api.getJourneys();
      final journeys = (response.data['data'] as List)
          .map((e) => Journey.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      final result = await showModalBottomSheet<int>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
                  child: ListView(shrinkWrap: true, children: [
                const ListTile(
                    title: Text('关联旅行'), subtitle: Text('作品也可以独立收藏')),
                ListTile(
                    leading: const Icon(Icons.link_off),
                    title: const Text('独立作品'),
                    onTap: () => Navigator.pop(context, -1)),
                ...journeys.map((j) => ListTile(
                    title: Text(j.title),
                    trailing:
                        _draft.tripId == j.id ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, j.id))),
              ])));
      if (result == null || !mounted) return;
      setState(() => _draft = _draft.copyWith(
          clearTrip: result == -1,
          tripId: result == -1 ? null : result,
          tripTitle: result == -1
              ? null
              : journeys.firstWhere((j) => j.id == result).title));
      await _save();
    } catch (_) {
      _message('行程读取失败，当前作品已保留');
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await renderCreation(_d, _images, back: _back);
      final file = File(
          '${(await getApplicationDocumentsDirectory()).path}/lovegirl_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      try {
        await Gal.putImage(file.path);
        _message('已保存到系统相册');
      } catch (_) {
        if (!mounted) return;
        final open = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('图片已生成'),
                    content: const Text('系统相册未能写入，文件已保存在 App 内，可以打开图片后另存。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('稍后')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('打开图片'))
                    ]));
        if (open == true) await OpenFilex.open(file.path);
      }
    } catch (_) {
      _message('导出失败，作品和草稿没有丢失');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    if (_busy || _loading || _loadError != null) return;
    if (_draft.sourcePaths.length < _d.minimumPhotos) {
      _message('这个版式需要至少 ${_d.minimumPhotos} 张照片，请返回选择照片后制作');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.save(_draft);
      final bytes = await renderCreation(_d, _images, width: 1320);
      final response = await _api.saveCreation(
          clientId: _draft.id,
          document: _d.toJson(),
          preview: bytes,
          sourcePaths: _draft.sourcePaths,
          id: _draft.workId,
          revision: _draft.revision,
          tripId: _draft.tripId);
      final work = CreationWork.fromJson(
          Map<String, dynamic>.from(response.data['data']));
      // Persist the acknowledgement before removing the draft; retry cannot duplicate it.
      _draft = _draft.copyWith(workId: work.id, revision: work.revision);
      await widget.store.save(_draft);
      await widget.store.delete(_draft.id);
      if (mounted) {
        _message('已收藏，两个人都可以看到');
        Navigator.pop(context, true);
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 409 && _draft.workId == null) {
        // A previous request may have succeeded before its response was lost.
        try {
          final response = await _api.getCreations();
          final matches = (response.data['data'] as List)
              .where((e) => e['clientId'] == _draft.id)
              .toList();
          if (matches.isNotEmpty) {
            final work =
                CreationWork.fromJson(Map<String, dynamic>.from(matches.first));
            _draft = _draft.copyWith(workId: work.id, revision: work.revision);
            await widget.store.save(_draft);
            _message('上次收藏已完成，当前修改仍在草稿中；再次收藏即可更新');
            return;
          }
        } catch (_) {/* The original draft remains recoverable. */}
      }
      _message(error.response?.statusCode == 409
          ? '作品或关联行程已变化。当前输入已保留为草稿，请刷新作品后再编辑；也可以取消旅行关联后另存。'
          : '收藏失败，草稿已保留，请检查网络后重试');
    } catch (_) {
      _message('收藏未完成，草稿仍然保留');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _leave() async {
    if (_busy) return false;
    try {
      await widget.store.save(_draft);
      return true;
    } catch (_) {
      if (!mounted) return false;
      return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                      title: const Text('草稿未能写入'),
                      content: const Text('存储空间可能不足，离开会失去本次未保存修改。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('继续编辑')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('仍然离开'))
                      ])) ??
          false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop && await _leave() && mounted && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          backgroundColor: context.lgBg,
          appBar: AppBar(
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_d.kind == 'ticket' ? '制作票根' : '制作拍立得',
                        style: const TextStyle(fontSize: 18)),
                    Text(
                        _saveFailed
                            ? '草稿未保存，点击重试'
                            : _saved
                                ? '私密草稿已保存'
                                : '正在保存草稿…',
                        style: TextStyle(
                            fontSize: 10,
                            color: _saveFailed
                                ? Colors.red
                                : context.lgTextSecondary))
                  ]),
              actions: [
                if (_saveFailed)
                  IconButton(
                      onPressed: _save,
                      tooltip: '重试保存草稿',
                      icon: const Icon(Icons.save_outlined)),
                IconButton(
                    tooltip: '导出当前面',
                    onPressed: _busy || _loading || _loadError != null
                        ? null
                        : _export,
                    icon: const Icon(Icons.file_download_outlined)),
                Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: FilledButton(
                        onPressed: _busy || _loading || _loadError != null
                            ? null
                            : _publish,
                        child: Text(_busy ? '处理中' : '收藏')))
              ]),
          body: SafeArea(
              child: Column(children: [
            Expanded(
                child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    decoration: BoxDecoration(
                        color: _d.background,
                        borderRadius: BorderRadius.circular(24),
                        gradient: _d.gradient
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                    _d.background,
                                    Color.lerp(_d.background, _d.accent, .30)!
                                  ])
                            : null),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _loadError != null
                            ? Center(child: Text(_loadError!))
                            : LayoutBuilder(builder: (context, constraints) {
                                final width = math.min(
                                    constraints.maxWidth - 36,
                                    (constraints.maxHeight - 32) *
                                        _d.aspectRatio);
                                final size =
                                    Size(width, width / _d.aspectRatio);
                                Offset normalized(Offset point) => Offset(
                                    (point.dx / size.width).clamp(0, 1),
                                    (point.dy / size.height).clamp(0, 1));
                                return Center(
                                    child: SizedBox.fromSize(
                                        size: size,
                                        child: GestureDetector(
                                          onTap: _busy
                                              ? null
                                              : () {
                                                  if (!_drawing) _text();
                                                },
                                          onScaleStart: _busy
                                              ? null
                                              : (details) {
                                                  if (_drawing) {
                                                    final point = normalized(
                                                        details
                                                            .localFocalPoint);
                                                    if (_eraser) {
                                                      final strokes = (_back
                                                              ? _d.backInk
                                                              : _d.frontInk)
                                                          .where((s) => !s
                                                              .points
                                                              .any((p) =>
                                                                  (p - point)
                                                                      .distance <
                                                                  .04))
                                                          .toList();
                                                      _change(_back
                                                          ? _d.copyWith(
                                                              backInk: strokes)
                                                          : _d.copyWith(
                                                              frontInk:
                                                                  strokes));
                                                    } else {
                                                      setState(() => _active =
                                                          CreationInk(
                                                              points: [point],
                                                              width: _penWidth,
                                                              color:
                                                                  _penColor));
                                                    }
                                                  } else if (!_back) {
                                                    _undo.add(_d);
                                                    _redo.clear();
                                                    _cropStart = _d
                                                        .transforms[_cropIndex];
                                                    _cropFocal =
                                                        details.localFocalPoint;
                                                  }
                                                },
                                          onScaleUpdate: _busy
                                              ? null
                                              : (details) {
                                                  if (_drawing &&
                                                      !_eraser &&
                                                      _active != null) {
                                                    if (_active!
                                                            .points.length >=
                                                        math.min(
                                                            2000,
                                                            20000 -
                                                                (_back
                                                                        ? _d
                                                                            .backInk
                                                                        : _d
                                                                            .frontInk)
                                                                    .fold<int>(
                                                                        0,
                                                                        (sum, s) =>
                                                                            sum +
                                                                            s.points.length))) {
                                                      return;
                                                    }
                                                    setState(() => _active =
                                                            CreationInk(
                                                                points: [
                                                              ..._active!
                                                                  .points,
                                                              normalized(details
                                                                  .localFocalPoint)
                                                            ],
                                                                width:
                                                                    _penWidth,
                                                                color:
                                                                    _penColor));
                                                  } else if (_drawing &&
                                                      _eraser) {
                                                    final point = normalized(
                                                        details
                                                            .localFocalPoint);
                                                    final strokes = (_back
                                                            ? _d.backInk
                                                            : _d.frontInk)
                                                        .where((stroke) => !stroke
                                                            .points
                                                            .any((p) =>
                                                                (p - point)
                                                                    .distance <
                                                                .04))
                                                        .toList();
                                                    setState(() => _draft =
                                                        _draft.copyWith(
                                                            document: _back
                                                                ? _d.copyWith(
                                                                    backInk:
                                                                        strokes)
                                                                : _d.copyWith(
                                                                    frontInk:
                                                                        strokes)));
                                                  } else if (!_drawing &&
                                                      !_back) {
                                                    final delta = details
                                                            .localFocalPoint -
                                                        _cropFocal;
                                                    final crops =
                                                        _d.transforms.toList();
                                                    crops[_cropIndex] = CreationCrop(
                                                        scale: (_cropStart
                                                                    .scale *
                                                                details.scale)
                                                            .clamp(1, 5),
                                                        x: (_cropStart.x +
                                                                delta.dx /
                                                                    size.width *
                                                                    2)
                                                            .clamp(-1, 1),
                                                        y: (_cropStart.y +
                                                                delta.dy /
                                                                    size.height *
                                                                    2)
                                                            .clamp(-1, 1));
                                                    setState(() => _draft =
                                                        _draft.copyWith(
                                                            document: _d
                                                                .copyWith(
                                                                    transforms:
                                                                        crops)));
                                                  }
                                                },
                                          onScaleEnd: _busy
                                              ? null
                                              : (_) {
                                                  if (_active != null) {
                                                    final strokes = [
                                                      ...(_back
                                                          ? _d.backInk
                                                          : _d.frontInk),
                                                      _active!
                                                    ];
                                                    if (strokes.length <= 800) {
                                                      _change(_back
                                                          ? _d.copyWith(
                                                              backInk: strokes)
                                                          : _d.copyWith(
                                                              frontInk:
                                                                  strokes));
                                                    } else {
                                                      _message(
                                                          '笔迹已达到上限，可以撤销后继续');
                                                    }
                                                    setState(
                                                        () => _active = null);
                                                  } else {
                                                    unawaited(_save());
                                                  }
                                                },
                                          child: CreationArtwork(
                                              document: _d,
                                              images: _images,
                                              back: _back,
                                              activeInk: _active),
                                        )));
                              }))),
            SizedBox(
                height: 44,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                      tooltip: '撤销',
                      onPressed:
                          _busy || _undo.isEmpty ? null : () => _history(false),
                      icon: const Icon(Icons.undo, size: 20)),
                  IconButton(
                      tooltip: '重做',
                      onPressed:
                          _busy || _redo.isEmpty ? null : () => _history(true),
                      icon: const Icon(Icons.redo, size: 20)),
                  TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _back = !_back;
                                _active = null;
                              });
                            },
                      icon: const Icon(Icons.flip, size: 18),
                      label: Text(_back ? '查看正面' : '翻到背面')),
                  TextButton(
                      onPressed: _busy ? null : _text,
                      child: const Text('文字／日期')),
                ])),
            SizedBox(
                height: 42,
                child: Row(children: [
                  for (final item in [
                    (0, _d.kind == 'ticket' ? '版式' : '相纸'),
                    (1, '成像'),
                    (2, '涂鸦'),
                    (3, '更多')
                  ])
                    Expanded(
                        child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _tab = item.$1;
                                      _active = null;
                                    }),
                            child: Text(item.$2,
                                style: TextStyle(
                                    fontWeight: _tab == item.$1
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                    color: _tab == item.$1
                                        ? context.lgInk
                                        : context.lgTextSecondary))))
                ])),
            SizedBox(
                height: math.min(180, MediaQuery.sizeOf(context).height * .24),
                child: AbsorbPointer(absorbing: _busy, child: _controls())),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
          ])),
        ),
      );

  Widget _controls() {
    if (_tab == 0) {
      final options = _d.kind == 'ticket'
          ? ticketTemplates
              .map((t) => (t.id, t.label, t.minimumPhotos))
              .toList()
          : paperTemplates.map((p) => (p.id, p.label, 1)).toList();
      return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: options
                  .map((option) => ChoiceChip(
                      label: Text(option.$2),
                      selected: _d.templateId == option.$1,
                      onSelected: (_) {
                        if (_images.length < option.$3) {
                          _message('这个版式需要 ${option.$3} 张照片，请新建时选择多张照片');
                          return;
                        }
                        _change(_d.copyWith(templateId: option.$1));
                      }))
                  .toList()));
    }
    if (_tab == 1) {
      return Column(children: [
        SizedBox(
            height: 66,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: creationLooks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                    label: Text(creationLooks[i].label),
                    selected: _d.lookId == creationLooks[i].id,
                    onSelected: (_) =>
                        _change(_d.copyWith(lookId: creationLooks[i].id))))),
        Row(children: [
          const SizedBox(width: 20),
          const Text('强度'),
          Expanded(
              child: Slider(
                  value: _d.intensity,
                  onChangeStart: (_) {
                    _undo.add(_d);
                    _redo.clear();
                  },
                  onChanged: (value) =>
                      _change(_d.copyWith(intensity: value), history: false))),
          SizedBox(width: 48, child: Text('${(_d.intensity * 100).round()}%'))
        ]),
      ]);
    }
    if (_tab == 2) {
      return SingleChildScrollView(
          child: Column(children: [
        const Text('整张相纸都能画 · 切到其他工具后可缩放／移动照片', style: TextStyle(fontSize: 11)),
        Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final color in const [
                Color(0xff22252b),
                Colors.white,
                Color(0xff5b7498),
                Color(0xffba6978),
                Color(0xff768e72),
                Color(0xffc7a45e)
              ])
                InkWell(
                    onTap: () => setState(() {
                          _penColor = color;
                          _eraser = false;
                        }),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _penColor == color && !_eraser
                                    ? context.lgInk
                                    : context.lgSeparator,
                                width: 3)))),
              IconButton(
                  tooltip: '按笔画擦除',
                  onPressed: () => setState(() => _eraser = !_eraser),
                  isSelected: _eraser,
                  icon: const Icon(Icons.auto_fix_normal)),
            ]),
        Row(children: [
          const SizedBox(width: 20),
          const Text('笔宽'),
          Expanded(
              child: Slider(
                  value: _penWidth,
                  min: .002,
                  max: .025,
                  onChanged: (v) => setState(() => _penWidth = v))),
          const SizedBox(width: 16)
        ]),
      ]));
    }
    return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: _link,
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(_draft.tripTitle ?? '关联旅行',
                        maxLines: 1, overflow: TextOverflow.ellipsis))),
            const SizedBox(width: 8),
            OutlinedButton(
                onPressed: () => _change(_d.copyWith(
                    transforms: List.generate(
                        _images.length, (_) => const CreationCrop()))),
                child: const Text('重置裁切'))
          ]),
          if (_images.length > 1)
            Wrap(spacing: 8, children: [
              for (var i = 0;
                  i <
                      math.min(_images.length,
                          CreationPainter.photoWindows(_d).length);
                  i++)
                ChoiceChip(
                    label: Text('裁切照片 ${i + 1}'),
                    selected: _cropIndex == i,
                    onSelected: (_) => setState(() => _cropIndex = i))
            ]),
          Row(children: [
            const Text('工作台'),
            const SizedBox(width: 8),
            for (final c in const [
              Color(0xffeef0f3),
              Color(0xffdce5ed),
              Color(0xffe7e2e8),
              Color(0xffdfe6df)
            ])
              IconButton(
                  tooltip: '更换工作台颜色',
                  onPressed: () => _change(_d.copyWith(
                      background: c, accent: Color.lerp(c, Colors.black, .4))),
                  icon: Icon(Icons.circle, color: c)),
          ]),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('柔和渐变背景', style: TextStyle(fontSize: 13)),
              value: _d.gradient,
              onChanged: (v) => _change(_d.copyWith(gradient: v))),
          if (_d.kind == 'ticket')
            Wrap(spacing: 4, children: [
              const Text('票根配色'),
              for (final c in const [
                Color(0xff7d899b),
                Color(0xff608397),
                Color(0xff986d7e),
                Color(0xff6a8068),
                Color(0xff282b32)
              ])
                IconButton(
                    tooltip: '更换票根配色',
                    onPressed: () => _change(_d.copyWith(accent: c)),
                    icon: Icon(Icons.circle, color: c))
            ]),
        ]));
  }
}
