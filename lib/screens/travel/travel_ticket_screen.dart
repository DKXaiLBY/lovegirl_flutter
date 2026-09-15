import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';

import '../../providers/travel_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/lovegirl_ui.dart';

/// 全宽水平虚线分隔符（解决 LoveTicketDivider.length=double.infinity 在 CustomPaint 中的问题）
class _FullWidthDashedLine extends StatelessWidget {
  const _FullWidthDashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, 1),
          painter: const _TicketDashedPainter(color: Color(0xFFE0D8D0)),
        );
      },
    );
  }
}

class _TicketDashedPainter extends CustomPainter {
  final Color color;
  const _TicketDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(170)
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    double current = 0;
    while (current < size.width) {
      final next = (current + dash).clamp(0.0, size.width).toDouble();
      canvas.drawLine(Offset(current, 0), Offset(next, 0), paint);
      current += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketDashedPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 旅行票根生成页面
class TravelTicketScreen extends StatefulWidget {
  final List<TravelSpot> visitedSpots;
  final TravelStats stats;

  const TravelTicketScreen({
    super.key,
    required this.visitedSpots,
    required this.stats,
  });

  @override
  State<TravelTicketScreen> createState() => _TravelTicketScreenState();
}

class _TravelTicketScreenState extends State<TravelTicketScreen> {
  final GlobalKey _ticketKey = GlobalKey();
  bool _capturing = false;

  List<TravelSpot> get _visited =>
      widget.visitedSpots.where((s) => s.status == 'visited').toList();

  String get _dateRange {
    final visited = _visited;
    if (visited.isEmpty) return '暂无日期';
    final dates = visited
        .where((s) => s.visitedDate != null && s.visitedDate!.isNotEmpty)
        .map((s) => s.visitedDate!)
        .toList();
    dates.sort();
    if (dates.isEmpty) return '暂无日期';
    if (dates.length == 1) return dates.first;
    return '${dates.first} ~ ${dates.last}';
  }

  int get _travelDays {
    final visited = _visited;
    if (visited.isEmpty) return 0;
    final dates = visited
        .where((s) => s.visitedDate != null && s.visitedDate!.isNotEmpty)
        .map((s) => s.visitedDate!)
        .toList();
    if (dates.isEmpty) return visited.length;
    dates.sort();
    try {
      final first = DateTime.parse(dates.first);
      final last = DateTime.parse(dates.last);
      return last.difference(first).inDays + 1;
    } catch (_) {
      return visited.length;
    }
  }

  Set<String> get _cities {
    return _visited.where((s) => s.city.isNotEmpty).map((s) => s.city).toSet();
  }

  List<String> get _weatherRecords {
    return _visited
        .where((s) => s.mood != null && s.mood!.isNotEmpty)
        .map((s) => '${s.visitedDate ?? ''} ${s.mood!}')
        .toList();
  }

  List<String> get _photoUrls {
    final urls = <String>[];
    for (final spot in _visited) {
      for (final photo in spot.photos) {
        final url =
            photo.startsWith('http') ? photo : '${AppConstants.baseUrl}$photo';
        urls.add(url);
      }
    }
    return urls;
  }

  Future<void> _captureAndSave() async {
    if (_capturing) return;
    setState(() => _capturing = true);

    try {
      final boundary = _ticketKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnack('截图失败，请重试');
        setState(() => _capturing = false);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showSnack('截图失败，请重试');
        setState(() => _capturing = false);
        return;
      }

      final pngBytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final ticketDir = Directory('${dir.path}/tickets');
      if (!await ticketDir.exists()) {
        await ticketDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${ticketDir.path}/旅行票根_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        _showSnack('票根已保存到: $filePath');
        OpenFilex.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('保存失败: $e');
      }
    }
    if (mounted) setState(() => _capturing = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('旅行票根'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _capturing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: '保存为图片',
            onPressed: _capturing ? null : _captureAndSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _ticketKey,
          child: _buildTicket(),
        ),
      ),
    );
  }

  Widget _buildTicket() {
    final visited = _visited;
    final cities = _cities;
    final photoUrls = _photoUrls;
    final weatherRecords = _weatherRecords;
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy.MM.dd').format(now);
    final ticketNo =
        'LG-${DateFormat('yyyyMMdd').format(now)}-${visited.length.toString().padLeft(3, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: LoveGirlTheme.cardShadowElevated(),
      ),
      child: LoveTicketCard(
        color: const Color(0xFFFFF8F0),
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== 票头 =====
            _buildHeader(ticketNo, dateStr),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _FullWidthDashedLine(),
            ),

            // ===== 目的地 =====
            _buildDestination(cities),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _FullWidthDashedLine(),
            ),

            // ===== 打卡地点 =====
            _buildSpotList(visited),

            // ===== 照片条 =====
            if (photoUrls.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _FullWidthDashedLine(),
              ),
              _buildPhotoStrip(photoUrls),
            ],

            // ===== 天气 =====
            if (weatherRecords.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _FullWidthDashedLine(),
              ),
              _buildWeather(weatherRecords),
            ],

            // ===== 票根底部 =====
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _FullWidthDashedLine(),
            ),
            _buildFooter(ticketNo),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String ticketNo, String dateStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          // 标题
          const Text(
            '旅 行 票 根',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: LoveGirlTheme.textPrimary,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '把一起去过的日子收好',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: LoveGirlTheme.textMuted.withAlpha(180),
            ),
          ),
          const SizedBox(height: 16),

          // 日期与天数
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoChip(Icons.calendar_today_rounded, _dateRange),
              const SizedBox(width: 16),
              _infoChip(Icons.timer_rounded, '共 $_travelDays 天'),
            ],
          ),
          const SizedBox(height: 12),

          // 统计摘要
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statBadge('${_visited.length}', '打卡'),
              _buildDot(),
              _statBadge('${_cities.length}', '城市'),
              _buildDot(),
              _statBadge('${widget.stats.wish + widget.stats.planned}', '待探索'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: LoveGirlTheme.accent.withAlpha(180),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _statBadge(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: LoveGirlTheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: LoveGirlTheme.textMuted.withAlpha(180),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: LoveGirlTheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LoveGirlTheme.primary.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: LoveGirlTheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LoveGirlTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestination(Set<String> cities) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_rounded,
                  size: 18, color: LoveGirlTheme.secondary),
              const SizedBox(width: 6),
              const Text(
                '目的地',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (cities.isEmpty)
            const Text(
              '暂无记录',
              style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cities.map((city) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.secondary.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: LoveGirlTheme.secondary.withAlpha(50)),
                  ),
                  child: Text(
                    city,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSpotList(List<TravelSpot> spots) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: LoveGirlTheme.visited),
              const SizedBox(width: 6),
              const Text(
                '已打卡地点',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.visited,
                ),
              ),
              const Spacer(),
              Text(
                '共 ${spots.length} 处',
                style: TextStyle(
                  fontSize: 12,
                  color: LoveGirlTheme.textMuted.withAlpha(180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (spots.isEmpty)
            const Text(
              '暂无打卡记录',
              style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
            )
          else
            ...spots.asMap().entries.map((entry) {
              final i = entry.key;
              final spot = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.visited.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: LoveGirlTheme.visited,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spot.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: LoveGirlTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (spot.city.isNotEmpty)
                      Text(
                        spot.city,
                        style: TextStyle(
                          fontSize: 12,
                          color: LoveGirlTheme.textMuted.withAlpha(200),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPhotoStrip(List<String> urls) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_rounded,
                  size: 18, color: LoveGirlTheme.accent),
              const SizedBox(width: 6),
              const Text(
                '旅行瞬间',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.accent,
                ),
              ),
              const Spacer(),
              Text(
                '${urls.length} 张',
                style: TextStyle(
                  fontSize: 12,
                  color: LoveGirlTheme.textMuted.withAlpha(180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CachedNetworkImage(
                      imageUrl: urls[index],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: LoveGirlTheme.bgLight,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: LoveGirlTheme.bgLight,
                        child: const Icon(Icons.broken_image,
                            color: LoveGirlTheme.textMuted, size: 28),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeather(List<String> records) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded,
                  size: 18, color: LoveGirlTheme.orange),
              const SizedBox(width: 6),
              const Text(
                '天气 / 心情',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...records.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  r,
                  style: const TextStyle(
                    fontSize: 13,
                    color: LoveGirlTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFooter(String ticketNo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        children: [
          // 条码
          Center(child: LoveBarcode()),
          const SizedBox(height: 10),
          Text(
            ticketNo,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: LoveGirlTheme.textMuted.withAlpha(200),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LOVEGIRL · 旅行记忆',
            style: TextStyle(
              fontSize: 10,
              color: LoveGirlTheme.textMuted.withAlpha(150),
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}
