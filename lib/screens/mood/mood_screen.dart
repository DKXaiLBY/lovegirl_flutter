import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/lovegirl_ui.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});
  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final ApiService _api = ApiService();
  Map<String, List<Map<String, dynamic>>> _moodsByDay = {}; // date -> 该日全部心情（W5）
  List<Map<String, dynamic>> _moods = [];
  bool _loading = true;
  String? _error;
  late DateTime _currentMonth;

  static const _moodIcons = [
    Icons.sentiment_satisfied_rounded,
    Icons.favorite_rounded,
    Icons.volunteer_activism_rounded,
    Icons.sentiment_dissatisfied_rounded,
    Icons.sentiment_very_dissatisfied_rounded,
    Icons.bedtime_rounded,
    Icons.celebration_rounded,
    Icons.self_improvement_rounded,
    Icons.water_drop_rounded,
    Icons.mood_bad_rounded,
  ];
  static const _labels = [
    '开心',
    '幸福',
    '恋爱',
    '难过',
    '生气',
    '疲惫',
    '兴奋',
    '悠闲',
    '委屈',
    '烦躁'
  ];
  // v3.42 消解同色/近色（幸福 vs 难过曾同色、疲惫/烦躁两灰难分、开心/悠闲同绿系）
  static const _moodColors = [
    Color(0xFF8FAE8B),
    Color(0xFF7B8CFF),
    Color(0xFF6BD4FF),
    Color(0xFF5B6EA8),
    Color(0xFFE95B4E),
    Color(0xFF9E9EAD),
    Color(0xFF00BCD4),
    Color(0xFF4DB6A2),
    Color(0xFF9E9AD1),
    Color(0xFFB58860),
  ];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final monthStr = DateFormat('yyyy-MM').format(_currentMonth);
    try {
      final results = await Future.wait([
        _api.getMoods(monthStr),
        _api.getMoodStats(monthStr),
      ]);
      final data1 = results[0].data?['data'];
      List raw = data1 is List ? data1 : [];
      _moods = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      _moodsByDay = groupMoodsByDate(_moods);
      LogService().info('Mood', '加载${_moods.length}条记录');
    } catch (e) {
      _error = '加载失败';
      LogService().error('Mood', '加载失败: $e');
    }
    setState(() => _loading = false);
  }

  void _prevMonth() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_currentMonth.year == now.year && _currentMonth.month == now.month) {
      return;
    }
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    _loadData();
  }

  List<Map<String, dynamic>> _getDayMoods(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return _moodsByDay[key] ?? const [];
  }

  MoodData _moodToData(Map<String, dynamic> m) {
    final idx = int.tryParse((m['emoji'] ?? '0').toString()) ?? 0;
    return MoodData(
      hasMood: true,
      icon: (idx >= 0 && idx < _moodIcons.length)
          ? _moodIcons[idx]
          : Icons.sentiment_satisfied_rounded,
      color: (idx >= 0 && idx < _moodColors.length)
          ? _moodColors[idx]
          : context.lgInk,
      label: m['label'] ?? _labels[idx.clamp(0, _labels.length - 1)],
      note: m['note'] ?? '',
      raw: m,
    );
  }

  MoodData _getDayMood(DateTime day) {
    final list = _getDayMoods(day);
    if (list.isEmpty) return MoodData.empty();
    return _moodToData(list.first);
  }

  void _showDayDetail(DateTime day) {
    final moods = _getDayMoods(day);
    if (moods.isEmpty) return;
    final items = moods.map(_moodToData).toList();
    _showGlassSheet(
      ctx: context,
      builder: (ctx) => ConstrainedBox(
        // 多条记录时弹层限高（对抗审查 P2-4），单条布局与旧版一致
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSheetGrabber(),
            SizedBox(height: 20),
            Text(DateFormat('M月d日 EEEE', 'zh_CN').format(day),
                style: TextStyle(
                    fontSize: 14, color: context.lgTextMuted)),
            SizedBox(height: 16),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final mood in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              color: (mood.color ?? context.lgTextMuted)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle),
                          child: Icon(mood.icon,
                              size: 30,
                              color: mood.color ?? context.lgTextMuted),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mood.label,
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: mood.color ??
                                          context.lgTextMuted)),
                              if (mood.note.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(mood.note,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: context.lgTextSecondary,
                                        height: 1.4)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    int selectedIdx = 0;
    final noteCtrl = TextEditingController();
    _showGlassSheet(
      ctx: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          // 键盘避让在外层 _showGlassSheet 已处理；这里只留输入区与按钮的呼吸位
          padding: const EdgeInsets.only(bottom: 4, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetGrabber(width: 36),
              const SizedBox(height: 20),
              const Text('记录今天的心情',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(_moodIcons.length, (i) {
                  final sel = selectedIdx == i;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedIdx = i),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel
                            ? _moodColors[i].withValues(alpha: 0.14)
                            : context.lgBg,
                        border: Border.all(
                            color: sel
                                ? _moodColors[i]
                                : context.lgCardBorder,
                            width: sel ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_moodIcons[i], size: 24, color: _moodColors[i]),
                          Text(_labels[i],
                              style: TextStyle(
                                  fontSize: 10,
                                  color: sel
                                      ? _moodColors[i]
                                      : context.lgTextMuted)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),
              TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: '写点什么吧...', prefixIcon: Icon(Icons.edit_note))),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.lgInk,
                    foregroundColor:
                        context.lgIsDark ? context.lgBg : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  onPressed: () async {
                    try {
                      final now =
                          DateFormat('yyyy-MM-dd').format(DateTime.now());
                      await _api.recordMood({
                        'date': now,
                        'emoji': selectedIdx.toString(),
                        'label': _labels[selectedIdx],
                        'note': noteCtrl.text.trim()
                      });
                      LogService().userAction('记录心情:${_labels[selectedIdx]}');
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      await _loadData();
                    } catch (e) {
                      LogService().error('Mood', '记录失败: $e');
                    }
                  },
                  child: const Text('记录',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// v4.0 弹层统一口径（v4-ui-token-plan §4）：半透明白卡玻璃化 +
  /// BackdropFilter blur 24 + radiusXl 28 + cardBorder 顶线。
  void _showGlassSheet({
    required BuildContext ctx,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        // 键盘避让集中在外层（detail 无键盘时 viewInsets.bottom=0 不产生留白）
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(LoveGirlTheme.radiusXl)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: context.lgPaper.withValues(alpha: 0.72),
                border: Border(
                    top: BorderSide(color: context.lgCardBorder, width: 1)),
              ),
              child: builder(sheetCtx),
            ),
          ),
        ),
      ),
    );
  }

  /// 弹层顶部抓手条：浅色模式黑 12%（既有视觉），深色模式白 12% 玻璃线
  Widget _buildSheetGrabber({double width = 40}) => Center(
        child: Container(
            width: width,
            height: 4,
            decoration: BoxDecoration(
                color: context.lgIsDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2))),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // v4.0：纯色 bgLight/bgDark 兜底，实际底色由 LovePage 135° 浅灰渐变承担
      //（v4-ui-token-plan §4 LovePage；转场/键盘露出的裸 Scaffold 不破）
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('心情日记'),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.lgTextPrimary,
        ),
        // 本页是生活 tab 的嵌入子页（IndexedStack），无可返回路由；
        // 仅当作为独立页面推入时才显示返回键，否则点了会把根路由 pop 成黑屏
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: AppIcon('back'),
                onPressed: () => Navigator.pop(context))
            : null,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        // 黑底白字主行动（浅色）/米白底深字（深色，lgInk 深色态为近白，图标不能恒白）
        backgroundColor: context.lgInk,
        child: Icon(Icons.add,
            color: context.lgIsDark ? context.lgBg : Colors.white),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off, size: 48, color: context.lgTextMuted),
          SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: context.lgTextSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
              onPressed: _loadData,
              icon: AppIcon('refresh'),
              label: const Text('重试')),
        ]),
      );

  Widget _buildContent() {
    // v4.0：底色=LovePage 135° surfaceGradient（浅灰光感），深色自动回落纯色 bgDark
    return LovePage(
      // ListView 自身滚动+下拉刷新；LovePage 默认上下 padding 收敛为 0
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
            padding: const EdgeInsets.only(top: 8),
            children: [
              _buildMonthSwitcher(),
              const SizedBox(height: 16),
              _buildHeatmap(),
              const SizedBox(height: 24),
              if (_moods.length >= 2) ...[
                _buildTrendChart(),
                const SizedBox(height: 24),
              ],
              _buildRecentList(),
            ]),
      ),
    );
  }

  // ===== Month Switcher =====
  Widget _buildMonthSwitcher() {
    final months = [
      '',
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月'
    ];
    return LovePaper(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
        Text('${_currentMonth.year}年 ${months[_currentMonth.month]}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        IconButton(
            icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
      ]),
    );
  }

  // ===== GitHub-style Heatmap =====
  Widget _buildHeatmap() {
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon
    final weeks = <List<DateTime?>>[];
    List<DateTime?> currentWeek = [];
    // Pad before 1st
    for (int i = 1; i < firstWeekday; i++) {
      currentWeek.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      currentWeek.add(DateTime(_currentMonth.year, _currentMonth.month, d));
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(null);
      }
      weeks.add(currentWeek);
    }

    return LovePaper(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('本月心情',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.lgTextPrimary)),
        SizedBox(height: 4),
        Text('${_moods.length} 天有记录',
            style:
                TextStyle(fontSize: 12, color: context.lgTextMuted)),
        SizedBox(height: 12),
        // Weekday headers
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map((s) => SizedBox(
                    width: 36,
                    child: Center(
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 10, color: context.lgTextMuted))),
                  ))
              .toList(),
        ),
        SizedBox(height: 4),
        ...weeks.map((week) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: week.map((day) {
                  if (day == null) return const SizedBox(width: 36, height: 36);
                  final mood = _getDayMood(day);
                  final today = day.day == DateTime.now().day &&
                      day.month == DateTime.now().month &&
                      day.year == DateTime.now().year;
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: GestureDetector(
                      onTap: () => _showDayDetail(day),
                      child: Builder(builder: (cellCtx) {
                        // W5 弹药库 6.1：一日多心情 → SweepGradient 扇形（star_book 手法）
                        // v4.0 参考图⑧：格色降为粉彩浅底（色相语义不动，v3.42 消同色成果保留），
                        // 数字字色由白转墨；真机验收预留 alpha 0.11-0.22 档重调
                        final dayColors = dayGradientColors(
                            _getDayMoods(day)
                                .map((m) =>
                                    _moodColors[_moodIndexOf(m)]
                                        .withValues(alpha: 0.11))
                                .toList());
                        final multi = dayColors.length >= 2;
                        return Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: multi
                                ? SweepGradient(
                                    colors: dayColors,
                                    startAngle: -math.pi / 2,
                                    endAngle: -math.pi / 2 + 2 * math.pi,
                                  )
                                : null,
                            color: mood.hasMood
                                ? (multi
                                    ? null
                                    : (mood.color ?? context.lgTextMuted)
                                        .withValues(alpha: 0.11))
                                : context.lgPrimarySoft,
                            borderRadius: BorderRadius.circular(8),
                            border: today
                                ? Border.all(
                                    color: context.lgInk, width: 2)
                                : Border.all(color: context.lgCardBorder),
                          ),
                          child: Center(
                              child: Text('${day.day}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: mood.hasMood
                                          ? context.lgInk
                                          : context.lgTextMuted))),
                        );
                      }),
                    ),
                  );
                }).toList(),
              ),
            )),
        // Legend（W5：单心情=心情色浅底，多心情=渐变扇形）
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('无记录',
              style: TextStyle(fontSize: 10, color: context.lgTextMuted)),
          SizedBox(width: 4),
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: context.lgPrimarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.lgCardBorder))),
          SizedBox(width: 8),
          Text('有记录',
              style: TextStyle(fontSize: 10, color: context.lgTextMuted)),
          SizedBox(width: 4),
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: _moodColors.first.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(8))),
          SizedBox(width: 8),
          Text('多心情',
              style: TextStyle(fontSize: 10, color: context.lgTextMuted)),
          SizedBox(width: 4),
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  gradient: SweepGradient(
                      colors: [
                        _moodColors[1].withValues(alpha: 0.11),
                        _moodColors[4].withValues(alpha: 0.11),
                        _moodColors[6].withValues(alpha: 0.11),
                      ],
                      startAngle: -math.pi / 2),
                  borderRadius: BorderRadius.circular(8))),
        ]),
      ]),
    );
  }

  // ===== Trend Chart =====
  Widget _buildTrendChart() {
    final sorted = List<Map<String, dynamic>>.from(_moods);
    sorted.sort(
        (a, b) => (a['date'] ?? '').toString().compareTo(b['date'] ?? ''));
    final spots = <FlSpot>[];
    final labels = <int, String>{};
    for (int i = 0; i < sorted.length; i++) {
      final idx = int.tryParse((sorted[i]['emoji'] ?? '0').toString()) ?? 0;
      spots.add(FlSpot(i.toDouble(), idx.toDouble()));
      if (i % 5 == 0 || i == sorted.length - 1) {
        labels[i] = (sorted[i]['date'] ?? '').toString().substring(5);
      }
    }

    return LovePaper(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('心情趋势',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.lgTextPrimary)),
        SizedBox(height: 4),
        Text('共 ${_moods.length} 天，纵轴越高越开心',
            style:
                TextStyle(fontSize: 12, color: context.lgTextMuted)),
        SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 9,
              gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 3,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: context.lgSeparator, strokeWidth: 0.5)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 3,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt().clamp(0, _labels.length - 1);
                          return Text(_labels[idx],
                              style: TextStyle(
                                  fontSize: 10, color: context.lgTextMuted));
                        })),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          return labels.containsKey(v.toInt())
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(labels[v.toInt()]!,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: context.lgTextMuted)))
                              : const SizedBox.shrink();
                        })),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: context.lgInk,
                  barWidth: 2.5,
                  dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 3,
                          color: context.lgInk,
                          strokeWidth: 0)),
                      belowBarData: BarAreaData(
                          show: true,
                          color: context.lgInk.withValues(alpha: 0.10)),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ===== Recent List =====
  Widget _buildRecentList() {
    if (_moods.isEmpty) return _buildEmpty();
    final recent = List<Map<String, dynamic>>.from(_moods);
    recent.sort((a, b) {
      final c = (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString());
      if (c != 0) return c;
      return _moodIndexOf(a).compareTo(_moodIndexOf(b));
    });
    final display = recent.take(10).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('最近记录',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: context.lgTextMuted)),
      SizedBox(height: 8),
      // W5 弹药库 9.2：相邻记录心情色渐变连线（最后一条无线=时间尽头）
      ...List.generate(display.length, (i) {
        final m = display[i];
        final color = _moodItemColor(m);
        final nextColor = i + 1 < display.length ? _moodItemColor(display[i + 1]) : null;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 26,
                child: Column(
                  children: [
                    const SizedBox(height: 29), // 与卡片图标圆心对齐
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                    if (nextColor != null)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            // v4.0：连线随月历格降为粉彩浅底（withAlpha 28 档，
                            // 色相渐变语义保留；真机验收预留 alpha 36-56 重调）
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withValues(alpha: 0.11),
                                nextColor.withValues(alpha: 0.11),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildMoodItem(m)),
            ],
          ),
        );
      }),
    ]);
  }

  Color _moodItemColor(Map<String, dynamic> m) {
    final idx = _moodIndexOf(m);
    return (idx < _moodColors.length) ? _moodColors[idx] : context.lgInk;
  }

  Widget _buildEmpty() => Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(children: [
            Icon(Icons.mood_outlined,
                size: 48, color: context.lgTextMuted),
            SizedBox(height: 8),
            Text('本月还没有记录',
                style: TextStyle(color: context.lgTextSecondary)),
          ]),
        ),
      );

  Widget _buildMoodItem(Map<String, dynamic> mood) {
    final idx = int.tryParse((mood['emoji'] ?? '0').toString()) ?? 0;
    final icon = (idx >= 0 && idx < _moodIcons.length)
        ? _moodIcons[idx]
        : Icons.sentiment_satisfied_rounded;
    final color = (idx >= 0 && idx < _moodColors.length)
        ? _moodColors[idx]
        : context.lgInk;
    final label = mood['label'] ?? '';
    final note = mood['note'] ?? '';
    final date = mood['date'] ?? '';
    // v4.0 参考图④：疏朗行（图标圆底 + 文字 + 右侧日期），LovePaper 细线卡
    return LovePaper(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: LoveGirlTheme.radius,
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11), shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: color)),
        SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            Spacer(),
            // 右侧日期=计数徽章形态（参考图⑥中性浅底徽章）
            LoveBadge(
              text: date.toString().substring(5),
              style: LoveBadgeStyle.neutral,
            ),
          ]),
          if (note.isNotEmpty) ...[
            SizedBox(height: 4),
            Text(note,
                style: TextStyle(
                    fontSize: 13, color: context.lgTextSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)
          ],
        ])),
      ]),
    );
  }
}

class MoodData {
  final bool hasMood;
  final IconData icon;
  final Color? color;
  final String label;
  final String note;
  final Map<String, dynamic> raw;
  MoodData(
      {required this.hasMood,
      this.icon = Icons.help_outline,
      this.color,
      this.label = '',
      this.note = '',
      this.raw = const {}});
  factory MoodData.empty() => MoodData(hasMood: false);
}

// ===== W5 弹药库纯函数（单测：mood_map_test.dart）=====

/// 弹药库 6.2：按日分组心情记录（date/recordDate 双键兼容）
Map<String, List<Map<String, dynamic>>> groupMoodsByDate(
    List<Map<String, dynamic>> moods) {
  final out = <String, List<Map<String, dynamic>>>{};
  for (final m in moods) {
    final dateRaw = (m['recordDate'] ?? m['date'] ?? '').toString();
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    out.putIfAbsent(date, () => []).add(m);
  }
  return out;
}

/// 弹药库 6.1：一日多心情 → SweepGradient 色表（相邻同色合并，全同色回退单色）
List<Color> dayGradientColors(List<Color> colors) {
  final distinct = <Color>[];
  for (final c in colors) {
    if (distinct.isEmpty || distinct.last != c) distinct.add(c);
  }
  return distinct;
}

int _moodIndexOf(Map<String, dynamic> m) {
  final idx = int.tryParse((m['emoji'] ?? '0').toString()) ?? 0;
  return idx.clamp(0, 9);
}
