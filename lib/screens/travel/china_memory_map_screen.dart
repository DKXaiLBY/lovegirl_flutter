import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/travel_provider.dart';
import '../../utils/constants.dart';
import '../../utils/china_geo.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/travel_memories.dart';
import '../../widgets/memory_controls.dart';
import 'travel_memory_screen.dart';

/// 省份点亮地图（W6 弹药库：map-for-love 交互复刻，Dart 自研）。
/// 到访过的地点按经纬度做点在多边形判定点亮所在省份；
/// 点击已点亮省份弹出该省城市记忆清单。九段线按规范保留（虚线）。
class ChinaMemoryMapScreen extends StatefulWidget {
  final List<TravelSpot> spots;

  const ChinaMemoryMapScreen({super.key, required this.spots});

  @override
  State<ChinaMemoryMapScreen> createState() => _ChinaMemoryMapScreenState();
}

/// 投影后的省份形状（点已做墨卡托 y 归一，paint 阶段只做线性映射）
class _ProjShape {
  final GeoShape shape;
  final List<List<List<Offset>>> polys; // [poly][ring][point]
  const _ProjShape(this.shape, this.polys);
}

class _ChinaMemoryMapScreenState extends State<ChinaMemoryMapScreen>
    with SingleTickerProviderStateMixin {
  static const double _mapPadding = 6;

  List<_ProjShape>? _shapes;
  _ProjShape? _dashLine;
  Map<int, List<TravelSpot>> _litMap = {};
  List<TravelSpot> _visited = [];
  final Map<int, TravelSpot> _edits = {};
  List<double>? _bounds; // [minX, maxX, minY, maxY]（墨卡托空间）
  double _aspect = 0.82; // spanX / spanY

  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final geo = await loadChinaGeo();
    if (!mounted) return;

    final visited = widget.spots
        .map((spot) => _edits[spot.id] ?? spot)
        .where((s) => s.status == 'visited' && (s.lat != 0 || s.lng != 0))
        .toList();

    final shapes = <_ProjShape>[];
    _ProjShape? dash;
    var minX = double.infinity,
        maxX = double.negativeInfinity,
        minY = double.infinity,
        maxY = double.negativeInfinity;

    void project(GeoShape shape, {required bool isDash}) {
      final polys = <List<List<Offset>>>[];
      for (final poly in shape.polygons) {
        final rings = <List<Offset>>[];
        for (final ring in poly) {
          final pts = <Offset>[];
          for (final p in ring.points) {
            // 屏幕坐标 y 向下增、纬度向上增 → 墨卡托值取负，北在上
            pts.add(Offset(p.dx, -mercatorY(p.dy)));
          }
          if (pts.length < 3) continue;
          rings.add(pts);
          for (final p in pts) {
            if (p.dx < minX) minX = p.dx;
            if (p.dx > maxX) maxX = p.dx;
            if (p.dy < minY) minY = p.dy;
            if (p.dy > maxY) maxY = p.dy;
          }
        }
        if (rings.isNotEmpty) polys.add(rings);
      }
      if (polys.isEmpty) return;
      final proj = _ProjShape(shape, polys);
      if (isDash) {
        dash = proj;
      } else {
        shapes.add(proj);
      }
    }

    for (final p in geo.provinces) {
      project(p, isDash: false);
    }
    if (geo.dashLine != null) project(geo.dashLine!, isDash: true);

    final lit = <int, List<TravelSpot>>{};
    for (final s in geo.provinces) {
      final inProv =
          visited.where((sp) => s.containsPoint(sp.lng, sp.lat)).toList();
      if (inProv.isNotEmpty) lit[s.adcode] = inProv;
    }
    lit.remove(100000);

    setState(() {
      _shapes = shapes;
      _dashLine = dash;
      _litMap = lit;
      _visited = visited;
      _bounds = [minX, maxX, minY, maxY];
      _aspect = (maxX - minX) / math.max(1e-6, maxY - minY);
    });
    _anim.forward();
  }

  void _onTapUp(TapUpDetails d, List<double> fit) {
    final shapes = _shapes;
    final bounds = _bounds;
    if (shapes == null || bounds == null) return;
    final gx = (d.localPosition.dx - fit[1]) / fit[0] + bounds[0];
    // 投影时 y 已取负：屏幕 y → 负墨卡托值 → 还原正值再反投影
    final nMerc = (d.localPosition.dy - fit[2]) / fit[0] + bounds[2];
    final gy = inverseMercatorY(-nMerc);
    for (final s in shapes) {
      if (!s.shape.containsPoint(gx, gy)) continue;
      final spots = _litMap[s.shape.adcode];
      if (spots != null && spots.isNotEmpty) {
        _showProvinceSheet(s.shape.name, spots);
      }
      return;
    }
  }

  void _showProvinceSheet(String province, List<TravelSpot> spots) {
    final adcode = _litMap.entries
        .firstWhere((entry) => identical(entry.value, spots))
        .key;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, updateSheet) {
          final groups = groupTravelMemories(_litMap[adcode] ?? []);
          return FractionallySizedBox(
            heightFactor: 0.78,
            child: MemoryGlass(
                child: SafeArea(
              top: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 8, 10),
                  child: Row(children: [
                    Expanded(
                        child: Text('$province的回忆',
                            style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: context.lgTextPrimary))),
                    IconButton(
                        tooltip: '关闭回忆列表',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close)),
                  ]),
                ),
                Expanded(
                    child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  children: [
                    if (groups.isEmpty) const Text('这里还没有已打卡记录'),
                    for (final group in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 18, bottom: 8),
                        child: Text(group.key,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.lgTextPrimary)),
                      ),
                      for (final spot in group.value)
                        Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            minVerticalPadding: 14,
                            leading: SizedBox(
                              width: 60,
                              height: 60,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (spot.coverImage ??
                                            (spot.photos.isEmpty
                                                ? ''
                                                : spot.photos.first))
                                        .isEmpty
                                    ? ColoredBox(
                                        color: context.lgPrimarySoft,
                                        child: Icon(Icons.photo_outlined,
                                            color: context.lgTextMuted))
                                    : CachedNetworkImage(
                                        imageUrl: (spot.coverImage ??
                                                    spot.photos.first)
                                                .startsWith('http')
                                            ? (spot.coverImage ??
                                                spot.photos.first)
                                            : AppConstants.baseUrl +
                                                (spot.coverImage ??
                                                    spot.photos.first),
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Icon(
                                            Icons.broken_image_outlined,
                                            color: context.lgTextMuted),
                                      ),
                              ),
                            ),
                            title: Text(spot.name),
                            subtitle: Text(
                                [
                                  (spot.visitedDate ?? '日期待补充')
                                      .split('T')
                                      .first
                                      .split(' ')
                                      .first,
                                  if ((spot.diary ?? spot.note ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    (spot.diary ?? spot.note)!.trim(),
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                Navigator.of(ctx).push(MaterialPageRoute(
                              builder: (_) => TravelMemoryScreen(
                                spot: spot,
                                onChanged: (updated) {
                                  _edits[updated.id] = updated;
                                  _load().then((_) {
                                    if (ctx.mounted) updateSheet(() {});
                                  });
                                },
                              ),
                            )),
                          ),
                        ),
                    ],
                  ],
                )),
              ]),
            )),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? LoveGirlTheme.bgDark : LoveGirlTheme.bgLight;
    final textMain =
        dark ? LoveGirlTheme.textPrimaryDark : LoveGirlTheme.textPrimary;
    final textSub =
        dark ? LoveGirlTheme.textSecondaryDark : LoveGirlTheme.textSecondary;
    final card = dark ? LoveGirlTheme.cardDark : Colors.white;

    final unlitFill = dark ? const Color(0xFF2E2A26) : const Color(0xFFF0EAE0);
    final stroke = dark ? const Color(0xFF3E3833) : const Color(0xFFE2D8C9);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_rounded, color: textMain),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('我们的足迹地图',
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: textMain)),
                        const SizedBox(height: 2),
                        Text('走过的每一寸土地，都会亮起来',
                            style: TextStyle(fontSize: 12, color: textSub)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _StatCard(
                    value: '${_litMap.length}',
                    suffix: '/34',
                    label: '已点亮省份',
                    dark: dark,
                    card: card,
                    accent: LoveGirlTheme.peach,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: '${visitedMemoryCityCount(_visited)}',
                    suffix: ' 座',
                    label: '到访城市',
                    dark: dark,
                    card: card,
                    accent: textMain,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Row(
                children: [
                  _LegendDot(
                      color: LoveGirlTheme.peach,
                      label: '已点亮',
                      textColor: textSub),
                  const SizedBox(width: 16),
                  _LegendDot(
                      color: unlitFill,
                      label: '待解锁',
                      textColor: textSub,
                      bordered: true),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (ctx, cons) {
                  final shapes = _shapes;
                  final bounds = _bounds;
                  if (shapes == null || bounds == null) {
                    return const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  var w = cons.maxWidth;
                  var h = w / math.max(0.05, _aspect);
                  if (h > cons.maxHeight) {
                    h = cons.maxHeight;
                    w = h * math.max(0.05, _aspect);
                  }
                  return AnimatedBuilder(
                    animation: _anim,
                    builder: (ctx, _) {
                      // fit 必须按实际画布尺寸计算，与命中判定共用同一套参数
                      final fit = geoFitExtent(
                        minX: bounds[0],
                        maxX: bounds[1],
                        minY: bounds[2],
                        maxY: bounds[3],
                        width: w,
                        height: h,
                        padding: _mapPadding,
                      );
                      return GestureDetector(
                        onTapUp: (d) => _onTapUp(d, fit),
                        child: CustomPaint(
                          size: Size(w, h),
                          painter: _ChinaMapPainter(
                            shapes: shapes,
                            dashLine: _dashLine,
                            litMap: _litMap,
                            fit: fit,
                            bounds: bounds,
                            progress:
                                Curves.easeOutCubic.transform(_anim.value),
                            unlitFill: unlitFill,
                            stroke: stroke,
                            dark: dark,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Center(
                child: Text('点击已点亮的省份，查看城市记忆',
                    style: TextStyle(fontSize: 12, color: textSub)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String suffix;
  final String label;
  final bool dark;
  final Color card;
  final Color accent;

  const _StatCard({
    required this.value,
    required this.suffix,
    required this.label,
    required this.dark,
    required this.card,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final textSub =
        dark ? LoveGirlTheme.textSecondaryDark : LoveGirlTheme.textSecondary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1.0)),
                Text(suffix,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textSub)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: textSub)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;
  final bool bordered;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.textColor,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: bordered
                ? Border.all(color: textColor.withValues(alpha: 0.4), width: 1)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}

class _ChinaMapPainter extends CustomPainter {
  final List<_ProjShape> shapes;
  final _ProjShape? dashLine;
  final Map<int, List<TravelSpot>> litMap;
  final List<double> fit; // [scale, ox, oy]
  final List<double> bounds; // [minX, maxX, minY, maxY]
  final double progress;
  final Color unlitFill;
  final Color stroke;
  final bool dark;

  const _ChinaMapPainter({
    required this.shapes,
    required this.dashLine,
    required this.litMap,
    required this.fit,
    required this.bounds,
    required this.progress,
    required this.unlitFill,
    required this.stroke,
    required this.dark,
  });

  /// 墨卡托点 → 画布：先减 bounds 原点再套 fit（geoFitExtent 以 (0,0) 为基准）
  Offset _map(Offset p) => Offset((p.dx - bounds[0]) * fit[0] + fit[1],
      (p.dy - bounds[2]) * fit[0] + fit[2]);

  Path _buildPath(_ProjShape s) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final poly in s.polys) {
      for (final ring in poly) {
        if (ring.isEmpty) continue;
        final first = _map(ring.first);
        path.moveTo(first.dx, first.dy);
        for (final p in ring.skip(1)) {
          final m = _map(p);
          path.lineTo(m.dx, m.dy);
        }
        path.close();
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i < shapes.length; i++) {
      final s = shapes[i];
      final lit = litMap.containsKey(s.shape.adcode);
      final idx = lit ? litMap.keys.toList().indexOf(s.shape.adcode) : i;
      final local = ((progress * 1.5 - idx * 0.014)).clamp(0.0, 1.0);
      final ease = Curves.easeOutCubic.transform(local);
      final path = _buildPath(s);

      if (lit) {
        fillPaint.color = LoveGirlTheme.peach.withValues(alpha: 0.92 * ease);
      } else {
        fillPaint.color =
            unlitFill.withValues(alpha: unlitFill.a * (0.5 + 0.5 * ease));
      }
      canvas.drawPath(path, fillPaint);

      strokePaint.color = lit
          ? Colors.white.withValues(alpha: 0.85 * ease)
          : stroke.withValues(alpha: stroke.a * ease);
      canvas.drawPath(path, strokePaint);

      if (lit && ease > 0.6) {
        _drawLabel(canvas, s, (ease - 0.6) / 0.4);
      }
    }

    final dash = dashLine;
    if (dash != null) {
      final dashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = stroke.withValues(alpha: stroke.a * progress);
      for (final poly in dash.polys) {
        for (final ring in poly) {
          if (ring.isEmpty) continue;
          final path = Path();
          final first = _map(ring.first);
          path.moveTo(first.dx, first.dy);
          for (final p in ring.skip(1)) {
            final m = _map(p);
            path.lineTo(m.dx, m.dy);
          }
          for (final metric in path.computeMetrics()) {
            var dist = 0.0;
            while (dist < metric.length) {
              final next = math.min(dist + 4, metric.length);
              canvas.drawPath(metric.extractPath(dist, next), dashPaint);
              dist = next + 3;
            }
          }
        }
      }
    }
  }

  void _drawLabel(Canvas canvas, _ProjShape s, double alpha) {
    // 取最大环（点最多）做近似质心，标注省名
    List<Offset>? main;
    for (final poly in s.polys) {
      for (final ring in poly) {
        if (main == null || ring.length > main.length) main = ring;
      }
    }
    if (main == null || main.isEmpty) return;
    var cx = 0.0;
    var cy = 0.0;
    for (final p in main) {
      cx += p.dx;
      cy += p.dy;
    }
    final center = _map(Offset(cx / main.length, cy / main.length));

    final tp = TextPainter(
      text: TextSpan(
        text: s.shape.name,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
          shadows: [
            Shadow(
                color: const Color(0xFF7A3010).withValues(alpha: 0.35 * alpha),
                blurRadius: 3),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ChinaMapPainter old) =>
      old.progress != progress ||
      old.litMap != litMap ||
      old.unlitFill != unlitFill ||
      old.stroke != stroke ||
      old.shapes != shapes;
}
