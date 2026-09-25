import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:path_provider/path_provider.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/illus_image.dart';
import '../../widgets/lovegirl_ui.dart';

/// 月度小报：当月两人小日子的聚合卡（照片/旅行/厨房/每日一问/时光轴/慢信/豆）。
/// 卡片整体可保存为图片（RepaintBoundary 截图）。
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final ApiService _api = ApiService();
  final GlobalKey _cardKey = GlobalKey();

  late int _year;
  late int _month;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getMonthlyReport(_year, _month);
      final raw = res.data?['data'];
      if (!mounted) return;
      setState(() {
        _data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '小报没取回来，稍后再试试';
        _loading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    if (_saving) return;
    var y = _year;
    var m = _month + delta;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    if (y < 2000) return;
    final now = DateTime.now();
    if (DateTime(y, m).isAfter(DateTime(now.year, now.month))) return;
    setState(() {
      _year = y;
      _month = m;
    });
    _load();
  }

  bool _canGoNext() {
    final now = DateTime.now();
    return DateTime(_year, _month).isBefore(DateTime(now.year, now.month));
  }

  Future<void> _saveCard() async {
    if (_saving) return;
    setState(() => _saving = true);
    // 先快照年月：保存期间切换月份不应影响文件名
    final snapYear = _year;
    final snapMonth = _month;
    try {
      final b = _cardKey.currentContext?.findRenderObject();
      if (b is! RenderRepaintBoundary) {
        throw Exception('no boundary');
      }
      final image = await b.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (data == null) throw Exception('capture failed');
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final mm = snapMonth.toString().padLeft(2, '0');
      final name = 'LoveGirl_monthly_$snapYear$mm.png';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(data.buffer.asUint8List());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('小报已保存：$name'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('保存失败，再试一次'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _canGoNext();
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('月度小报'),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.lgTextPrimary,
        ),
        leading: IconButton(
          icon: AppIcon('back'),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: '保存小报',
            onPressed: _loading || _error != null ? null : _saveCard,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // 月份切换
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '上个月',
                  onPressed: _loading ? null : () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '$_year 年 $_month 月',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.lgTextPrimary,
                  ),
                ),
                IconButton(
                  tooltip: '下个月',
                  onPressed: _loading || !canNext ? null : () => _shiftMonth(1),
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: canNext ? null : context.lgTextMuted.withAlpha(90),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            RepaintBoundary(
                              key: _cardKey,
                              child: _buildReportCard(context),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context) {
    final d = _data ?? const <String, dynamic>{};
    final earned = (d['beansEarned'] as num?)?.toInt() ?? 0;
    final spent = (d['beansSpent'] as num?)?.toInt() ?? 0;
    final topDish = d['topDish']?.toString() ?? '';

    return LoveTicketCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IllusImg('ui_report', height: 76),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_month 月的小报',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: context.lgTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (d['hasPartner'] as bool?) ?? false
                          ? '两个人的小日子，都收在这里'
                          : '一个人的日子，也在好好过',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.lgTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _statRow(Icons.photo_camera_outlined, '相册留影',
              '${(d['photos'] as num?)?.toInt() ?? 0} 张'),
          _statRow(Icons.luggage_rounded, '旅行打卡',
              '${(d['travelSpots'] as num?)?.toInt() ?? 0} 个地点 · ${(d['travelCities'] as num?)?.toInt() ?? 0} 座城'),
          _statRow(
              Icons.restaurant_rounded,
              '厨房开火',
              '${(d['kitchenDone'] as num?)?.toInt() ?? 0} 单${topDish.isEmpty ? '' : ' · 最常点 $topDish'}'),
          _statRow(Icons.question_answer_rounded, '每日一问',
              '同答 ${(d['dailyDays'] as num?)?.toInt() ?? 0} 天'),
          _statRow(Icons.timeline_rounded, '时光轴',
              '${(d['timelineEvents'] as num?)?.toInt() ?? 0} 件小事'),
          _statRow(Icons.mark_email_unread_outlined, '慢信',
              '${(d['letters'] as num?)?.toInt() ?? 0} 封'),
          _statRow(Icons.savings_rounded, '爱心豆',
              '+$earned / -$spent'),
          const SizedBox(height: 6),
          Text(
            '—— LoveGirl 月度小报 · $_year 年 $_month 月',
            style: TextStyle(
              fontSize: 10.5,
              fontFamily: 'Caveat',
              fontWeight: FontWeight.w700,
              color: context.lgTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.lgInk.withAlpha(14),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: context.lgInk),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.lgTextSecondary,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 46, color: context.lgTextMuted),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: context.lgTextSecondary)),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
