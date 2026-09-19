import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/organic_ui.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/screens/tasks/task_form.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  static const _storageKey = 'couple_tasks';
  static const _categories = ['全部', '旅行', '美食', '运动', '学习', '生活'];

  static const _categoryColors = <String, Color>{
    '旅行': Color(0xFF2196F3),
    '美食': Color(0xFFFF9800),
    '运动': Color(0xFF4CAF50),
    '学习': Color(0xFF9C27B0),
    '生活': Color(0xFFE91E63),
  };

  static const _categoryIcons = <String, IconData>{
    '旅行': Icons.flight_rounded,
    '美食': Icons.restaurant_rounded,
    '运动': Icons.fitness_center_rounded,
    '学习': Icons.menu_book_rounded,
    '生活': Icons.favorite_rounded,
  };

  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  late TabController _tabController;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });
    _loadTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------- Persistence ----------

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final list = jsonDecode(jsonStr) as List;
        setState(() {
          _tasks = list.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (_) {
      // ignore
    }
    setState(() => _loading = false);
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_tasks));
  }

  // ---------- CRUD ----------

  Future<void> _toggleTask(int index) async {
    final task = _tasks[index];
    final now = DateTime.now().toIso8601String();
    setState(() {
      task['completed'] = !(task['completed'] == true);
      task['completedAt'] = task['completed'] == true ? now : null;
    });
    await _saveTasks();
  }

  void _deleteTask(int index) {
    final name = _tasks[index]['name'] ?? '';
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        ),
        title: const Text('删除愿望'),
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
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() => _tasks.removeAt(index));
        _saveTasks();
      }
    });
  }

  Future<void> _addTask() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const TaskForm()),
    );
    if (result != null) {
      setState(() {
        _tasks.insert(0, {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'name': result['name'],
          'category': result['category'],
          'notes': result['notes'],
          'completed': false,
          'createdAt': DateTime.now().toIso8601String(),
          'completedAt': null,
        });
      });
      _saveTasks();
    }
  }

  Future<void> _editTask(int index) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => TaskForm(task: _tasks[index])),
    );
    if (result != null) {
      setState(() {
        _tasks[index] = {
          ..._tasks[index],
          'name': result['name'],
          'category': result['category'],
          'notes': result['notes'],
        };
      });
      _saveTasks();
    }
  }

  // ---------- Filters ----------

  List<Map<String, dynamic>> get _filteredTasks {
    if (_currentTab == 0) return _tasks;
    final cat = _categories[_currentTab];
    return _tasks.where((t) => t['category'] == cat).toList();
  }

  int get _completedCount => _tasks.where((t) => t['completed'] == true).length;

  // ---------- Helpers ----------

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  Color _catColor(String? cat) => _categoryColors[cat] ?? context.lgInk;

  IconData _catIcon(String? cat) =>
      _categoryIcons[cat] ?? Icons.checklist_rounded;

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        title: const Text('愿望清单'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: context.lgInk,
          unselectedLabelColor: context.lgTextMuted,
          indicatorColor: context.lgInk,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: context.lgInk),
            )
          : _buildBody(),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Stats card
        _buildStatsCard(),
        // Task list
        Expanded(
          child: _filteredTasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: _filteredTasks.length,
                  itemBuilder: (ctx, i) => _buildTaskItem(_filteredTasks[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final total = _tasks.length;
    final completed = _completedCount;
    final progress = total > 0 ? completed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LovePaper(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: context.lgSeparator,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.lgInk,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    total > 0 ? '${(progress * 100).round()}%' : '0%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.lgInk,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 20),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '完成进度',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.lgTextMuted,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '已完成 $completed',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.lgInk,
                          ),
                        ),
                        TextSpan(
                          text: ' / $total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: context.lgTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Decorative hearts
            Icon(
              Icons.favorite_rounded,
              color: context.lgInk.withAlpha(30),
              size: 36,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 64,
            color: context.lgTextMuted.withAlpha(60),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有愿望',
            style: TextStyle(
              color: context.lgTextMuted,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮添加',
            style: TextStyle(
              color: context.lgTextMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final idx = _tasks.indexOf(task);
    final name = task['name'] ?? '';
    final category = task['category'] ?? '生活';
    final completed = task['completed'] == true;
    final createdAt = task['createdAt'] as String?;
    final completedAt = task['completedAt'] as String?;
    final notes = task['notes'] as String? ?? '';
    final color = _catColor(category);

    return Dismissible(
      key: Key('wish_${task['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _deleteTask(idx);
        return false; // we handle deletion manually
      },
      background: ClipPath(
        clipper: OrganicClipper(borderRadius: 16),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.lgInk, LoveGirlTheme.pinkLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: context.lgInk.withAlpha(40),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () => _editTask(idx),
        child: Opacity(
          opacity: completed ? 0.55 : 1.0,
          child: LovePaper(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                // Hand-drawn checkbox
                GestureDetector(
                  onTap: () => _toggleTask(idx),
                  child: _HandDrawnCheckbox(
                    checked: completed,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: completed
                              ? context.lgTextMuted
                              : context.lgTextPrimary,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.lgTextMuted.withAlpha(150),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: context.lgTextMuted.withAlpha(120),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(completed ? completedAt : createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.lgTextMuted.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Category chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_catIcon(category), size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFab() {
    return ClipPath(
      clipper: OrganicClipper(borderRadius: 18),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [context.lgInk, LoveGirlTheme.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: context.lgInk.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: context.lgInk.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _addTask,
            borderRadius: BorderRadius.circular(18),
            child: const Center(
              child: Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hand-drawn style checkbox (self-contained copy from todo_list)
class _HandDrawnCheckbox extends StatelessWidget {
  final bool checked;
  final Color? color;
  static const double _size = 24.0;

  const _HandDrawnCheckbox({
    this.checked = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        size: const Size(_size, _size),
        painter: _HandDrawnCheckboxPainter(
          checked: checked,
          color: color ?? context.lgInk,
        ),
      ),
    );
  }
}

class _HandDrawnCheckboxPainter extends CustomPainter {
  final bool checked;
  final Color color;

  _HandDrawnCheckboxPainter({required this.checked, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;
    final rand = Random(checked ? 42 : 7);

    if (checked) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final fillPath = Path();
      for (int i = 0; i < 12; i++) {
        final a = (2 * pi * i) / 12;
        final j = 1.0 + (rand.nextDouble() - 0.5) * 0.1;
        final x = center.dx + radius * j * cos(a);
        final y = center.dy + radius * j * sin(a);
        if (i == 0) {
          fillPath.moveTo(x, y);
        } else {
          fillPath.lineTo(x, y);
        }
      }
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);

      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final checkPath = Path();
      checkPath.moveTo(center.dx - radius * 0.3, center.dy);
      checkPath.lineTo(center.dx - radius * 0.08, center.dy + radius * 0.35);
      checkPath.lineTo(center.dx + radius * 0.4, center.dy - radius * 0.3);
      canvas.drawPath(checkPath, checkPaint);
    } else {
      final borderPaint = Paint()
        ..color = color.withAlpha(100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final borderPath = Path();
      for (int i = 0; i <= 10; i++) {
        final a = (2 * pi * i) / 10;
        final j = 1.0 + (rand.nextDouble() - 0.5) * 0.08;
        final x = center.dx + radius * j * cos(a);
        final y = center.dy + radius * j * sin(a);
        if (i == 0) {
          borderPath.moveTo(x, y);
        } else {
          borderPath.lineTo(x, y);
        }
      }
      borderPath.close();
      canvas.drawPath(borderPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HandDrawnCheckboxPainter old) =>
      old.checked != checked;
}
