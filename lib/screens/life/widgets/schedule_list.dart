import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import '../../../widgets/rebuild_controls.dart';

/// ===== 课程表 =====
class ScheduleListWidget extends StatefulWidget {
  final ApiService? api;
  const ScheduleListWidget({super.key, this.api});

  @override
  State<ScheduleListWidget> createState() => _ScheduleListWidgetState();
}

class _ScheduleListWidgetState extends State<ScheduleListWidget> {
  late final ApiService _api = widget.api ?? ApiService();
  List<dynamic> _courses = [];
  bool _loading = true;
  String? _error;
  int _request = 0;
  late int _selectedDay = DateTime.now().weekday;
  bool _showWeek = false;
  final _deleting = <int>{};

  static const _weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  // ignore: unused_field
  static const _sectionLabels = [
    '第1节',
    '第2节',
    '第3节',
    '第4节',
    '第5节',
    '第6节',
    '第7节',
    '第8节',
  ];

  // v4.0 课程色板收敛（v4-ui-token-plan §4 生活页分类色板行）：
  // Stripe 高饱靛蓝 10 色退役，换低饱和粉彩版（色相语义保留、饱和度降档，
  // 参考图⑧课程表浅底卡）；新增课程才写新 hex，旧 hex 由 _legacyHex 归一
  static const _defaultColors = [
    Color(0xFF63609E), // 靛蓝→softPurpleText
    Color(0xFFB58860), // 粉红→暖棕（mood 10 色同源）
    Color(0xFF4DB6A2), // 薄荷绿降饱和
    Color(0xFF9E9EAD), // 中性灰
    Color(0xFFB0ACDD), // 紫→softPurpleText 深色档
    Color(0xFF3A689F), // 蓝→softBlueText
    Color(0xFF356B47), // 绿→softGreenText
    Color(0xFFA8431F), // 玫红→softOrangeText
    Color(0xFF5B6EA8), // 靛青→mood 难过同源
    Color(0xFF4DB6A2), // 青绿→薄荷同源
  ];

  static const _colorHex = [
    '#63609E',
    '#B58860',
    '#4DB6A2',
    '#9E9EAD',
    '#B0ACDD',
    '#3A689F',
    '#356B47',
    '#A8431F',
    '#5B6EA8',
    '#4DB6A2',
  ];

  /// 旧高饱 hex → 新低饱和版归一（老课程数据兼容；键=历史 _colorHex 全集）
  static const _legacyHex = {
    '#635BFF': '#63609E',
    '#FF6B8A': '#B58860',
    '#00D4AA': '#4DB6A2',
    '#FF9800': '#A8431F',
    '#9C27B0': '#B0ACDD',
    '#2196F3': '#3A689F',
    '#4CAF50': '#356B47',
    '#E91E63': '#A8431F',
    '#3F51B5': '#5B6EA8',
    '#009688': '#4DB6A2',
  };

  // 节次 → 开始时间映射（中国高校标准作息）
  static const _sectionStartTimes = [
    '08:00:00',
    '08:55:00',
    '10:00:00',
    '10:55:00',
    '14:00:00',
    '14:55:00',
    '16:00:00',
    '16:55:00',
  ];
  static const _sectionEndTimes = [
    '08:45:00',
    '09:40:00',
    '10:45:00',
    '11:40:00',
    '14:45:00',
    '15:40:00',
    '16:45:00',
    '17:40:00',
  ];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  String get _currentTerm {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    if (month >= 2 && month <= 7) {
      return '${year - 1}-$year-2';
    } else {
      return '$year-${year + 1}-1';
    }
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final res = await _api.getCourses(_currentTerm);
      if (!mounted || request != _request) return;
      setState(() {
        _courses = res.data['data'] ?? [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = '加载失败，下拉重试';
        _loading = false;
      });
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    int dayOfWeek = _selectedDay;
    int startSection = 1;
    int endSection = 2;
    int colorIndex = 0;
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // v4.0 弹层玻璃化统一口径（v4-ui-token-plan §4）：
      // 半透明白 72% + BackdropFilter blur 24 + radiusXl 28
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(LoveGirlTheme.radiusXl),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: context.lgCard.withValues(alpha: 0.72),
                border: Border(
                  top: BorderSide(color: context.lgCardBorder, width: 1),
                ),
              ),
              child: ListView(
                shrinkWrap: true,
                primary: false,
                padding: EdgeInsets.zero,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.lgTextMuted.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '添加课程',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.lgTextPrimary,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '课程名称',
                      hintText: '例如：高等数学',
                      prefixIcon: Icon(
                        Icons.book_rounded,
                        color: context.lgInk,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: teacherCtrl,
                    decoration: InputDecoration(
                      labelText: '授课教师（选填）',
                      hintText: '教师姓名',
                      prefixIcon: Icon(
                        Icons.person_rounded,
                        color: context.lgTextMuted,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: roomCtrl,
                    decoration: InputDecoration(
                      labelText: '教室（选填）',
                      hintText: '例如：教3-201',
                      prefixIcon: Icon(
                        Icons.meeting_room_rounded,
                        color: context.lgTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '上课时间',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.lgTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: List.generate(7, (i) {
                        final day = i + 1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              _weekDays[i],
                              style: const TextStyle(fontSize: 13),
                            ),
                            selected: dayOfWeek == day,
                            selectedColor: context.lgPrimarySoft,
                            labelStyle: TextStyle(
                              color: dayOfWeek == day
                                  ? context.lgInk
                                  : context.lgTextSecondary,
                              fontWeight: dayOfWeek == day
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            side: BorderSide(
                              color: dayOfWeek == day
                                  ? context.lgInk.withAlpha(80)
                                  : context.lgCardBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            onSelected: (_) =>
                                setSheetState(() => dayOfWeek = day),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '开始节次',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.lgTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.lgPrimarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: startSection,
                                  isExpanded: true,
                                  items: List.generate(
                                    7,
                                    (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text('第${i + 1}节'),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setSheetState(() {
                                        startSection = v;
                                        if (endSection < v) {
                                          endSection = v;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '结束节次',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.lgTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.lgPrimarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: endSection,
                                  isExpanded: true,
                                  items: List.generate(
                                    _sectionEndTimes.length - startSection + 1,
                                    (i) => DropdownMenuItem(
                                      value: startSection + i,
                                      child: Text('第${startSection + i}节'),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setSheetState(() => endSection = v);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '课程颜色',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.lgTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: List.generate(_defaultColors.length, (i) {
                        final isSelected = colorIndex == i;
                        return GestureDetector(
                          onTap: () => setSheetState(() => colorIndex = i),
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: _defaultColors[i],
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(
                                      // 白卡上白描边不可见：选中态外扩细线随卡底
                                      color:
                                          context.lgCard.withValues(alpha: 0.9),
                                      width: 3,
                                    )
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: _defaultColors[i].withAlpha(100),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                        );
                      }),
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (saving || nameCtrl.text.trim().isEmpty) {
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                final startTime =
                                    _sectionStartTimes[startSection - 1];
                                final endTime =
                                    _sectionEndTimes[endSection - 1];
                                await _api.createCourse({
                                  'courseName': nameCtrl.text.trim(),
                                  'teacher': teacherCtrl.text.trim(),
                                  'classroom': roomCtrl.text.trim(),
                                  'dayOfWeek': dayOfWeek,
                                  'startTime': startTime,
                                  'endTime': endTime,
                                  'weekType': 'every',
                                  'startWeek': 1,
                                  'endWeek': 20,
                                  'color': _colorHex[colorIndex],
                                });
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                await _loadCourses();
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content: Text(extractServerMessage(e,
                                            fallback: '添加失败，输入已保留')),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2)),
                                  );
                                }
                              } finally {
                                if (ctx.mounted &&
                                    ModalRoute.of(ctx)?.isCurrent == true) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.lgInk,
                        foregroundColor:
                            context.lgIsDark ? context.lgBg : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        saving ? '正在添加' : '确定添加',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCourse(int id, String name) async {
    if (_deleting.contains(id)) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('删除课程'),
        content: Text('确定删除 "$name" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              '取消',
              style: TextStyle(color: context.lgTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '删除',
              style: TextStyle(color: context.lgInk),
            ),
          ),
        ],
      ),
    );
    if (result == true && mounted && _deleting.add(id)) {
      setState(() {});
      try {
        await _api.deleteCourse(id);
        await _loadCourses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(extractServerMessage(e, fallback: '删除失败，课程仍然保留')),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2)),
          );
        }
      } finally {
        if (mounted) setState(() => _deleting.remove(id));
      }
    }
  }

  List<dynamic> _getCoursesForDay(int day) {
    return _courses.where((course) => _getDayOfWeek(course) == day).toList()
      ..sort((a, b) =>
          (_startMinute(a) ?? 1440).compareTo(_startMinute(b) ?? 1440));
  }

  int? _startMinute(dynamic course) {
    final time = course['startTime']?.toString() ?? '';
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  Color _getCourseColor(dynamic course) {
    final hex = course['color']?.toString() ?? '#63609E';
    // v4.0：旧高饱 hex 归一到新低饱和版后再解析
    final normalized = _legacyHex[hex] ?? hex;
    // 尝试从 hex 颜色字符串创建 Color
    try {
      final clean = normalized.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    // 回退：尝试作为索引
    final idx = int.tryParse(hex) ?? 0;
    return _defaultColors[idx % _defaultColors.length];
  }

  int _getStartSection(dynamic course) {
    // 服务器返回 startTime，尝试解析时间得到节次
    final time = course['startTime']?.toString() ?? '';
    final idx = _sectionStartTimes.indexOf(time);
    return idx >= 0 ? idx + 1 : 0;
  }

  int _getEndSection(dynamic course) {
    final time = course['endTime']?.toString() ?? '';
    final idx = _sectionEndTimes.indexOf(time);
    return idx >= 0 ? idx + 1 : 0;
  }

  /// 获取课程时间字符串（如 "08:00-08:45"）
  String _getCourseTime(dynamic course) {
    final startTime = course['startTime']?.toString() ?? '';
    final endTime = course['endTime']?.toString() ?? '';

    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      // 格式化时间，去掉秒数
      final start =
          startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
      final end = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;
      return '$start-$end';
    }

    return startTime.isNotEmpty ? startTime : endTime;
  }

  int _getDayOfWeek(dynamic course) {
    final d = course['dayOfWeek'];
    if (d is int) return d;
    return int.tryParse(d?.toString() ?? '1') ?? 1;
  }

  @override
  Widget build(BuildContext context) => RebuildPageBackground(
        child: _loading && _courses.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      );

  Widget _buildBody() {
    final now = DateTime.now();
    final today = now.weekday;
    final monday = DateTime(now.year, now.month, now.day - today + 1);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    final todayCourses = _getCoursesForDay(today);
    final minute = now.hour * 60 + now.minute;
    final next = todayCourses
        .where((course) => (_startMinute(course) ?? -1) >= minute)
        .firstOrNull;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _loadCourses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
          children: [
            if (_error != null)
              ListTile(
                title: Text(_courses.isEmpty ? _error! : '暂未更新，仍显示上次读取的课程'),
                trailing: TextButton(
                    onPressed: _loadCourses, child: const Text('重试')),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_error == null || _courses.isNotEmpty) ...[
              RebuildGlass(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${monday.month}月${monday.day}日 – ${sunday.month}月${sunday.day}日',
                          style: TextStyle(color: context.lgTextSecondary)),
                      const SizedBox(height: 8),
                      Text(
                          todayCourses.isEmpty
                              ? '今天没有课程安排'
                              : '今天课表有 ${todayCourses.length} 门课',
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w700)),
                      if (next != null) ...[
                        const SizedBox(height: 6),
                        Text(
                            '课表下一节 · ${next['courseName'] ?? next['name'] ?? ''} · ${_getCourseTime(next)}',
                            style: TextStyle(color: context.lgTextSecondary)),
                      ],
                    ]),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                children: [
                  for (var i = 0; i < 7; i++)
                    RebuildChoiceChip(
                      label: Text(_weekDays[i]),
                      selected: !_showWeek && _selectedDay == i + 1,
                      onSelected: (_) => setState(() {
                        _selectedDay = i + 1;
                        _showWeek = false;
                      }),
                    ),
                ],
              ),
              Row(children: [
                Expanded(
                    child: Text(
                        _showWeek ? '本周课表' : _weekDays[_selectedDay - 1],
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700))),
                TextButton(
                  style: rebuildTextStyle(context),
                  onPressed: () => setState(() => _showWeek = !_showWeek),
                  child: Text(_showWeek ? '查看单日' : '查看整周'),
                ),
              ]),
              if (_showWeek) ...[
                if (_courses.isEmpty)
                  _emptyDay('这周没有课程安排')
                else
                  for (var day = 1; day <= 7; day++)
                    if (_getCoursesForDay(day).isNotEmpty)
                      _dayCourses(day, heading: true),
              ] else
                _dayCourses(_selectedDay),
            ],
          ],
        ),
      ),
      Positioned(
        right: 16,
        bottom: 20,
        child: RebuildGlassButton(
          label: '添加课程',
          icon: Icons.add,
          showLabel: true,
          selected: true,
          onPressed: _showAddDialog,
        ),
      ),
    ]);
  }

  Widget _dayCourses(int day, {bool heading = false}) {
    final courses = _getCoursesForDay(day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (heading)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 0, 8),
            child: Text(_weekDays[day - 1],
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        if (courses.isEmpty)
          _emptyDay('没有课程安排')
        else
          for (final course in courses) _buildCourseCard(course),
      ]),
    );
  }

  Widget _emptyDay(String message) => RebuildGlass(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Text(message, style: TextStyle(color: context.lgTextSecondary)),
      );

  Widget _buildCourseCard(dynamic course) {
    final name = course['courseName'] ?? course['name'] ?? '';
    final teacher = course['teacher'] ?? '';
    final room = course['classroom'] ?? course['room'] ?? '';
    final color = _getCourseColor(course);
    final startSec = _getStartSection(course);
    final endSec = _getEndSection(course);
    final id =
        course['id'] is int ? course['id'] : int.parse(course['id'].toString());
    final timeStr = _getCourseTime(course);

    final weekType = course['weekType']?.toString();
    final weekStart = course['startWeek'];
    final weekEnd = course['endWeek'];
    final weekLabel = switch (weekType) {
      'odd' => '单周',
      'even' => '双周',
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RebuildGlass(
        radius: 16,
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 6),
          leading: startSec <= 0 || endSec < startSec
              ? null
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withAlpha(42),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    startSec == endSec ? '$startSec 节' : '$startSec–$endSec 节',
                    style: TextStyle(
                      color: context.lgTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              [
                if (timeStr.isNotEmpty) timeStr,
                if (teacher.isNotEmpty) teacher,
                if (room.isNotEmpty) room,
                if (weekLabel.isNotEmpty) weekLabel,
                if (weekStart != null && weekEnd != null)
                  '第 $weekStart–$weekEnd 周',
              ].join(' · '),
              style: TextStyle(color: context.lgTextSecondary)),
          onLongPress:
              _deleting.contains(id) ? null : () => _deleteCourse(id, name),
          trailing: IconButton(
            tooltip: '删除 $name',
            icon: const Icon(Icons.more_horiz),
            onPressed:
                _deleting.contains(id) ? null : () => _deleteCourse(id, name),
          ),
        ),
      ),
    );
  }
}
