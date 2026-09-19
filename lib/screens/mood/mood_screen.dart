import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_icon.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});
  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  final ApiService _api = ApiService();
  Map<String, Map<String, dynamic>> _moodMap = {}; // date -> mood data
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
  static const _moodColors = [
    Color(0xFFFFB347),
    Color(0xFFFF6B8A),
    Color(0xFFFF8FA8),
    Color(0xFF7B8CFF),
    Color(0xFFFF4757),
    Color(0xFF9E9EAD),
    Color(0xFF00BCD4),
    Color(0xFF4CAF50),
    Color(0xFFE040FB),
    Color(0xFFFF9800),
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
      _moodMap = {};
      for (final m in _moods) {
        // 后端返回 recordDate，前端兼容 date
        final dateRaw = (m['recordDate'] ?? m['date'] ?? '').toString();
        final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
        _moodMap[date] = m;
      }
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

  MoodData _getDayMood(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final m = _moodMap[key];
    if (m == null) return MoodData.empty();
    final idx = int.tryParse((m['emoji'] ?? '0').toString()) ?? 0;
    return MoodData(
      hasMood: true,
      icon: (idx >= 0 && idx < _moodIcons.length)
          ? _moodIcons[idx]
          : Icons.sentiment_satisfied_rounded,
      color: (idx >= 0 && idx < _moodColors.length)
          ? _moodColors[idx]
          : LoveGirlTheme.primary,
      label: m['label'] ?? _labels[idx.clamp(0, _labels.length - 1)],
      note: m['note'] ?? '',
      raw: m,
    );
  }

  void _showDayDetail(DateTime day) {
    final mood = _getDayMood(day);
    if (!mood.hasMood) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: mood.color.withAlpha(30), shape: BoxShape.circle),
              child: Icon(mood.icon, size: 40, color: mood.color),
            ),
            const SizedBox(height: 12),
            Text(mood.label,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: mood.color)),
            const SizedBox(height: 4),
            Text(DateFormat('M月d日 EEEE', 'zh_CN').format(day),
                style: const TextStyle(
                    fontSize: 14, color: LoveGirlTheme.textMuted)),
            if (mood.note.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: LoveGirlTheme.bgLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(mood.note,
                    style: const TextStyle(
                        fontSize: 15,
                        color: LoveGirlTheme.textSecondary,
                        height: 1.5)),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    int selectedIdx = 0;
    final noteCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 24),
          decoration: const BoxDecoration(
              color: LoveGirlTheme.cardLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)))),
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
                            ? _moodColors[i].withAlpha(30)
                            : LoveGirlTheme.bgLight,
                        border: Border.all(
                            color: sel
                                ? _moodColors[i]
                                : Colors.black.withAlpha(10),
                            width: sel ? 2 : 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_moodIcons[i], size: 24, color: _moodColors[i]),
                          Text(_labels[i],
                              style: TextStyle(
                                  fontSize: 9,
                                  color: sel
                                      ? _moodColors[i]
                                      : LoveGirlTheme.textMuted)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: '写点什么吧...', prefixIcon: Icon(Icons.edit_note))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
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
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        backgroundColor: LoveGirlTheme.bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('心情日记'),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: LoveGirlTheme.textPrimary,
        ),
        leading: IconButton(
            icon: AppIcon('back'),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: LoveGirlTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
              onPressed: _loadData,
              icon: AppIcon('refresh'),
              label: const Text('重试')),
        ]),
      );

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: LoveGirlTheme.cardShadow()),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
        Text('${_currentMonth.year}年 ${months[_currentMonth.month]}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: LoveGirlTheme.cardShadow()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('本月心情',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textPrimary)),
        const SizedBox(height: 4),
        Text('${_moods.length} 天有记录',
            style:
                const TextStyle(fontSize: 12, color: LoveGirlTheme.textMuted)),
        const SizedBox(height: 12),
        // Weekday headers
        Row(
          children: ['一', '二', '三', '四', '五', '六', '日']
              .map((s) => SizedBox(
                    width: 36,
                    child: Center(
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 10, color: LoveGirlTheme.textMuted))),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
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
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: mood.hasMood
                              ? mood.color.withAlpha(180)
                              : LoveGirlTheme.bgLight,
                          borderRadius: BorderRadius.circular(6),
                          border: today
                              ? Border.all(
                                  color: LoveGirlTheme.primary, width: 2)
                              : Border.all(color: Colors.black.withAlpha(10)),
                        ),
                        child: mood.hasMood
                            ? Center(
                                child: Text('${day.day}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white)))
                            : Center(
                                child: Text('${day.day}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: LoveGirlTheme.textMuted))),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )),
        // Legend
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          const Text('无记录',
              style: TextStyle(fontSize: 10, color: LoveGirlTheme.textMuted)),
          const SizedBox(width: 4),
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: LoveGirlTheme.bgLight,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.black.withAlpha(10)))),
          const SizedBox(width: 8),
          const Text('有记录',
              style: TextStyle(fontSize: 10, color: LoveGirlTheme.textMuted)),
          const SizedBox(width: 4),
          Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                  color: LoveGirlTheme.primary.withAlpha(180),
                  borderRadius: BorderRadius.circular(3))),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: LoveGirlTheme.cardShadow()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('心情趋势',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textPrimary)),
        const SizedBox(height: 4),
        Text('共 ${_moods.length} 天，纵轴越高越开心',
            style:
                const TextStyle(fontSize: 12, color: LoveGirlTheme.textMuted)),
        const SizedBox(height: 16),
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
                      FlLine(color: LoveGirlTheme.separator, strokeWidth: 0.5)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 3,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt().clamp(0, _labels.length - 1);
                          return Text(_labels[idx],
                              style: const TextStyle(
                                  fontSize: 9, color: LoveGirlTheme.textMuted));
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
                                      style: const TextStyle(
                                          fontSize: 8,
                                          color: LoveGirlTheme.textMuted)))
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
                  color: LoveGirlTheme.primary,
                  barWidth: 2.5,
                  dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 3,
                          color: LoveGirlTheme.primary,
                          strokeWidth: 0)),
                  belowBarData: BarAreaData(
                      show: true, color: LoveGirlTheme.primary.withAlpha(25)),
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
    recent.sort(
        (a, b) => (b['date'] ?? '').toString().compareTo(a['date'] ?? ''));
    final display = recent.take(10).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('最近记录',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: LoveGirlTheme.textPrimary)),
      const SizedBox(height: 8),
      ...display.map((m) => _buildMoodItem(m)),
    ]);
  }

  Widget _buildEmpty() => Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(children: [
            const Icon(Icons.mood_outlined,
                size: 48, color: LoveGirlTheme.textMuted),
            const SizedBox(height: 8),
            const Text('本月还没有记录',
                style: TextStyle(color: LoveGirlTheme.textSecondary)),
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
        : LoveGirlTheme.primary;
    final label = mood['label'] ?? '';
    final note = mood['note'] ?? '';
    final date = mood['date'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius)),
      child: Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withAlpha(25), shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: color)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color)),
            const Spacer(),
            Text(date.toString().substring(5),
                style: const TextStyle(
                    fontSize: 12, color: LoveGirlTheme.textMuted)),
          ]),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note,
                style: const TextStyle(
                    fontSize: 13, color: LoveGirlTheme.textSecondary),
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
  final Color color;
  final String label;
  final String note;
  final Map<String, dynamic> raw;
  MoodData(
      {required this.hasMood,
      this.icon = Icons.help_outline,
      this.color = LoveGirlTheme.textMuted,
      this.label = '',
      this.note = '',
      this.raw = const {}});
  factory MoodData.empty() => MoodData(hasMood: false);
}
