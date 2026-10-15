import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import '../../../widgets/app_icon.dart';

/// ===== 课程表 =====
class ScheduleListWidget extends StatefulWidget {
  const ScheduleListWidget({super.key});

  @override
  State<ScheduleListWidget> createState() => _ScheduleListWidgetState();
}

class _ScheduleListWidgetState extends State<ScheduleListWidget> {
  final ApiService _api = ApiService();
  List<dynamic> _courses = [];
  bool _loading = true;
  String? _error;

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
    setState(() => _loading = true);
    try {
      final res = await _api.getCourses(_currentTerm);
      setState(() {
        _courses = res.data['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
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
    int dayOfWeek = 1;
    int startSection = 1;
    int endSection = 2;
    int colorIndex = 0;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    8 - startSection,
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
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        try {
                          final startTime =
                              _sectionStartTimes[startSection - 1];
                          final endTime = _sectionEndTimes[endSection - 1];
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
                                  content: Text('添加失败: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2)),
                            );
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
                      child: const Text(
                        '确定添加',
                        style: TextStyle(
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
    if (result == true) {
      try {
        await _api.deleteCourse(id);
        await _loadCourses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('删除失败: $e'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2)),
          );
        }
        await _loadCourses(); // 恢复原状态
      }
    }
  }

  List<dynamic> _getCoursesForDay(int day) {
    return _courses.where((c) {
      final d = _getDayOfWeek(c);
      return d == day;
    }).toList();
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
    return idx >= 0 ? idx + 1 : 1;
  }

  int _getEndSection(dynamic course) {
    final time = course['endTime']?.toString() ?? '';
    final idx = _sectionEndTimes.indexOf(time);
    return idx >= 0 ? idx + 1 : 2;
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

    // 如果没有时间，根据节次推算
    final startSec = _getStartSection(course);
    final endSec = _getEndSection(course);
    if (startSec - 1 < _sectionStartTimes.length &&
        endSec - 1 < _sectionEndTimes.length) {
      final start = _sectionStartTimes[startSec - 1].substring(0, 5);
      final end = _sectionEndTimes[endSec - 1].substring(0, 5);
      return '$start-$end';
    }

    return '';
  }

  int _getDayOfWeek(dynamic course) {
    final d = course['dayOfWeek'];
    if (d is int) return d;
    return int.tryParse(d?.toString() ?? '1') ?? 1;
  }

  bool _isToday(int dayOfWeek) {
    return DateTime.now().weekday == dayOfWeek;
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LovePaper(
        padding: EdgeInsets.zero,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: context.lgInk),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: context.lgTextMuted.withAlpha(100),
            ),
            SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: context.lgTextMuted),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadCourses,
              icon: AppIcon('refresh'),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadCourses,
          color: context.lgInk,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            children: [
              // ---- 学期标题 ----
              LovePaper(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.lgInk.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: context.lgInk,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '本学期课程表',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: context.lgTextPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.lgInk.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_courses.length}门课',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.lgInk,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---- 星期行（有机圆形标签） ----
              LovePaper(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final today = _isToday(day);
                    return Expanded(
                      child: Column(
                        children: [
                          // 圆形日期标签（v4.0：去有机裁剪，圆块选中=lgInk）
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: today ? context.lgInk : Colors.transparent,
                            ),
                            child: Center(
                              child: Text(
                                _weekDays[i].substring(0, 1),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      today ? FontWeight.w700 : FontWeight.w500,
                                  // lgInk 深色态近白，选中字随底反转
                                  color: today
                                      ? (context.lgIsDark
                                          ? context.lgBg
                                          : Colors.white)
                                      : context.lgTextSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // 日期数字（本周实际日期）
                          Text(
                            '${DateTime.now().add(Duration(days: i - DateTime.now().weekday + 1)).day}',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  today ? context.lgInk : context.lgTextMuted,
                              fontWeight:
                                  today ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),

              // ---- 每日课程 ----
              ...List.generate(7, (dayIndex) {
                final day = dayIndex + 1;
                final dayCourses = _getCoursesForDay(day);
                final today = _isToday(day);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LovePaper(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 日期头部
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: today ? context.lgPrimarySoft : null,
                            border: Border(
                              bottom: BorderSide(
                                color: context.lgSeparator,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: today
                                      ? context.lgInk
                                      : context.lgTextMuted.withAlpha(80),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                _weekDays[dayIndex],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: today
                                      ? context.lgInk
                                      : context.lgTextPrimary,
                                ),
                              ),
                              if (today) ...[
                                SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.lgInk,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '今天',
                                    style: TextStyle(
                                      fontSize: 10,
                                      // lgInk 深色态近白，标签字随底反转
                                      color: context.lgIsDark
                                          ? context.lgBg
                                          : Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              Spacer(),
                              if (dayCourses.isNotEmpty)
                                Text(
                                  '${dayCourses.length}节',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.lgTextMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // 课程卡片
                        if (dayCourses.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 20,
                            ),
                            child: Text(
                              '没有课程安排',
                              style: TextStyle(
                                color: context.lgTextMuted,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          ...dayCourses.map(
                            (course) => _buildCourseCard(course),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // ---- FAB ----
        Positioned(
          right: 16,
          bottom: 20,
          child: _buildFab(),
        ),
      ],
    );
  }

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

    return GestureDetector(
      onLongPress: () => _deleteCourse(id, name),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: LovePaper(
          padding: const EdgeInsets.all(12),
          // v4.0 参考图⑧：课程卡=粉彩浅底（低饱和色 4% 着色）
          color: color.withValues(alpha: 0.04),
          child: Row(
            children: [
              // 节次信息色块（去有机裁剪，圆角同体系）
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '$startSec-$endSec',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      '节',
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              // 课程信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.lgTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 时间显示
                    if (timeStr.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: context.lgTextMuted.withAlpha(160),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.lgTextMuted.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Row(
                      children: [
                        if (teacher.isNotEmpty) ...[
                          Icon(
                            Icons.person_outline_rounded,
                            size: 12,
                            color: context.lgTextMuted.withAlpha(160),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            teacher,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.lgTextMuted.withAlpha(160),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (room.isNotEmpty) ...[
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 12,
                            color: context.lgTextMuted.withAlpha(160),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            room,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.lgTextMuted.withAlpha(160),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 删除（红=删除语义保留：功能性红浅底+红字）
              GestureDetector(
                onTap: () => _deleteCourse(id, name),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.red.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: LoveGirlTheme.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    // v4.0 主行动黑底白字：去有机裁剪/渐变/双层重阴影，回归圆角黑块
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: context.lgInk,
        borderRadius: BorderRadius.circular(18),
        boxShadow: LoveGirlTheme.cardShadowElevated(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showAddDialog,
          borderRadius: BorderRadius.circular(18),
          child: Icon(
            Icons.add,
            color: context.lgIsDark ? context.lgBg : Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}
