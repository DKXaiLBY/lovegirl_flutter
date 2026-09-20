import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';

/// 年度恋爱报告：把这一年的数据讲成一个故事（截图友好）
class AnnualReportScreen extends StatefulWidget {
  const AnnualReportScreen({super.key});

  @override
  State<AnnualReportScreen> createState() => _AnnualReportScreenState();
}

class _AnnualReportScreenState extends State<AnnualReportScreen> {
  late int _year = DateTime.now().year;
  Map<String, dynamic>? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().getLoveReport(year: _year);
      final d = res.data?['data'];
      if (d is Map) {
        _report = d.cast<String, dynamic>();
      }
    } catch (_) {
      _error = '报告加载失败';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 4),
              child: Row(
                children: [
                  LoveIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '年度报告',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<int>(
                    initialValue: _year,
                    onSelected: (y) {
                      setState(() => _year = y);
                      _load();
                    },
                    itemBuilder: (_) => [
                      for (final y in [
                        DateTime.now().year,
                        DateTime.now().year - 1,
                        DateTime.now().year - 2,
                      ])
                        PopupMenuItem(value: y, child: Text('$y 年')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.lgPaper,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: context.lgSeparator),
                      ),
                      child: Row(
                        children: [
                          Text('$_year',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: LoveGirlTheme.primary))
                  : _error != null
                      ? EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: _error!,
                          onRetry: _load)
                      : _buildReport(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(BuildContext context) {
    final r = _report!;
    final travel = (r['travel'] as Map?)?.cast<String, dynamic>() ?? const {};
    final kitchen = (r['kitchen'] as Map?)?.cast<String, dynamic>() ?? const {};
    final spots = (travel['spots'] as num?)?.toInt() ?? 0;
    final cities = (travel['cities'] as num?)?.toInt() ?? 0;
    final orders = (kitchen['orders'] as num?)?.toInt() ?? 0;
    final fedMe = (kitchen['fedMe'] as num?)?.toInt() ?? 0;
    final topDish = kitchen['topDish']?.toString();
    final dailyDays = (r['dailyDays'] as num?)?.toInt() ?? 0;
    final beans = (r['beansEarned'] as num?)?.toInt() ?? 0;
    final photos = (r['photos'] as num?)?.toInt() ?? 0;
    final timelineEvents = (r['timelineEvents'] as num?)?.toInt() ?? 0;
    final letters = (r['letters'] as num?)?.toInt() ?? 0;
    final busiestMonth = r['busiestMonth']?.toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        // Hero
        LovePaper(
          color: context.lgPaperWarm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories_rounded,
                      size: 18, color: context.lgEmotion),
                  const SizedBox(width: 6),
                  Text(
                    '$_year · 你们的年度故事',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.lgTextSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _heroSummary(spots, orders, dailyDays),
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 数据网格
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _StatTile(
                icon: Icons.map_rounded,
                label: '去过的地方',
                value: '$spots',
                sub: '$cities 座城市',
                color: LoveGirlTheme.secondary),
            _StatTile(
                icon: Icons.restaurant_rounded,
                label: '厨房订单',
                value: '$orders',
                sub: 'TA 为你做了 $fedMe 次',
                color: LoveGirlTheme.orange),
            _StatTile(
                icon: Icons.quiz_rounded,
                label: '每日一问',
                value: '$dailyDays 天',
                sub: '一起作答的日子',
                color: context.lgEmotion),
            _StatTile(
                icon: Icons.savings_rounded,
                label: '爱心豆',
                value: '$beans',
                sub: '今年一起赚到',
                color: LoveGirlTheme.brandEmotion),
            _StatTile(
                icon: Icons.photo_library_rounded,
                label: '相册照片',
                value: '$photos',
                sub: '存进回忆里',
                color: LoveGirlTheme.secondary),
            _StatTile(
                icon: Icons.confirmation_number_outlined,
                label: '时光轴事件',
                value: '$timelineEvents',
                sub: letters > 0 ? '慢信 $letters 封' : '值得纪念的瞬间',
                color: context.lgInk),
          ],
        ),
        const SizedBox(height: 16),
        // 亮点
        LovePaper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '年度亮点',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (topDish != null)
                _HighlightRow(Icons.restaurant_menu_rounded,
                    '最常点的菜是「$topDish」'),
              if (busiestMonth != null)
                _HighlightRow(Icons.calendar_month_rounded,
                    '$busiestMonth 是你们最热闹的一个月'),
              if (dailyDays > 0)
                _HighlightRow(Icons.favorite_rounded,
                    '有 $dailyDays 天，你们都认真回答了同一个问题'),
              if (fedMe > 0)
                _HighlightRow(Icons.soup_kitchen_rounded,
                    'TA 给你做了 $fedMe 次饭，都记在这里'),
              if (topDish == null &&
                  busiestMonth == null &&
                  dailyDays == 0 &&
                  fedMe == 0)
                _HighlightRow(Icons.auto_awesome_rounded,
                    '新的一年，多留下一些两个人的痕迹吧'),
            ],
          ),
        ),
      ],
    );
  }

  String _heroSummary(int spots, int orders, int dailyDays) {
    final parts = <String>[];
    if (spots > 0) parts.add('一起去了 $spots 个地方');
    if (orders > 0) parts.add('下了 $orders 次厨房订单');
    if (dailyDays > 0) parts.add('答了 $dailyDays 天每日一问');
    if (parts.isEmpty) return '这一年才刚开始，故事慢慢写。';
    return '${parts.join('，')}。'.replaceFirst('，。', '。');
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgSeparator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.lgTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: context.lgTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: context.lgTextMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HighlightRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.lgEmotion),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: context.lgTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
