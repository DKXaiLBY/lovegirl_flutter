import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/travel_provider.dart';
import '../../utils/constants.dart';
import '../travel/travel_form_screen.dart';

/// 足迹星图：深色星空 + 中国地图 + 城市光点（去过点亮）
class StarsMapScreen extends StatefulWidget {
  final List<TravelSpot> spots;

  const StarsMapScreen({super.key, required this.spots});

  @override
  State<StarsMapScreen> createState() => _StarsMapScreenState();
}

class _GeoCity {
  final String name;
  final String province;
  final double lng;
  final double lat;
  const _GeoCity(this.name, this.province, this.lng, this.lat);
}

class _ProvinceShape {
  final String name;
  final List<List<List<double>>> rings; // [polygon][ring][pt] 原始经纬度
  const _ProvinceShape(this.name, this.rings);
}

enum StarsView { dots, routes, photos }

class _StarsMapScreenState extends State<StarsMapScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();

  List<_ProvinceShape> _provinces = [];
  List<_GeoCity> _cities = [];
  bool _loadingGeo = true;

  StarsView _view = StarsView.dots;
  int? _highlightCityIndex;

  // 去过：city 规范化名 -> spot
  final Map<String, TravelSpot> _visitedByCity = {};
  final Set<String> _visitedProvinces = {};
  List<_GeoCity> _visitedCities = [];

  late final AnimationController _twinkle = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  static const _lngMin = 73.0, _lngMax = 136.0;
  static const _latMin = 17.5, _latMax = 54.5;

  @override
  void initState() {
    super.initState();
    _loadGeo();
    _matchVisited();
  }

  @override
  void didUpdateWidget(covariant StarsMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spots != widget.spots) _matchVisited();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _transform.dispose();
    super.dispose();
  }

  Future<void> _loadGeo() async {
    try {
      final provinceRaw =
          await rootBundle.loadString('assets/geo/provinces_slim.json');
      final citiesRaw = await rootBundle.loadString('assets/geo/cities.json');
      final provinces = <_ProvinceShape>[];
      for (final f in (jsonDecode(provinceRaw)
          as Map)['features'] as List) {
        final name = f['name'] as String?;
        final geo = f['geometry'];
        if (name == null || geo == null) continue;
        final rings = <List<List<double>>>[];
        void addPoly(List poly) {
          for (final ring in poly) {
            rings.add([
              for (final pt in ring)
                [(pt[0] as num).toDouble(), (pt[1] as num).toDouble()]
            ]);
          }
        }

        final coords = geo['coordinates'] as List;
        if (geo['type'] == 'MultiPolygon') {
          for (final poly in coords) {
            addPoly(poly as List);
          }
        } else if (geo['type'] == 'Polygon') {
          addPoly(coords);
        }
        provinces.add(_ProvinceShape(name, rings));
      }
      final cities = ((jsonDecode(citiesRaw) as List))
          .map((e) => Map<String, dynamic>.from(e))
          .map((e) =>
              _GeoCity(e['name'], e['province'], (e['lng'] as num).toDouble(),
                  (e['lat'] as num).toDouble()))
          .toList();
      if (!mounted) return;
      setState(() {
        _provinces = provinces;
        _cities = cities;
        _loadingGeo = false;
      });
      _matchVisited();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingGeo = false);
    }
  }

  /// 投影：经纬度 -> 归一化 0..1（实际绘制时再乘 size）
  Offset _project(double lng, double lat, Size size) {
    final nx = (lng - _lngMin) / (_lngMax - _lngMin);
    final ny = (_latMax - lat) / (_latMax - _latMin);
    return Offset(nx * size.width, ny * size.height);
  }

  static String _normCity(String raw) {
    var s = raw.trim();
    for (final suffix in [
      '特别行政区',
      '维吾尔自治区',
      '壮族自治区',
      '回族自治区',
      '自治区',
      '自治州',
      '地区',
      '市',
      '盟'
    ]) {
      if (s.length > suffix.length && s.endsWith(suffix)) {
        s = s.substring(0, s.length - suffix.length);
        break;
      }
    }
    return s;
  }

  void _matchVisited() {
    final byCity = <String, TravelSpot>{};
    final provinces = <String>{};
    final visitedCities = <_GeoCity>[];
    if (_cities.isEmpty) {
      return;
    }
    for (final spot in widget.spots) {
      final raw = spot.city.trim();
      if (raw.isEmpty) continue;
      final norm = _normCity(raw);
      _GeoCity? hit;
      for (final c in _cities) {
        if (c.name == raw || _normCity(c.name) == norm) {
          hit = c;
          break;
        }
      }
      if (hit == null) {
        for (final c in _cities) {
          final n = _normCity(c.name);
          if (norm.contains(n) || n.contains(norm)) {
            hit = c;
            break;
          }
        }
      }
      if (hit == null) continue;
      final key = '${hit.province}|${hit.name}';
      if (!byCity.containsKey(key)) {
        byCity[key] = spot;
        visitedCities.add(hit);
      }
      provinces.add(hit.province);
    }
    if (!mounted) return;
    setState(() {
      _visitedByCity.clear();
      _visitedByCity.addEntries(byCity.entries);
      _visitedProvinces
        ..clear()
        ..addAll(provinces);
      _visitedCities = visitedCities;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF070B14),
      child: Stack(
        fit: StackFit.loose,
        children: [
          if (_loadingGeo)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6FD9F5)),
            )
          else ...[
            Positioned.fill(
              child: Image.asset('assets/images/icons/bg_stars.png',
                  fit: BoxFit.cover),
            ),
            InteractiveViewer(
              transformationController: _transform,
              maxScale: 6,
              minScale: 0.8,
              boundaryMargin: const EdgeInsets.all(80),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: LayoutBuilder(builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, constraints.maxWidth);
                  final photoOverlays = <Widget>[];
                  if (_view == StarsView.photos) {
                    for (final c in _visitedCities) {
                      final key = '${c.province}|${c.name}';
                      final spot = _visitedByCity[key];
                      if (spot == null || spot.photos.isEmpty) continue;
                      final url = spot.photos.first.toString();
                      final p = _project(c.lng, c.lat, size);
                      photoOverlays.add(Positioned(
                        left: p.dx - 26,
                        top: p.dy - 26,
                        child: GestureDetector(
                          onTap: () => _showCitySheet(c, spot),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFF6FD9F5), width: 2),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 8)
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url.startsWith('http')
                                    ? url
                                    : '${AppConstants.baseUrl}$url',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ));
                    }
                  }
                  return Stack(children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _handleTap(d.localPosition, size),
                    onLongPressStart: (d) =>
                        _handleLongPress(d.localPosition, size),
                    onLongPressEnd: (_) =>
                        setState(() => _highlightCityIndex = null),
                    child: AnimatedBuilder(
                      animation: _twinkle,
                      builder: (context, _) => CustomPaint(
                        painter: _StarsPainter(
                          t: _twinkle.value,
                          provinces: _provinces,
                          cities: _cities,
                          visitedCities: _visitedCities,
                          visitedProvinces: _visitedProvinces,
                          visitedByCity: _visitedByCity,
                          showRoutes: _view == StarsView.routes,
                          highlightIndex: _highlightCityIndex,
                        ),
                        size: size,
                      ),
                    ),
                  ),
                  ...photoOverlays,
                ],
              );
                }),
              ),
            ),
            _buildPanel(),
          ],
        ],
      ),
    );
  }

  // ---------- 交互 ----------

  void _handleTap(Offset local, Size size) {
    final idx = _hitCity(local, size);
    if (idx == null) return;
    final city = _cities[idx];
    final key = '${city.province}|${city.name}';
    final spot = _visitedByCity[key];
    _showCitySheet(city, spot);
  }

  void _handleLongPress(Offset local, Size size) {
    final idx = _hitCity(local, size);
    if (idx == null) return;
    setState(() => _highlightCityIndex = idx);
    HapticFeedback.selectionClick();
  }

  int? _hitCity(Offset local, Size size) {
    // InteractiveViewer 反算：局部 -> 场景坐标
    final inverse = Matrix4.inverted(_transform.value);
    final scene = MatrixUtils.transformPoint(inverse, local);
    var best = -1;
    var bestDist = 26.0; // 命中半径（缩放前场景像素）
    for (var i = 0; i < _cities.length; i++) {
      final p = _project(_cities[i].lng, _cities[i].lat, size);
      final d = (p - scene).distance;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best < 0 ? null : best;
  }

  void _showCitySheet(_GeoCity city, TravelSpot? spot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CitySheet(city: city, spot: spot),
    );
  }

  // ---------- 左上毛玻璃面板 ----------

  Widget _buildPanel() {
    final visitedCount = _visitedCities.length;
    final provinceCount = _visitedProvinces.length;
    return Positioned(
      left: 14,
      top: 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 228,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF12203A).withAlpha(190),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF6FD9F5).withAlpha(80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('我的足迹',
                    style: TextStyle(
                        color: Color(0xFFBFEFFF),
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('走过的城市 拼成一张星空图',
                    style: TextStyle(
                        color: Colors.white.withAlpha(150), fontSize: 10)),
                const SizedBox(height: 10),
                _statRow('点亮城市', '$visitedCount', '/ ${_cities.length}'),
                _progressBar(visitedCount, math.max(_cities.length, 1),
                    const Color(0xFF6FD9F5)),
                const SizedBox(height: 8),
                _statRow('覆盖省份', '$provinceCount', '/ 34'),
                _progressBar(provinceCount, 34, const Color(0xFF9CE7C4)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _panelButton(
                      icon: _view == StarsView.routes
                          ? Icons.blur_circular_rounded
                          : Icons.timeline_rounded,
                      label: _view == StarsView.routes ? '光点' : '轨迹线',
                      onTap: () => setState(() {
                        _view = _view == StarsView.routes
                            ? StarsView.dots
                            : StarsView.routes;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _panelButton(
                      icon: Icons.photo_library_outlined,
                      label: _view == StarsView.photos ? '光点' : '相册',
                      onTap: () => setState(() {
                        _view = _view == StarsView.photos
                            ? StarsView.dots
                            : StarsView.photos;
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, String suffix) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(170), fontSize: 12)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF6FD9F5),
                fontSize: 17,
                fontWeight: FontWeight.w900)),
        Text(suffix,
            style: TextStyle(
                color: Colors.white.withAlpha(140), fontSize: 10)),
      ],
    );
  }

  Widget _progressBar(int value, int total, Color color) {
    final frac = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Container(height: 6, color: Colors.white.withAlpha(28)),
            // LIQUID：进度、宽度、数值三条动画同频
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: frac),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(height: 6, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6FD9F5).withAlpha(36),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF6FD9F5).withAlpha(90)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFBFEFFF)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFFBFEFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

// ================= 画笔 =================

class _StarsPainter extends CustomPainter {
  final double t;
  final List<_ProvinceShape> provinces;
  final List<_GeoCity> cities;
  final List<_GeoCity> visitedCities;
  final Set<String> visitedProvinces;
  final Map<String, TravelSpot> visitedByCity;
  final bool showRoutes;
  final int? highlightIndex;

  static const _lngMin = 73.0, _lngMax = 136.0;
  static const _latMin = 17.5, _latMax = 54.5;

  _StarsPainter({
    required this.t,
    required this.provinces,
    required this.cities,
    required this.visitedCities,
    required this.visitedProvinces,
    required this.visitedByCity,
    required this.showRoutes,
    required this.highlightIndex,
  });

  Offset _project(double lng, double lat, Size size) {
    final nx = (lng - _lngMin) / (_lngMax - _lngMin);
    final ny = (_latMax - lat) / (_latMax - _latMin);
    return Offset(nx * size.width, ny * size.height);
  }

  late List<Offset> _stars;
  Size? _builtSize;
  final Map<String, Path> _provincePaths = {};

  void _buildProvincePaths(Size size) {
    if (_builtSize == size) return;
    _builtSize = size;
    _provincePaths.clear();
    for (final p in provinces) {
      final path = Path();
      for (final ring in p.rings) {
        if (ring.isEmpty) continue;
        var first = true;
        for (final pt in ring) {
          final pos = _project(pt[0], pt[1], size);
          if (first) {
            path.moveTo(pos.dx, pos.dy);
            first = false;
          } else {
            path.lineTo(pos.dx, pos.dy);
          }
        }
        path.close();
      }
      _provincePaths[p.name] = path;
    }
  }

  void _initStars(Size size) {
    final rng = math.Random(42);
    _stars = List.generate(90, (_) {
      return Offset(rng.nextDouble() * size.width,
          rng.nextDouble() * size.height * 0.7);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    _initStars(size);


    // 星星闪烁
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _stars.length; i++) {
      final phase = (i * 0.618) % 1;
      final alpha = 0.25 + 0.55 * (0.5 + 0.5 * math.sin((t + phase) * 2 * math.pi));
      starPaint.color = Colors.white.withAlpha((alpha * 255).toInt());
      canvas.drawCircle(_stars[i], i % 5 == 0 ? 1.4 : 0.9, starPaint);
    }

    // 省界发光描边
    _buildProvincePaths(size);
    for (final province in provinces) {
      final path = _provincePaths[province.name];
      if (path == null) continue;
      // 外发光层
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = const Color(0xFF4C8FC0).withAlpha(46));
      // 主线
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = const Color(0xFF7FD4FF).withAlpha(150));
      // 去过的省份微填充
      if (visitedProvinces.contains(province.name)) {
        canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.fill
              ..color = const Color(0xFF3D7EA6).withAlpha(36));
      }
    }

    final centerPaint = Paint()..style = PaintingStyle.fill;

    // 全部城市灰点
    final greyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withAlpha(56);
    for (final city in cities) {
      canvas.drawCircle(_project(city.lng, city.lat, size), 1.3, greyPaint);
    }

    // 轨迹线视图：按 routeDay/routeOrder 顺序连接去过城市
    if (showRoutes && visitedCities.length > 1) {
      final ordered = [...visitedCities]..sort((a, b) {
          final sa = visitedByCity['${a.province}|${a.name}'];
          final sb = visitedByCity['${b.province}|${b.name}'];
          final day = (sa?.routeDay ?? 999).compareTo(sb?.routeDay ?? 999);
          if (day != 0) return day;
          final order =
              (sa?.routeOrder ?? 999).compareTo(sb?.routeOrder ?? 999);
          if (order != 0) return order;
          return a.name.compareTo(b.name);
        });
      final linePath = Path();
      var first = true;
      for (final c in ordered) {
        final p = _project(c.lng, c.lat, size);
        if (first) {
          linePath.moveTo(p.dx, p.dy);
          first = false;
        } else {
          linePath.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
          linePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = const Color(0xFF6FD9F5).withAlpha(50)
            ..strokeCap = StrokeCap.round);
      canvas.drawPath(
          linePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..shader = LinearGradient(colors: [
              const Color(0xFF6FD9F5).withAlpha(230),
              const Color(0xFF9CE7C4).withAlpha(220),
            ]).createShader(Offset.zero & size)
            ..strokeCap = StrokeCap.round);
    }

    // 去过城市：青色呼吸光点
    for (var i = 0; i < visitedCities.length; i++) {
      final c = visitedCities[i];
      final p = _project(c.lng, c.lat, size);
      final phase = (i * 0.4) % 1;
      final breathe =
          0.5 + 0.5 * math.sin((t + phase) * 2 * math.pi);
      final dimmed =
          highlightIndex != null && cities[highlightIndex!] != c;
      // 光晕
      canvas.drawCircle(
          p,
          7 + 3 * breathe,
          centerPaint
            ..color = const Color(0xFF6FD9F5)
                .withAlpha(dimmed ? 26 : (40 + 40 * breathe).toInt()));
      // 主点
      canvas.drawCircle(
          p,
          3.2,
          centerPaint
            ..color = dimmed
                ? const Color(0xFF6FD9F5).withAlpha(90)
                : const Color(0xFFBFEFFF));
      // 白芯
      canvas.drawCircle(
          p, 1.3, centerPaint..color = Colors.white.withAlpha(220));
    }

    // 长按高亮：城市名
    if (highlightIndex != null && highlightIndex! < cities.length) {
      final c = cities[highlightIndex!];
      final p = _project(c.lng, c.lat, size);
      final tp = TextPainter(
        text: TextSpan(
            text: '${c.name} · ${c.province}',
            style: const TextStyle(
                color: Color(0xFFBFEFFF),
                fontSize: 12,
                fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p + const Offset(8, -18));
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => true;
}

// ================= 城市详情弹窗 =================

class _CitySheet extends StatelessWidget {
  final _GeoCity city;
  final TravelSpot? spot;

  const _CitySheet({required this.city, required this.spot});

  String _photoUrl(TravelSpot s) {
    final photos = s.photos;
    if (photos.isEmpty) return '';
    final first = photos.first.toString();
    return first.startsWith('http') ? first : '${AppConstants.baseUrl}$first';
  }

  @override
  Widget build(BuildContext context) {
    final s = spot;
    final photo = s != null ? _photoUrl(s) : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF101B30).withAlpha(235),
              borderRadius: BorderRadius.circular(26),
              border:
                  Border.all(color: const Color(0xFF6FD9F5).withAlpha(90)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(city.name,
                        style: const TextStyle(
                            color: Color(0xFFBFEFFF),
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: s != null
                            ? const Color(0xFF6FD9F5).withAlpha(60)
                            : Colors.white.withAlpha(24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s != null ? '已点亮' : '还没去过',
                        style: const TextStyle(
                            color: Color(0xFFBFEFFF), fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white54, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  s != null
                      ? (s.visitedDate?.isNotEmpty == true
                          ? '打卡于 ${s.visitedDate}'
                          : '标记人：${s.creatorNickname ?? '我们'}')
                      : '把这个城市加进旅行计划，点亮这颗星',
                  style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
                ),
                if (s != null) ...[
                  const SizedBox(height: 12),
                  if (photo.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 170),
                        child: Image.network(photo,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink()),
                      ),
                    ),
                  if ((s.note ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(s.note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 13)),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    TravelFormScreen(spot: s)));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6FD9F5).withAlpha(50),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color:
                                      const Color(0xFF6FD9F5).withAlpha(120)),
                            ),
                            child: const Center(
                              child: Text('编辑这个地点',
                                  style: TextStyle(
                                      color: Color(0xFFBFEFFF),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
