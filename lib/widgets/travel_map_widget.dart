import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';

/// 旅行地图组件——模拟高德地图风格
/// 如果 amap_flutter_map 可用，可替换内部实现为 AMapWidget
class TravelMapWidget extends StatefulWidget {
  final List<TravelSpot> spots;
  final int? highlightedId;
  final void Function(TravelSpot spot)? onMarkerTap;

  const TravelMapWidget({
    super.key,
    required this.spots,
    this.highlightedId,
    this.onMarkerTap,
  });

  @override
  State<TravelMapWidget> createState() => TravelMapWidgetState();
}

class TravelMapWidgetState extends State<TravelMapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Offset _targetOffset = Offset.zero;
  Offset _currentOffset = Offset.zero;

  // 坐标映射边界
  double _minLat = 90, _maxLat = -90, _minLng = 180, _maxLng = -180;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.addListener(_onAnimTick);
    _calcBounds();
  }

  @override
  void didUpdateWidget(TravelMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spots != widget.spots) {
      _calcBounds();
    }
  }

  @override
  void dispose() {
    _animController.removeListener(_onAnimTick);
    _animController.dispose();
    super.dispose();
  }

  void _calcBounds() {
    if (widget.spots.isEmpty) return;
    _minLat = widget.spots.map((s) => s.lat).reduce((a, b) => a < b ? a : b);
    _maxLat = widget.spots.map((s) => s.lat).reduce((a, b) => a > b ? a : b);
    _minLng = widget.spots.map((s) => s.lng).reduce((a, b) => a < b ? a : b);
    _maxLng = widget.spots.map((s) => s.lng).reduce((a, b) => a > b ? a : b);

    // 单点时候扩大边界
    if (_minLat == _maxLat) {
      _minLat -= 0.02;
      _maxLat += 0.02;
    }
    if (_minLng == _maxLng) {
      _minLng -= 0.02;
      _maxLng += 0.02;
    }
  }

  /// 平滑移动到指定地点
  void animateToSpot(TravelSpot spot) {
    if (widget.spots.isEmpty) return;
    final size = context.size;
    if (size == null) return;

    final padding = 0.15;
    final latRange = (_maxLat - _minLat).abs().clamp(0.001, 180.0);
    final lngRange = (_maxLng - _minLng).abs().clamp(0.001, 180.0);
    final mapW = size.width * (1 - 2 * padding);
    final mapH = size.height * (1 - 2 * padding);

    final normX = (spot.lng - _minLng) / lngRange;
    final normY = 1.0 - (spot.lat - _minLat) / latRange;

    final cx = padding * size.width + normX * mapW;
    final cy = padding * size.height + normY * mapH;

    final viewCenter = Offset(size.width / 2, size.height / 2);
    final targetOffset = viewCenter - Offset(cx, cy);

    _targetOffset = targetOffset;
    _animController.reset();

    // 先跳到当前位置
    _currentOffset = _targetOffset;
    _animController.forward();
  }

  void _onAnimTick() {
    final t = Curves.easeInOut.transform(_animController.value);
    setState(() {
      // 微小的弹性效果
      final eased = t < 0.5
          ? 2 * t * t
          : -1 + (4 - 2 * t) * t;
      _currentOffset = Offset.lerp(
        Offset.zero,
        _targetOffset,
        eased.clamp(0.0, 1.0),
      )!;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spots.isEmpty) {
      return _buildEmptyMap();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _currentOffset += details.delta;
              });
            },
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
              ),
              child: Transform.scale(
                scale: _scale,
                child: Stack(
                children: [
                  // 地图底色
                  _buildMapBackground(size),
                  // 网格街道
                  CustomPaint(
                    size: size,
                    painter: _GridPainter(),
                  ),
                  // 连线
                  CustomPaint(
                    size: size,
                    painter: _RoutePainter(
                      spots: widget.spots,
                      offset: _currentOffset,
                      minLat: _minLat,
                      maxLat: _maxLat,
                      minLng: _minLng,
                      maxLng: _maxLng,
                    ),
                  ),
                  // 标记
                  ...widget.spots.map((spot) =>
                      _buildMarker(spot, _currentOffset, size)),
                  // 左上角放大缩小按钮
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _buildMapControls(size),
                  ),
                  // 右上角定位
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _buildLocateButton(size),
                  ),
                  // 左下角 Logo
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map, size: 14, color: LoveGirlTheme.primary),
                          SizedBox(width: 4),
                          Text(
                            'LoveMap',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: LoveGirlTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyMap() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFB2DFDB),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: LoveGirlTheme.textMuted.withAlpha(120)),
            const SizedBox(height: 12),
            Text(
              '还没有旅行地点',
              style: TextStyle(
                fontSize: 15,
                color: LoveGirlTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击右下角 + 添加你们的旅行足迹',
              style: TextStyle(
                fontSize: 13,
                color: LoveGirlTheme.textMuted.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBackground(Size size) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F5E9),
            Color(0xFFC8E6C9),
            Color(0xFFA5D6A7),
            Color(0xFF81C784),
          ],
        ),
      ),
      child: CustomPaint(
        size: size,
        painter: _TerrainPainter(),
      ),
    );
  }

  Widget _buildMarker(TravelSpot spot, Offset offset, Size size) {
    final padding = 0.15;
    final latRange = (_maxLat - _minLat).abs().clamp(0.001, 180.0);
    final lngRange = (_maxLng - _minLng).abs().clamp(0.001, 180.0);
    final mapW = size.width * (1 - 2 * padding);
    final mapH = size.height * (1 - 2 * padding);

    final normX = (spot.lng - _minLng) / lngRange;
    final normY = 1.0 - (spot.lat - _minLat) / latRange;

    final x = padding * size.width + normX * mapW + offset.dx;
    final y = padding * size.height + normY * mapH + offset.dy;

    final isHighlighted = widget.highlightedId == spot.id;
    final color = _statusColor(spot.status);
    final markerSize = isHighlighted ? 48.0 : 40.0;

    return Positioned(
      left: x - markerSize / 2,
      top: y - markerSize,
      child: GestureDetector(
        onTap: () => widget.onMarkerTap?.call(spot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: markerSize,
          height: markerSize + 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标记主体
              Container(
                width: markerSize,
                height: markerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHighlighted
                      ? color
                      : color.withAlpha(220),
                  border: Border.all(
                    color: Colors.white,
                    width: isHighlighted ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(isHighlighted ? 120 : 60),
                      blurRadius: isHighlighted ? 16 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  size: isHighlighted ? 24 : 20,
                  color: Colors.white,
                ),
              ),
              // 小三角
              ClipPath(
                clipper: _TriangleClipper(),
                child: Container(
                  width: 10,
                  height: 6,
                  color: isHighlighted ? color : color.withAlpha(220),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _scale = 1.0;

  Widget _buildMapControls(Size size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniButton(Icons.add, () {
          setState(() {
            _scale = (_scale * 1.3).clamp(0.5, 3.0);
          });
        }),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 1,
          color: Colors.white.withAlpha(100),
        ),
        const SizedBox(height: 4),
        _miniButton(Icons.remove, () {
          setState(() {
            _scale = (_scale / 1.3).clamp(0.5, 3.0);
          });
        }),
      ],
    );
  }

  Widget _miniButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withAlpha(220),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: LoveGirlTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildLocateButton(Size size) {
    return Material(
      color: Colors.white.withAlpha(220),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _currentOffset = Offset.zero;
            _scale = 1.0;
          });
        },
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: const Icon(Icons.my_location, size: 16, color: LoveGirlTheme.primary),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'visited':
        return LoveGirlTheme.visited;
      case 'wish':
        return LoveGirlTheme.wish;
      case 'planned':
        return LoveGirlTheme.planned;
      default:
        return LoveGirlTheme.textMuted;
    }
  }
}

// ==================== 网格街道绘制 ====================
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(50)
      ..strokeWidth = 0.5;

    // 水平线
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    // 垂直线
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // 粗主干道
    final mainRoadPaint = Paint()
      ..color = Colors.white.withAlpha(30)
      ..strokeWidth = 1.5;
    for (double y = 0; y < size.height; y += 160) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), mainRoadPaint);
    }
    for (double x = 0; x < size.width; x += 160) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), mainRoadPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== 地形着色 ====================
class _TerrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final parkPaint = Paint()
      ..color = const Color(0xFFA5D6A7).withAlpha(40);
    final rng = _SeededRandom(42);
    for (int i = 0; i < 8; i++) {
      final cx = rng.next() * size.width;
      final cy = rng.next() * size.height;
      final r = 20 + rng.next() * 60;
      canvas.drawOval(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        parkPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SeededRandom {
  final int seed;
  int _state;
  _SeededRandom(this.seed) : _state = seed;

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}

// ==================== 路线连线绘制 ====================
class _RoutePainter extends CustomPainter {
  final List<TravelSpot> spots;
  final Offset offset;
  final double minLat, maxLat, minLng, maxLng;

  _RoutePainter({
    required this.spots,
    required this.offset,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final visited = spots.where((s) => s.status == 'visited').toList();
    if (visited.length < 2) return;

    // 按 visitedDate 排序
    visited.sort((a, b) {
      if (a.visitedDate == null && b.visitedDate == null) return 0;
      if (a.visitedDate == null) return 1;
      if (b.visitedDate == null) return -1;
      return a.visitedDate!.compareTo(b.visitedDate!);
    });

    final padding = 0.15;
    final latRange = (maxLat - minLat).abs().clamp(0.001, 180.0);
    final lngRange = (maxLng - minLng).abs().clamp(0.001, 180.0);
    final mapW = size.width * (1 - 2 * padding);
    final mapH = size.height * (1 - 2 * padding);

    // 画虚线连接
    final dashPaint = Paint()
      ..color = LoveGirlTheme.visited.withAlpha(140)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    Offset? prevPoint;

    for (final spot in visited) {
      final normX = (spot.lng - minLng) / lngRange;
      final normY = 1.0 - (spot.lat - minLat) / latRange;
      final x = padding * size.width + normX * mapW + offset.dx;
      final y = padding * size.height + normY * mapH + offset.dy;
      final point = Offset(x, y);

      if (prevPoint != null) {
        path.moveTo(prevPoint.dx, prevPoint.dy);
        path.lineTo(point.dx, point.dy);
      }
      prevPoint = point;
    }

    // 绘制虚线
    canvas.drawPath(_dashPath(path, 6, 4), dashPaint);
  }

  Path _dashPath(Path source, double dashLength, double gapLength) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (distance + len > metric.length) {
          if (draw) {
            dest.addPath(metric.extractPath(distance, metric.length), Offset.zero);
          }
          break;
        }
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) {
    return oldDelegate.spots != spots || oldDelegate.offset != offset;
  }
}

// ==================== 标记三角剪裁 ====================
class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
