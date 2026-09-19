import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/widgets/organic_ui.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import '../../../widgets/app_icon.dart';

/// ===== 手绘风格复选框 =====
class HandDrawnCheckbox extends StatelessWidget {
  final bool checked;
  final Color? color;
  final double size;

  const HandDrawnCheckbox({
    super.key,
    this.checked = false,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
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
      // 手绘填充圆
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

      // 手绘勾号
      final checkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final checkPath = Path();
      checkPath.moveTo(
        center.dx - radius * 0.3,
        center.dy,
      );
      checkPath.lineTo(
        center.dx - radius * 0.08,
        center.dy + radius * 0.35,
      );
      checkPath.lineTo(
        center.dx + radius * 0.4,
        center.dy - radius * 0.3,
      );
      canvas.drawPath(checkPath, checkPaint);
    } else {
      // 未选中：手绘圆圈
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

/// ===== 待办列表 =====
class TodoListWidget extends StatefulWidget {
  const TodoListWidget({super.key});

  @override
  State<TodoListWidget> createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends State<TodoListWidget> {
  final ApiService _api = ApiService();
  List<dynamic> _todos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  // 分类映射：中文 -> 英文
  static const _categoryMap = {
    '日常': 'daily',
    '学习': 'study',
    '工作': 'life',
    '运动': 'custom',
    '购物': 'custom',
    '其他': 'custom',
  };

  // 反向映射：英文 -> 中文
  static const _categoryReverseMap = {
    'daily': '日常',
    'study': '学习',
    'life': '工作',
    'custom': '其他',
  };

  Future<void> _loadTodos() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTodos();
      setState(() {
        _todos = res.data['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败，下拉重试';
        _loading = false;
      });
    }
  }

  Future<void> _toggleTodo(int id) async {
    try {
      await _api.toggleTodo(id);
      await _loadTodos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('操作失败: $e'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2)),
        );
      }
      await _loadTodos(); // 即使失败也刷新，恢复UI状态
    }
  }

  Future<void> _deleteTodo(int id) async {
    try {
      await _api.deleteTodo(id);
      await _loadTodos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('删除失败，请重试'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2)),
        );
      }
      await _loadTodos(); // 恢复原状态
    }
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    String selectedCategory = '日常';

    final categories = ['日常', '学习', '其他'];
    final dateFormat =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    dateCtrl.text = dateFormat;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipPath(
          clipper: TopOrganicClipper(radius: 24),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 24,
            ),
            decoration: BoxDecoration(
              color: context.lgCard,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽指示条
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.lgTextMuted.withAlpha(60),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '添加待办',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.lgTextPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: '待办内容',
                    hintText: '输入待办事项...',
                    prefixIcon: Icon(
                      Icons.task_alt_rounded,
                      color: context.lgInk,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: context.lgInk,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        dateCtrl.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(
                      Icons.calendar_today_rounded,
                      color: context.lgInk,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c),
                              selected: selectedCategory == c,
                              selectedColor:
                                  context.lgInk.withAlpha(30),
                              labelStyle: TextStyle(
                                color: selectedCategory == c
                                    ? context.lgInk
                                    : context.lgTextSecondary,
                                fontWeight: selectedCategory == c
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              side: BorderSide(
                                color: selectedCategory == c
                                    ? context.lgInk.withAlpha(80)
                                    : context.lgTextMuted.withAlpha(40),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onSelected: (_) =>
                                  setSheetState(() => selectedCategory = c),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      try {
                        // 将中文分类转换为英文
                        final categoryEn =
                            _categoryMap[selectedCategory] ?? 'daily';
                        await _api.createTodo({
                          'title': titleCtrl.text.trim(),
                          'dueDate': dateCtrl.text,
                          'category': categoryEn,
                        });
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _loadTodos();
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
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
    );
  }

  Future<bool> _confirmDelete(int id, String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text('删除待办'),
        content: Text('确定删除 "$title" 吗？'),
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
      await _deleteTodo(id);
    }
    return result ?? false;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '学习':
        return Icons.menu_book_rounded;
      case '工作':
        return Icons.work_rounded;
      case '运动':
        return Icons.fitness_center_rounded;
      case '购物':
        return Icons.shopping_bag_rounded;
      case '其他':
        return Icons.push_pin_rounded;
      default:
        return Icons.checklist_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case '学习':
        return const Color(0xFF9C27B0);
      case '工作':
        return const Color(0xFFE67E22);
      case '运动':
        return const Color(0xFF27AE60);
      case '购物':
        return const Color(0xFFFF6B8A);
      case '其他':
        return const Color(0xFF95A5A6);
      default:
        return const Color(0xFF635BFF);
    }
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
              onPressed: _loadTodos,
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
          onRefresh: _loadTodos,
          color: context.lgInk,
          child: _todos.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: 320,
                      child: _buildEmptyState(),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _todos.length,
                  itemBuilder: (ctx, index) => _buildTodoItem(_todos[index]),
                ),
        ),
        // 有机形状 FAB
        Positioned(
          right: 16,
          bottom: 20,
          child: _buildFab(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_rounded,
            size: 64,
            color: context.lgTextMuted.withAlpha(60),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有待办事项',
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

  Widget _buildTodoItem(dynamic todo) {
    final id =
        todo['id'] is int ? todo['id'] : int.parse(todo['id'].toString());
    final title = todo['title'] ?? '';
    final completed = todo['completed'] == true || todo['completed'] == 1;
    final date = todo['due_date'] ?? todo['date'] ?? '';
    final categoryRaw = todo['category'] ?? 'daily';
    // 将英文分类转换为中文显示
    final category = _categoryReverseMap[categoryRaw] ?? categoryRaw;
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);

    return Dismissible(
      key: Key('todo_$id'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(id, title),
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
      child: Opacity(
        opacity: completed ? 0.55 : 1.0,
        child: LovePaper(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // 左边彩色有机竖条
              ClipPath(
                clipper: OrganicClipper(borderRadius: 3),
                child: Container(
                  width: 6,
                  height: 44,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              // 手绘复选框
              GestureDetector(
                onTap: () => _toggleTodo(id),
                child: HandDrawnCheckbox(
                  checked: completed,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
                    if (date.isNotEmpty) ...[
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
                            date,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.lgTextMuted.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 分类标签
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon, size: 14, color: categoryColor),
                    const SizedBox(width: 4),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        color: categoryColor,
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
            onTap: _showAddDialog,
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
