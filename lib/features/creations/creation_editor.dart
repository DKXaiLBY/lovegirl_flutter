import '../../widgets/rebuild_controls.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
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
import 'creation_material.dart';
import 'creation_preview.dart';

class CreationEditor extends StatefulWidget {
  final CreationDraft draft;
  final CreationDrafts store;
  const CreationEditor({super.key, required this.draft, required this.store});
  @override
  State<CreationEditor> createState() => _CreationEditorState();
}

class _LookThumbnail extends CustomPainter {
  final ui.Image? image;
  final List<double> matrix;
  const _LookThumbnail(this.image, this.matrix);
  @override
  void paint(Canvas canvas, Size size) {
    final target = Offset.zero & size;
    if (image == null) {
      canvas.drawRect(target, Paint()..color = const Color(0xffcbdde6));
      return;
    }
    final fitted = applyBoxFit(BoxFit.cover,
        Size(image!.width.toDouble(), image!.height.toDouble()), size);
    final source = Alignment.center.inscribe(fitted.source,
        Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()));
    canvas.drawImageRect(
        image!,
        source,
        target,
        Paint()
          ..filterQuality = FilterQuality.low
          ..colorFilter = ColorFilter.matrix(matrix));
  }

  @override
  bool shouldRepaint(_LookThumbnail oldDelegate) =>
      oldDelegate.image != image || oldDelegate.matrix != matrix;
}

class _CreationEditorState extends State<CreationEditor> {
  late CreationDraft _draft = widget.draft;
  List<ui.Image> _images = [];
  final _api = ApiService();
  late final ScrollController _templateScroll;
  late final ScrollController _lookScroll;
  final _undo = <CreationDocument>[];
  final _redo = <CreationDocument>[];
  late int _tab = widget.draft.document.kind == 'ticket' ? 4 : 0;
  int _cropIndex = 0;
  bool _back = false;
  bool _eraser = false;
  bool _busy = false;
  bool _loading = true;
  bool _saved = true;
  bool _saveFailed = false;
  bool _conflicted = false;
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
    final templates = (_d.kind == 'ticket'
            ? ticketTemplates.map((v) => v.id)
            : paperTemplates.map((v) => v.id))
        .toList();
    _templateScroll = ScrollController(
        initialScrollOffset:
            math.max(0, templates.indexOf(_d.templateId)) * 102.0);
    _lookScroll = ScrollController(
        initialScrollOffset:
            math.max(0, creationLooks.indexWhere((v) => v.id == _d.lookId)) *
                96.0);
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
    _templateScroll.dispose();
    _lookScroll.dispose();
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

  int get _inkPoints => (_back ? _d.backInk : _d.frontInk)
      .fold(0, (sum, s) => sum + s.points.length);

  void _startInk(Offset point) {
    if (_eraser) {
      _undo.add(_d);
      _redo.clear();
      _eraseAt(point);
      return;
    }
    if (_inkPoints >= 20000 ||
        (_back ? _d.backInk : _d.frontInk).length >= 800) {
      _message('笔迹已达到上限，可以撤销或擦除后继续');
      return;
    }
    setState(() => _active =
        CreationInk(points: [point], width: _penWidth, color: _penColor));
  }

  void _eraseAt(Offset point) {
    final strokes = (_back ? _d.backInk : _d.frontInk)
        .where((s) => !s.points.any((p) => (p - point).distance < .035))
        .toList();
    setState(() => _draft = _draft.copyWith(
        document: _back
            ? _d.copyWith(backInk: strokes)
            : _d.copyWith(frontInk: strokes)));
  }

  void _moveInk(Offset point) {
    if (_eraser) {
      _eraseAt(point);
      return;
    }
    final active = _active;
    if (active == null ||
        active.points.length >= math.min(2000, 20000 - _inkPoints)) {
      return;
    }
    if ((active.points.last - point).distance < .001) return;
    setState(() => _active = CreationInk(
        points: [...active.points, point],
        width: active.width,
        color: active.color));
  }

  void _finishInk() {
    if (_active != null) {
      final strokes = [...(_back ? _d.backInk : _d.frontInk), _active!];
      _change(_back
          ? _d.copyWith(backInk: strokes)
          : _d.copyWith(frontInk: strokes));
      setState(() => _active = null);
    } else {
      unawaited(_save());
    }
  }

  Future<void> _text() async {
    var title = _d.title;
    var note = _d.note;
    String? date = _d.date;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: const Text('记录这一刻'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                        initialValue: title,
                        onChanged: (v) => title = v,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: '正面标题')),
                    TextFormField(
                        initialValue: note,
                        onChanged: (v) => note = v,
                        maxLength: 2000,
                        minLines: 3,
                        maxLines: 7,
                        decoration: InputDecoration(
                            labelText:
                                _d.kind == 'ticket' ? '票根文字／背面故事' : '背面故事')),
                    TextButton.icon(
                        style: rebuildTextStyle(context),
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
                        style: rebuildTextStyle(context),
                        onPressed: () => setDialog(() => date = ''),
                        child: const Text('不显示日期')),
                  ])),
                  actions: [
                    TextButton(
                        style: rebuildTextStyle(context),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消')),
                    FilledButton(
                        style: rebuildFilledStyle(context),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('完成'))
                  ],
                )));
    if (accepted == true && mounted) {
      _change(_d.copyWith(title: title.trim(), note: note.trim(), date: date));
    }
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

  Future<void> _openLatest() async {
    if (_draft.workId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.save(_draft);
      final r = await _api.getCreation(_draft.workId!);
      final work =
          CreationWork.fromJson(Map<String, dynamic>.from(r.data['data']));
      final next = await draftFromRemote(
          widget.store, work.document, work.sourceUrls,
          workId: work.id,
          revision: work.revision,
          tripId: work.tripId,
          tripTitle: work.tripTitle);
      if (mounted) Navigator.pop(context, next);
    } catch (_) {
      _message('新版作品读取失败，当前输入仍在草稿中');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAsNew() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.save(_draft);
      final next = await widget.store.create(_d, _draft.sourcePaths,
          tripId: _draft.tripId, tripTitle: _draft.tripTitle);
      if (mounted) Navigator.pop(context, next);
    } catch (_) {
      _message('草稿未能另存，原草稿仍然保留');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_active != null) _finishInk();
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
                          style: rebuildTextStyle(context),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('稍后')),
                      FilledButton(
                          style: rebuildFilledStyle(context),
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

  Future<void> _replacePhoto() async {
    if (_busy || _loading || _loadError != null) return;
    if (_active != null) _finishInk();
    setState(() => _busy = true);
    ui.Image? replacement;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      replacement = (await decodeCreationImages([picked.path])).single;
      final index = _cropIndex.clamp(0, _images.length - 1);
      final next = await widget.store.replaceSource(_draft, index, picked.path);
      if (!mounted) return;
      final previous = _images[index];
      setState(() {
        _draft = next;
        _images = [..._images]..[index] = replacement!;
        _undo.clear();
        _redo.clear();
        _saved = true;
        _saveFailed = false;
        _saveGeneration++;
      });
      replacement = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      _message('照片已更换，文字和笔迹已保留');
    } catch (_) {
      _message('更换失败，原照片和草稿仍然保留');
    } finally {
      replacement?.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    if (_busy || _loading || _loadError != null) return;
    if (_active != null) _finishInk();
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
          sourcePaths: _draft.workId == null || _draft.sourcesChanged
              ? _draft.sourcePaths
              : const [],
          id: _draft.workId,
          revision: _draft.revision,
          tripId: _draft.tripId);
      final work = CreationWork.fromJson(
          Map<String, dynamic>.from(response.data['data']));
      // Persist the acknowledgement before removing the draft; retry cannot duplicate it.
      _draft = _draft.copyWith(
          workId: work.id, revision: work.revision, sourcesChanged: false);
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
            _draft = _draft.copyWith(
                workId: work.id, revision: 1, sourcesChanged: true);
            await widget.store.save(_draft);
            _message('上次收藏已完成，当前修改仍在草稿中；再次收藏即可更新');
            return;
          }
        } catch (_) {/* The original draft remains recoverable. */}
      }
      if (error.response?.statusCode == 409 && mounted) {
        setState(() => _conflicted = true);
      }
      _message(error.response?.statusCode == 409
          ? '作品或关联行程已变化。当前输入已保留为草稿，请刷新作品后再编辑；也可以取消旅行关联后另存。'
          : extractServerMessage(error, fallback: '收藏失败，草稿已保留，请检查网络后重试'));
    } catch (_) {
      _message('收藏未完成，草稿仍然保留');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _leave() async {
    if (_busy) return false;
    if (_active != null) _finishInk();
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
                            style: rebuildTextStyle(context),
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('继续编辑')),
                        TextButton(
                            style: rebuildTextStyle(context),
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
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
              systemOverlayStyle: context.lgIsDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_d.kind == 'ticket' ? '制作票根' : '制作拍立得',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18)),
                    Text(
                        _saveFailed
                            ? '草稿未保存，点击重试'
                            : _saved
                                ? '私密草稿已保存'
                                : '正在保存草稿…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        style: rebuildFilledStyle(context),
                        onPressed: _busy || _loading || _loadError != null
                            ? null
                            : _publish,
                        child: Text(_busy ? '处理中' : '收藏')))
              ]),
          body: Stack(children: [
            const Positioned.fill(child: CreationBackdrop()),
            SafeArea(
                child: Column(children: [
              Expanded(
                  child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      decoration: BoxDecoration(
                          color: _d.kind == 'ticket'
                              ? (context.lgIsDark
                                  ? const Color(0xff303238)
                                  : const Color(0xffe7e9ed))
                              : _d.background,
                          borderRadius: BorderRadius.circular(24),
                          gradient: _d.kind != 'ticket' && _d.gradient
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
                                          child: CreationMaterial(
                                              document: _d,
                                              lift: .65,
                                              child: GestureDetector(
                                                onLongPress: _busy ||
                                                        _drawing ||
                                                        _loading ||
                                                        _loadError != null
                                                    ? null
                                                    : () => Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                            builder: (_) =>
                                                                CreationPreview(
                                                                    document:
                                                                        _d,
                                                                    initialBack:
                                                                        _back,
                                                                    front: CreationArtwork(
                                                                        document:
                                                                            _d,
                                                                        images:
                                                                            _images)))),
                                                onTap: _busy
                                                    ? null
                                                    : () {
                                                        if (!_drawing) _text();
                                                      },
                                                onScaleStart: _busy || _drawing
                                                    ? null
                                                    : (details) {
                                                        if (_back) return;
                                                        final point = Offset(
                                                            details.localFocalPoint
                                                                    .dx /
                                                                size.width *
                                                                880,
                                                            details.localFocalPoint
                                                                    .dy /
                                                                size.height *
                                                                (880 /
                                                                    _d.aspectRatio));
                                                        final index = CreationPainter
                                                                .photoWindows(
                                                                    _d)
                                                            .indexWhere(
                                                                (window) => window
                                                                    .contains(
                                                                        point));
                                                        if (index >= 0 &&
                                                            index <
                                                                _d.transforms
                                                                    .length) {
                                                          _cropIndex = index;
                                                        }
                                                        _undo.add(_d);
                                                        _redo.clear();
                                                        _cropStart =
                                                            _d.transforms[
                                                                _cropIndex];
                                                        _cropFocal = details
                                                            .localFocalPoint;
                                                      },
                                                onScaleUpdate: _busy || _drawing
                                                    ? null
                                                    : (details) {
                                                        if (_back) return;
                                                        final delta = details
                                                                .localFocalPoint -
                                                            _cropFocal;
                                                        final crops = _d
                                                            .transforms
                                                            .toList();
                                                        crops[_cropIndex] = CreationCrop(
                                                            scale: (_cropStart
                                                                        .scale *
                                                                    details
                                                                        .scale)
                                                                .clamp(1, 5),
                                                            x: (_cropStart.x +
                                                                    delta.dx /
                                                                        size
                                                                            .width *
                                                                        2)
                                                                .clamp(-1, 1),
                                                            y: (_cropStart.y +
                                                                    delta.dy /
                                                                        size.height *
                                                                        2)
                                                                .clamp(-1, 1));
                                                        setState(() {
                                                          _saved = false;
                                                          _draft = _draft.copyWith(
                                                              document:
                                                                  _d.copyWith(
                                                                      transforms:
                                                                          crops));
                                                        });
                                                      },
                                                onScaleEnd: _busy || _drawing
                                                    ? null
                                                    : (_) => unawaited(_save()),
                                                child: Listener(
                                                    onPointerDown: _busy || !_drawing
                                                        ? null
                                                        : (event) => _startInk(
                                                            normalized(event
                                                                .localPosition)),
                                                    onPointerMove: _busy ||
                                                            !_drawing
                                                        ? null
                                                        : (event) => _moveInk(
                                                            normalized(event
                                                                .localPosition)),
                                                    onPointerUp: _busy ||
                                                            !_drawing
                                                        ? null
                                                        : (_) => _finishInk(),
                                                    onPointerCancel: _busy ||
                                                            !_drawing
                                                        ? null
                                                        : (_) => _finishInk(),
                                                    child: CreationArtwork(
                                                        document: _d,
                                                        images: _images,
                                                        back: _back,
                                                        activeInk: _active)),
                                              ))));
                                }))),
              SizedBox(
                  height: 48,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                            tooltip: '撤销',
                            onPressed: _busy || _undo.isEmpty
                                ? null
                                : () => _history(false),
                            icon: const Icon(Icons.undo, size: 20)),
                        IconButton(
                            tooltip: '重做',
                            onPressed: _busy || _redo.isEmpty
                                ? null
                                : () => _history(true),
                            icon: const Icon(Icons.redo, size: 20)),
                        TextButton.icon(
                            style: rebuildTextStyle(context),
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
                            style: rebuildTextStyle(context),
                            onPressed: _busy ? null : _text,
                            child: const Text('文字／日期')),
                      ])),
              Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                  child: RebuildGlass(
                      padding: const EdgeInsets.all(4),
                      child: Row(children: [
                        for (final item in _d.kind == 'ticket'
                            ? [(4, '照片'), (5, '文字'), (6, '配色'), (7, '背景')]
                            : [(0, '相纸'), (1, '成像'), (2, '涂鸦'), (3, '更多')])
                          Expanded(
                              child: TextButton(
                                  style: rebuildTextStyle(context).copyWith(
                                      backgroundColor: WidgetStatePropertyAll(
                                          _tab == item.$1
                                              ? context.lgInk
                                              : Colors.transparent),
                                      shape: const WidgetStatePropertyAll(
                                          StadiumBorder()),
                                      minimumSize: const WidgetStatePropertyAll(
                                          Size(48, 48))),
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
                                              ? context.lgPaper
                                              : context.lgTextSecondary))))
                      ]))),
              SizedBox(
                  height:
                      math.min(180, MediaQuery.sizeOf(context).height * .24),
                  child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child:
                          AbsorbPointer(absorbing: _busy, child: _controls()))),
              if (_busy) const LinearProgressIndicator(minHeight: 2),
            ])),
          ]),
        ),
      );

  Widget _ticketTools() => Row(children: [
        for (final tool in [(0, '版式'), (1, '成像'), (2, '涂鸦'), (3, '更多')])
          Expanded(
              child: TextButton(
                  style: rebuildTextStyle(context),
                  onPressed: () => setState(() {
                        _tab = tool.$1;
                        _active = null;
                      }),
                  child: Text(tool.$2, style: const TextStyle(fontSize: 12))))
      ]);

  Widget _accentColors() => Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('票根配色'),
            for (final color in const [
              Color(0xff7d899b),
              Color(0xff608397),
              Color(0xff986d7e),
              Color(0xff6a8068),
              Color(0xff282b32)
            ])
              _colorChoice(color, paper: false),
          ]);

  Widget _colorChoice(Color color, {required bool paper}) {
    final selected = color == (paper ? _d.background : _d.accent);
    return Semantics(
        selected: selected,
        child: IconButton(
            tooltip:
                paper ? (_d.kind == 'ticket' ? '更换票面底色' : '更换工作台颜色') : '更换票根配色',
            onPressed: () => _change(paper
                ? _d.copyWith(background: color)
                : _d.copyWith(accent: color)),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                        color: selected ? context.lgInk : context.lgSeparator,
                        width: selected ? 2 : 1)),
                child: selected
                    ? Icon(Icons.check,
                        size: 16,
                        color: color.computeLuminance() > .45
                            ? const Color(0xff21262d)
                            : Colors.white)
                    : null)));
  }

  List<Widget> _backgroundControls() => [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(_d.kind == 'ticket' ? '票面底色' : '工作台'),
          const SizedBox(width: 8),
          for (final color in const [
            Color(0xffeef0f3),
            Color(0xffdce5ed),
            Color(0xffe7e2e8),
            Color(0xffdfe6df)
          ])
            _colorChoice(color, paper: true),
        ]),
        SwitchListTile(
            activeColor: context.lgInk,
            contentPadding: EdgeInsets.zero,
            title: Text(_d.kind == 'ticket' ? '票面柔和渐变' : '柔和渐变背景',
                style: const TextStyle(fontSize: 13)),
            value: _d.gradient,
            onChanged: (value) => _change(_d.copyWith(gradient: value))),
      ];

  Future<void> _templateLibrary() async {
    final options = _d.kind == 'ticket'
        ? ticketTemplates.map((t) => (t.id, t.label, t.minimumPhotos)).toList()
        : paperTemplates.map((p) => (p.id, p.label, 1)).toList();
    final id = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .83,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Row(children: [
                        Expanded(
                            child: Text(_d.kind == 'ticket' ? '选择票根版式' : '相纸收藏',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700))),
                        Text('${options.length} 款',
                            style: TextStyle(color: context.lgTextSecondary))
                      ])),
                  Expanded(
                      child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          itemCount: options.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: .75,
                                  mainAxisSpacing: 20,
                                  crossAxisSpacing: 22),
                          itemBuilder: (context, index) {
                            final option = options[index];
                            final selected = option.$1 == _d.templateId;
                            final canUse = _images.length >= option.$3;
                            final preview = _d.copyWith(templateId: option.$1);
                            return Semantics(
                                button: true,
                                enabled: canUse,
                                selected: selected,
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: canUse
                                        ? () =>
                                            Navigator.pop(context, option.$1)
                                        : null,
                                    child: Column(children: [
                                      Expanded(
                                          child: Opacity(
                                              opacity: canUse ? 1 : .5,
                                              child: Center(
                                                  child: AspectRatio(
                                                      aspectRatio:
                                                          preview.aspectRatio,
                                                      child: CreationMaterial(
                                                          document: preview,
                                                          lift: .6,
                                                          child: RepaintBoundary(
                                                              child: CustomPaint(
                                                                  painter: CreationPainter(
                                                                      preview,
                                                                      _images)))))))),
                                      const SizedBox(height: 12),
                                      Text(option.$2,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text(
                                          selected
                                              ? '正在使用'
                                              : canUse
                                                  ? '点击使用'
                                                  : '需${option.$3}张照片',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: context.lgTextSecondary)),
                                      const SizedBox(height: 8),
                                    ])));
                          })),
                ]))));
    if (id == null || !mounted) return;
    HapticFeedback.selectionClick();
    _change(_d.copyWith(templateId: id));
    if (_cropIndex >= CreationPainter.photoWindows(_d).length) {
      setState(() => _cropIndex = 0);
    }
  }

  Widget _controls() {
    if (_tab == 4) {
      return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      style: rebuildOutlinedStyle(context),
                      onPressed:
                          _loading || _loadError != null ? null : _replacePhoto,
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          size: 18),
                      label: Text(_images.length > 1
                          ? '更换照片 ${_cropIndex + 1}'
                          : '更换照片'))),
              const SizedBox(width: 8),
              OutlinedButton(
                  style: rebuildOutlinedStyle(context),
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
                  RebuildChoiceChip(
                      label: Text('裁切照片 ${i + 1}'),
                      selected: _cropIndex == i,
                      onSelected: (_) => setState(() => _cropIndex = i))
              ]),
            const SizedBox(height: 4),
            Text('在票面上双指缩放、拖动照片',
                style: TextStyle(fontSize: 11, color: context.lgTextSecondary)),
            _ticketTools(),
          ]));
    }
    if (_tab == 5) {
      return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_d.title.isEmpty ? '给这段旅途起个名字' : _d.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(_d.date ?? '添加日期与背面故事'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _text),
            _ticketTools(),
          ]));
    }
    if (_tab == 6 || _tab == 7) {
      return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_tab == 6) _accentColors() else ..._backgroundControls(),
            _ticketTools(),
          ]));
    }
    if (_tab == 0) {
      final options = _d.kind == 'ticket'
          ? ticketTemplates
              .map((t) => (t.id, t.label, t.minimumPhotos))
              .toList()
          : paperTemplates.map((p) => (p.id, p.label, 1)).toList();
      return Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(children: [
              Expanded(
                  child: Text(
                      _d.kind == 'ticket' ? _d.ticket.label : _d.paper.label,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600))),
              TextButton.icon(
                  style: rebuildTextStyle(context),
                  onPressed:
                      _loading || _loadError != null ? null : _templateLibrary,
                  icon: const Icon(Icons.grid_view_outlined, size: 16),
                  label: Text(
                      '全部${_d.kind == 'ticket' ? '版式' : '相纸'} ${options.length}',
                      style: const TextStyle(fontSize: 12))),
            ])),
        Expanded(
            child: ListView.separated(
                key: const PageStorageKey('creation_templates'),
                controller: _templateScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final option = options[i];
                  final preview = _d.copyWith(templateId: option.$1);
                  final selected = _d.templateId == option.$1;
                  return SizedBox(
                      width: 94,
                      child: Material(
                          color: context.lgCard,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              if (_images.length < option.$3) {
                                _message('这个版式需要 ${option.$3} 张照片，请新建时选择多张照片');
                                return;
                              }
                              HapticFeedback.selectionClick();
                              _change(preview);
                              if (_cropIndex >=
                                  CreationPainter.photoWindows(preview)
                                      .length) {
                                setState(() => _cropIndex = 0);
                              }
                            },
                            child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: selected
                                            ? context.lgInk
                                            : Colors.transparent,
                                        width: 1.5)),
                                child: Column(children: [
                                  Expanded(
                                      child: Center(
                                          child: AspectRatio(
                                              aspectRatio: preview.aspectRatio,
                                              child: RepaintBoundary(
                                                  child: CustomPaint(
                                                      painter: CreationPainter(
                                                          preview,
                                                          _images)))))),
                                  const SizedBox(height: 8),
                                  Text(option.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w400)),
                                ])),
                          )));
                })),
      ]);
    }

    if (_tab == 1) {
      return Column(children: [
        Expanded(
            child: ListView.separated(
                key: const PageStorageKey('creation_looks'),
                controller: _lookScroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: creationLooks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(
                    width: 88,
                    child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _change(_d.copyWith(lookId: creationLooks[i].id));
                        },
                        child: Column(children: [
                          Expanded(
                              child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          width: 1.5,
                                          color:
                                              _d.lookId == creationLooks[i].id
                                                  ? context.lgInk
                                                  : Colors.transparent)),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CustomPaint(
                                          size: const Size(72, 58),
                                          painter: _LookThumbnail(
                                              _images.isEmpty
                                                  ? null
                                                  : _images.first,
                                              creationLooks[i]
                                                  .matrix(_d.intensity)))))),
                          Text(creationLooks[i].label,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: _d.lookId == creationLooks[i].id
                                      ? FontWeight.w700
                                      : FontWeight.w400)),
                          Text(creationLooks[i].family,
                              style: TextStyle(
                                  fontSize: 9, color: context.lgTextSecondary)),
                        ]))))),
        Row(children: [
          const SizedBox(width: 20),
          const Text('强度'),
          Expanded(
              child: Slider(
                  activeColor: context.lgInk,
                  value: _d.intensity,
                  onChangeStart: (_) {
                    _undo.add(_d);
                    _redo.clear();
                  },
                  onChanged: (value) => setState(() {
                        _saved = false;
                        _draft = _draft.copyWith(
                            document: _d.copyWith(intensity: value));
                      }),
                  onChangeEnd: (_) => unawaited(_save()))),
          SizedBox(width: 48, child: Text('${(_d.intensity * 100).round()}%'))
        ]),
      ]);
    }
    if (_tab == 2) {
      return SingleChildScrollView(
          child: Column(children: [
        const Text('整张相纸都能画 · 切到其他工具后可缩放／移动照片', style: TextStyle(fontSize: 11)),
        Wrap(
            spacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (color, name) in const [
                (Color(0xff22252b), '墨黑'),
                (Colors.white, '白色'),
                (Color(0xff5b7498), '雾蓝'),
                (Color(0xffba6978), '玫瑰'),
                (Color(0xff768e72), '鼠尾草绿'),
                (Color(0xffc7a45e), '金色')
              ])
                Semantics(
                    button: true,
                    label: '$name画笔',
                    selected: _penColor == color && !_eraser,
                    child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _penColor = color;
                            _eraser = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _penColor == color && !_eraser
                                        ? context.lgInk
                                        : context.lgSeparator,
                                    width: 3))))),
              RebuildGlassButton(
                  label: '按笔画擦除',
                  onPressed: () => setState(() => _eraser = !_eraser),
                  selected: _eraser,
                  icon: Icons.auto_fix_normal),
            ]),
        Row(children: [
          const SizedBox(width: 20),
          const Text('笔宽'),
          Expanded(
              child: Slider(
                  activeColor: context.lgInk,
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
          if (_draft.workId != null || _conflicted)
            Row(children: [
              if (_draft.workId != null)
                Expanded(
                    child: OutlinedButton(
                        style: rebuildOutlinedStyle(context),
                        onPressed: _openLatest,
                        child: const Text('保留草稿，查看新版'))),
              const SizedBox(width: 8),
              OutlinedButton(
                  style: rebuildOutlinedStyle(context),
                  onPressed: _saveAsNew,
                  child: const Text('另存一份')),
            ]),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    style: rebuildOutlinedStyle(context),
                    onPressed:
                        _loading || _loadError != null ? null : _replacePhoto,
                    icon: const Icon(Icons.add_photo_alternate_outlined,
                        size: 18),
                    label: Text(_images.length > 1
                        ? '更换照片 ${_cropIndex + 1}'
                        : '更换照片'))),
          ]),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    style: rebuildOutlinedStyle(context),
                    onPressed: _link,
                    icon: const Icon(Icons.link, size: 18),
                    label: Text(
                        _draft.tripTitle ??
                            (_draft.tripId != null ? '已关联旅行' : '关联旅行'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis))),
            const SizedBox(width: 8),
            OutlinedButton(
                style: rebuildOutlinedStyle(context),
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
                RebuildChoiceChip(
                    label: Text('裁切照片 ${i + 1}'),
                    selected: _cropIndex == i,
                    onSelected: (_) => setState(() => _cropIndex = i))
            ]),
          ..._backgroundControls(),
          if (_d.kind == 'ticket') _accentColors(),
        ]));
  }
}
