import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../services/log_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import 'wardrobe_avatar_screen.dart';

/// 换装白板（M2 W1，P13）：形象底图 + 已抠图单品拖缩摆放 → 合成 JPEG 白底 →
/// 换装穿搭（状态=待确认）。口径：wardrobe-interaction §P13 / m2-plan A3。
/// 白底固定不随主题（导出口径）；无旋转、无画布平移；互斥=替换并 toast。
class WardrobeWhiteboardScreen extends StatefulWidget {
  const WardrobeWhiteboardScreen({super.key});

  @override
  State<WardrobeWhiteboardScreen> createState() =>
      _WardrobeWhiteboardScreenState();
}

class _Placed {
  final WardrobeItem item;
  final int seq; // 插入序（配饰超限移除"最早"、同 z 序稳定排序）
  double nx; // 图层中心点（0-1）
  double ny;
  double scale; // 图层宽 / 画布宽
  _Placed(this.item, this.seq, this.nx, this.ny, this.scale);
}

class _WardrobeWhiteboardScreenState extends State<WardrobeWhiteboardScreen> {
  static const String _source = '换装';

  final GlobalKey _boundaryKey = GlobalKey();
  final List<_Placed> _placed = [];
  int _seq = 0;
  int? _selectedId;
  int? _avatarOverrideId;
  bool _saving = false;
  final Map<int, Timer> _layoutTimers = {};

  WardrobeProvider get _p => context.read<WardrobeProvider>();

  WardrobeAvatar? get _avatar {
    final list = _p.avatars;
    if (list.isEmpty) return null;
    if (_avatarOverrideId != null) {
      for (final a in list) {
        if (a.id == _avatarOverrideId) return a;
      }
    }
    return _p.defaultAvatar ?? list.first; // 无默认回退最新一张（P2-8 既有口径）
  }

  List<WardrobeItem> get _trayItems =>
      _p.items.where((e) => e.hasCutout && !e.retired).toList();

  @override
  void dispose() {
    for (final t in _layoutTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  // ---------- 放置 / 移除 ----------

  void _togglePlace(WardrobeItem item) {
    final existed = _placed.where((e) => e.item.id == item.id).toList();
    if (existed.isNotEmpty) {
      setState(() {
        _placed.removeWhere((e) => e.item.id == item.id);
        if (_selectedId == item.id) _selectedId = null;
      });
      return;
    }
    final removed = <String>[];
    // 互斥=替换并 toast（interaction §P13）
    final conflicts = wardrobeConflictsOf(item.category);
    _placed.removeWhere((e) {
      if (conflicts.contains(e.item.category)) {
        removed.add(e.item.category);
        return true;
      }
      return false;
    });
    // 鞋/包各 1：替换
    final slot = wardrobeSlotOf(item.category);
    if (slot == '鞋' || slot == '包') {
      _placed.removeWhere((e) {
        if (wardrobeSlotOf(e.item.category) == slot) {
          removed.add(e.item.category);
          return true;
        }
        return false;
      });
    }
    // 配饰 ≤3：移除最早
    if (item.category == '配饰') {
      final acc = _placed.where((e) => e.item.category == '配饰').toList();
      if (acc.length >= 3) {
        acc.sort((a, b) => a.seq.compareTo(b.seq));
        _placed.remove(acc.first);
        removed.add('配饰（最早的）');
      }
    }
    final avatarId = _avatar?.id.toString();
    final memo = avatarId == null ? null : item.itemLayout?[avatarId];
    final preset = wardrobePresetAnchors[item.category] ?? (0.5, 0.5, 0.55);
    setState(() {
      _placed.add(_Placed(item, _seq++, memo?.nx ?? preset.$1,
          memo?.ny ?? preset.$2, (memo?.scale ?? preset.$3).clamp(0.2, 1.5)));
      _selectedId = item.id;
    });
    if (removed.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('已替换：${removed.toSet().join('、')}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1)));
    }
  }

  void _clearAll() {
    if (_placed.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('清空白板？', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _placed.clear();
                  _selectedId = null;
                });
              },
              child: Text('清空',
                  style: TextStyle(color: LoveGirlTheme.red.withAlpha(230)))),
        ],
      ),
    );
  }

  void _switchAvatar() {
    final list = _p.avatars;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22))),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('换个形象',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final a in list)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _applyAvatar(a.id);
                      },
                      child: Container(
                        width: 72,
                        height: 96,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: a.id == _avatar?.id
                                ? context.lgInk
                                : LoveGirlTheme.separator,
                            width: 2,
                          ),
                        ),
                        child: Image(
                          image: CachedNetworkImageProvider(_abs(a.displayImage)),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyAvatar(int avatarId) {
    setState(() {
      _avatarOverrideId = avatarId;
      // 换形象回落：有该形象的位置记忆才沿用，否则预设锚点（同形象才对位）
      for (final pl in _placed) {
        final memo = pl.item.itemLayout?[avatarId.toString()];
        final preset =
            wardrobePresetAnchors[pl.item.category] ?? (0.5, 0.5, 0.55);
        pl.nx = memo?.nx ?? preset.$1;
        pl.ny = memo?.ny ?? preset.$2;
        pl.scale = (memo?.scale ?? preset.$3).clamp(0.2, 1.5);
      }
    });
  }

  // ---------- 位置记忆 ----------

  void _scheduleLayoutSave(_Placed pl) {
    final avatarId = _avatar?.id.toString();
    if (avatarId == null) return;
    _layoutTimers[pl.item.id]?.cancel();
    _layoutTimers[pl.item.id] = Timer(const Duration(milliseconds: 800), () {
      final merged = <String, dynamic>{};
      pl.item.itemLayout
          ?.forEach((k, v) => merged[k] = {'nx': v.nx, 'ny': v.ny, 'scale': v.scale});
      merged[avatarId] = {'nx': pl.nx, 'ny': pl.ny, 'scale': pl.scale};
      _p.saveItemLayout(pl.item.id, jsonEncode(merged));
    });
  }

  // ---------- 手势（单回调拖+缩，P2-4 pointerCount 变化时重置缩放基线） ----------

  double _scaleBase = 0.55; // 本手势起点缩放（ScaleUpdateDetails.scale 从 1.0 累计）
  int _lastPointers = 0;

  void _onScaleStart(_Placed pl, ScaleStartDetails d) {
    _scaleBase = pl.scale;
    _lastPointers = d.pointerCount;
  }

  void _onScaleUpdate(_Placed pl, double cw, ScaleUpdateDetails d) {
    if (d.pointerCount != _lastPointers) {
      // 双指按下/抬起瞬间 recognizer 会把累计 scale 重置回 1.0——
      // 以当前值为新基线，本帧不套用，防图层跳变
      _lastPointers = d.pointerCount;
      _scaleBase = pl.scale;
      return;
    }
    setState(() {
      if (d.pointerCount == 1) {
        pl.nx = (pl.nx + d.focalPointDelta.dx / cw).clamp(0.02, 0.98);
        pl.ny = (pl.ny + d.focalPointDelta.dy / cw).clamp(0.02, 0.98);
      } else if (d.pointerCount >= 2) {
        pl.scale = (_scaleBase * d.scale).clamp(0.2, 1.5);
      }
    });
  }

  void _onScaleEnd(_Placed pl, ScaleEndDetails d) {
    _scheduleLayoutSave(pl);
  }

  // ---------- 合成保存 ----------

  String _abs(String u) =>
      u.startsWith('http') ? u : '${AppConstants.baseUrl}$u';

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _waitForFrame() async {
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<void> _save() async {
    if (_placed.isEmpty || _saving) return;
    final avatar = _avatar;
    final urls = [
      if (avatar != null) _abs(avatar.displayImage),
      ..._placed.map((e) => _abs(e.item.cutoutUrl ?? '')),
    ];
    // P0-1：清选中态（边框不能烙进导出图），等清空后的那一帧真正绘制
    setState(() {
      _saving = true;
      _selectedId = null;
    });
    String? error;
    try {
      // P1-6：超时=中止保存（截到灰色占位帧是永久瑕疵），不是降级出图
      var ready = true;
      try {
        await Future.wait(urls
                .map((u) => precacheImage(CachedNetworkImageProvider(u), context)
                    .catchError((_) {})))
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        ready = false;
      }
      if (!ready) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('图片没加载完，再试一次'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2)));
        }
        return;
      }
      await _waitForFrame();
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) throw Exception('no boundary');
      final cw = boundary.size.width;
      final image =
          await boundary.toImage(pixelRatio: math.min(3, 2160 / cw));
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw Exception('capture failed');
      // JPEG q90 白底（P1-1：走既有 flutter_image_compress，不用纯 Dart 编码）
      final jpg = await FlutterImageCompress.compressWithList(
        data.buffer.asUint8List(),
        quality: 90,
        format: CompressFormat.jpeg,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/whiteboard_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(jpg);
      if (!mounted) return;
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 7)),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        helpText: '哪天穿？可选未来（计划）',
      );
      if (date == null) return; // 取消：保留白板继续摆
      error = await _p.createOutfit(
        filePath: file.path,
        source: _source,
        wornDate: _fmt(date),
        itemIds: _placed.map((e) => e.item.id).toList(),
      );
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2)));
        return;
      }
      LogService().userAction('白板:保存换装');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('已保存，等 TA 确认'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2)));
      Navigator.of(context).pop();
    } catch (_) {
      error = '保存失败，再试一次';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final avatar = _avatar;
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('换装试穿',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (avatar != null && _p.avatars.length > 1)
            TextButton(
                onPressed: _saving ? null : _switchAvatar,
                child: const Text('换形象',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          TextButton(
              onPressed: _saving ? null : _clearAll,
              child: Text('清空',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.lgTextSecondary))),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.lgInk,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _placed.isEmpty || _saving ? null : _save,
              child: Text(_saving ? '保存中…' : '保存穿搭',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: avatar == null ? _buildGuide() : _buildBoard(avatar),
    );
  }

  Widget _buildGuide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('先上传一张全身照',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('换装需要一个数字形象做底',
              style:
                  TextStyle(fontSize: 13, color: context.lgTextSecondary)),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.lgInk,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(
                      builder: (_) => const WardrobeAvatarScreen()))
                  .then((_) => setState(() {}));
            },
            child: const Text('去上传形象',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard(WardrobeAvatar avatar) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedId = null),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    color: Colors.white, // 白底固定（深浅两态/导出一致）
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRect(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image(
                                image: CachedNetworkImageProvider(
                                    _abs(avatar.displayImage)),
                                fit: BoxFit.contain, // 非 3:4 原照 contain 防砍头脚
                              ),
                            ),
                            for (final pl in _sortedPlaced())
                              _buildLayer(pl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildTray(),
      ],
    );
  }

  List<_Placed> _sortedPlaced() {
    final s = List<_Placed>.of(_placed);
    s.sort((a, b) {
      final z = wardrobeZOf(a.item.category)
          .compareTo(wardrobeZOf(b.item.category));
      return z != 0 ? z : a.seq.compareTo(b.seq);
    });
    return s;
  }

  Widget _buildLayer(_Placed pl) {
    final selected = pl.item.id == _selectedId;
    return LayoutBuilder(builder: (context, box) {
      final cw = box.maxWidth;
      return Align(
        alignment: Alignment(pl.nx * 2 - 1, pl.ny * 2 - 1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedId = pl.item.id),
          onScaleStart: (d) => _onScaleStart(pl, d),
          onScaleUpdate: (d) => _onScaleUpdate(pl, cw, d),
          onScaleEnd: (d) => _onScaleEnd(pl, d),
          child: Container(
            width: pl.scale * cw,
            padding: selected ? const EdgeInsets.all(3) : EdgeInsets.zero,
            decoration: BoxDecoration(
              border: selected
                  ? Border.all(color: context.lgInk, width: 1.2)
                  : null,
            ),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: _abs(pl.item.cutoutUrl ?? ''),
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const SizedBox(height: 1), // 保存前强制 precache，不留占位帧
                  errorWidget: (_, __, ___) => const SizedBox(height: 1),
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedId = null),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withAlpha(140),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTray() {
    final groups = <String, List<WardrobeItem>>{};
    for (final it in _trayItems) {
      groups.putIfAbsent(wardrobeSlotOf(it.category), () => []).add(it);
    }
    final order = ['上身', '下身', '外套', '鞋', '包', '配饰'];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.lgBg,
        border: Border(
            top: BorderSide(color: LoveGirlTheme.separator.withAlpha(120))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 104,
          child: _trayItems.isEmpty
              ? Center(
                  child: Text('还没有可用的抠图单品：先在单品页上传并"生成抠图"',
                      style: TextStyle(
                          fontSize: 12.5, color: context.lgTextSecondary)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (final slot in order)
                        ...[
                          if ((groups[slot] ?? const []).isNotEmpty) ...[
                            _slotDivider(slot),
                            for (final it in groups[slot]!) _trayChip(it),
                          ],
                        ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _slotDivider(String slot) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(slot,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: context.lgTextSecondary)),
        ],
      ),
    );
  }

  Widget _trayChip(WardrobeItem it) {
    final onBoard = _placed.any((e) => e.item.id == it.id);
    return GestureDetector(
      onTap: () => _togglePlace(it),
      child: Container(
        width: 64,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(4),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: onBoard ? context.lgInk : LoveGirlTheme.separator,
                  width: onBoard ? 1.6 : 1,
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: _abs(it.cutoutUrl ?? ''),
                fit: BoxFit.contain,
                memCacheWidth: 200,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              it.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5,
                  color: onBoard
                      ? context.lgTextPrimary
                      : context.lgTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
