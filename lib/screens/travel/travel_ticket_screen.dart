import 'dart:io';
import 'dart:math' as math;
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
import '../../widgets/ticket_styles.dart';

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

class _TravelTicketScreenState extends State<TravelTicketScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _ticketKey = GlobalKey();
  bool _capturing = false;
  // 票根版式：postcard 明信片 / stub 入场券 / classic 经典长票
  String _layout = 'postcard';
  late final AnimationController _flipCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620));

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  /// 背面：票根信息详情
  Widget _buildBackFace() {
    final cities = _cities.toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF22303F),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TICKET DETAILS',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...cities.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 14, color: Colors.white60),
                    const SizedBox(width: 6),
                    Text(c,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                  ],
                ),
              )),
          const Spacer(),
          Text('覆盖 ${cities.length} 个城市 · $_dateRange',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

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
      backgroundColor: context.lgBg,
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
          child: _layout == 'classic'
              ? _buildTicket()
              : AnimatedBuilder(
                  animation: _flipCtrl,
                  builder: (context, _) {
                    final v = _flipCtrl.value;
                    final showBack = v > 0.5;
                    final face = showBack
                        ? _buildBackFace()
                        : SizedBox(height: 260, child: _buildTicket());
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0015)
                        ..rotateY(v * math.pi),
                      child: showBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0015)
                                ..rotateY(math.pi),
                              child: SizedBox(
                                  height: 260, child: face),
                            )
                          : face,
                    );
                  },
                ),
        ),
      ),
      floatingActionButton: _layout == 'classic'
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                if (_flipCtrl.isAnimating) return;
                _flipCtrl.status == AnimationStatus.completed
                    ? _flipCtrl.reverse()
                    : _flipCtrl.forward();
              },
              backgroundColor: context.lgInk,
              icon: const Icon(Icons.flip_rounded, color: Colors.white),
              label: const Text('翻面',
                  style: TextStyle(color: Colors.white)),
            ),
    );
  }

  String get _primaryCity {
    final cities = _cities.toList();
    return cities.isNotEmpty ? cities.first : 'TRAVEL';
  }

  String get _primaryPhoto => _photoUrls.isEmpty ? '' : _photoUrls.first;

  String get _primaryQuote {
    for (final spot in _visited) {
      final note = (spot.note ?? '').trim();
      if (note.isNotEmpty) return note;
      final diary = (spot.diary ?? '').trim();
      if (diary.isNotEmpty) return diary;
    }
    return '把喜欢的地方，一步一步走成回忆';
  }

  Widget _buildLayoutSwitch() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'postcard', label: Text('明信片')),
                ButtonSegment(value: 'stub', label: Text('入场券')),
                ButtonSegment(value: 'classic', label: Text('经典')),
              ],
              selected: {_layout},
              onSelectionChanged: (sel) =>
                  setState(() => _layout = sel.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: LoveGirlTheme.primary,
                selectedForegroundColor: Colors.white,
                backgroundColor: Colors.white,
                foregroundColor: context.lgTextSecondary,
                side: BorderSide(color: context.lgSeparator),
              ),
            ),
          ),
        ],
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

    if (_layout != 'classic') {
      final photo = _primaryPhoto.isEmpty ? null : _primaryPhoto;
      return Column(
        children: [
          _buildLayoutSwitch(),
          if (_layout == 'postcard')
            VerticalPostcardTicket(
              photoUrl: photo,
              city: _primaryCity,
              quote: _primaryQuote,
              date: _dateRange,
            )
          else
            HorizontalTicketStub(
              photoUrl: photo,
              city: _primaryCity,
              quote: _primaryQuote,
              ticketNo: ticketNo,
              date: _dateRange,
            ),
          if (photo == null) ...[
            SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.lgPaperWarm,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.lgSeparator),
              ),
              child: Row(
                children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 18, color: context.lgInk),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '照片墙还是空的：编辑地点时上传照片，票根会自动用上',
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ], // photo==null spread
        ], // 外层 Column children
      ); // 外层 Column
    }

    return Column(
      children: [
        _buildLayoutSwitch(),
        Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(18),
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
          ], // 内层 Column children
        ), // 内层 Column
      ), // LoveTicketCard
    ), // Container(decoration)
        ], // 外层 Column children
      ); // 外层 Column return
  }

  Widget _buildHeader(String ticketNo, String dateStr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          // 标题
          Text(
            '旅 行 票 根',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: context.lgTextPrimary,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '把一起去过的日子收好',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.lgTextMuted.withAlpha(180),
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: context.lgInk,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.lgTextMuted.withAlpha(180),
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.lgInk.withAlpha(15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.lgInk.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.lgInk),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.lgInk,
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
              Icon(Icons.explore_rounded,
                  size: 18, color: LoveGirlTheme.secondary),
              SizedBox(width: 6),
              Text(
                '目的地',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (cities.isEmpty)
            Text(
              '暂无记录',
              style: TextStyle(fontSize: 13, color: context.lgTextMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cities.map((city) {
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.secondary.withAlpha(18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: LoveGirlTheme.secondary.withAlpha(50)),
                  ),
                  child: Text(
                    city,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.lgTextPrimary,
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
              Icon(Icons.check_circle_rounded,
                  size: 18, color: LoveGirlTheme.visited),
              SizedBox(width: 6),
              Text(
                '已打卡地点',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.visited,
                ),
              ),
              Spacer(),
              Text(
                '共 ${spots.length} 处',
                style: TextStyle(
                  fontSize: 12,
                  color: context.lgTextMuted.withAlpha(180),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (spots.isEmpty)
            Text(
              '暂无打卡记录',
              style: TextStyle(fontSize: 13, color: context.lgTextMuted),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LoveGirlTheme.visited,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spot.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.lgTextPrimary,
                        ),
                      ),
                    ),
                    if (spot.city.isNotEmpty)
                      Text(
                        spot.city,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.lgTextMuted.withAlpha(200),
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
              Icon(Icons.photo_library_rounded,
                  size: 18, color: LoveGirlTheme.accent),
              SizedBox(width: 6),
              Text(
                '旅行瞬间',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.accent,
                ),
              ),
              Spacer(),
              Text(
                '${urls.length} 张',
                style: TextStyle(
                  fontSize: 12,
                  color: context.lgTextMuted.withAlpha(180),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CachedNetworkImage(
                      imageUrl: urls[index],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: context.lgBg,
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: context.lgBg,
                        child: Icon(Icons.broken_image,
                            color: context.lgTextMuted, size: 28),
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
              Icon(Icons.wb_sunny_rounded,
                  size: 18, color: LoveGirlTheme.orange),
              SizedBox(width: 6),
              Text(
                '天气 / 心情',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          ...records.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  r,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.lgTextSecondary,
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.lgTextMuted.withAlpha(200),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LOVEGIRL · 旅行记忆',
            style: TextStyle(
              fontSize: 10,
              color: context.lgTextMuted.withAlpha(150),
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }
}
