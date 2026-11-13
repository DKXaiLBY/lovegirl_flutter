import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/rebuild_controls.dart';

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
  final bool createOnOpen;
  final ApiService? api;
  const TodoListWidget({super.key, this.createOnOpen = false, this.api});

  @override
  State<TodoListWidget> createState() => _TodoListWidgetState();
}

enum _TodoPeriod { all, today, week }

class _TodoListWidgetState extends State<TodoListWidget> {
  late final ApiService _api = widget.api ?? ApiService();
  List<dynamic> _todos = [];
  bool _loading = true;
  String? _error;
  int _loadRequest = 0;
  _TodoPeriod _period = _TodoPeriod.all;
  String? _category;
  final _saving = <int>{};

  @override
  void initState() {
    super.initState();
    _loadTodos();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddDialog();
      });
    }
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
    if (!mounted) return;
    final request = ++_loadRequest;
    setState(() => _loading = true);
    try {
      final res = await _api.getTodos();
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _todos = res.data['data'] ?? [];
        if (_category != null &&
            !_todos.any((todo) => _categoryFor(todo) == _category)) {
          _category = null;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _error = '加载失败，下拉重试';
        _loading = false;
      });
    }
  }

  Future<void> _toggleTodo(int id) async {
    if (_saving.contains(id)) return;
    setState(() => _saving.add(id));
    try {
      await _api.toggleTodo(id);
      await _loadTodos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(extractServerMessage(e, fallback: '暂未完成勾选，请重试')),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  Future<bool> _deleteTodo(int id) async {
    if (_saving.contains(id)) return false;
    setState(() => _saving.add(id));
    try {
      await _api.deleteTodo(id);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('删除失败，请重试'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2)),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    String selectedCategory = '日常';
    var adding = false;

    final categories = ['日常', '学习', '其他'];
    final dateFormat =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    dateCtrl.text = dateFormat;

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
                  // 拖拽指示条
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
                            // 深浅两态：色板跟随当前亮度
                            colorScheme: context.lgIsDark
                                ? ColorScheme.dark(primary: context.lgInk)
                                : ColorScheme.light(primary: context.lgInk),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null && ctx.mounted) {
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
                                selectedColor: context.lgPrimarySoft,
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
                                      : context.lgCardBorder,
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
                      onPressed: adding
                          ? null
                          : () async {
                              if (adding || titleCtrl.text.trim().isEmpty) {
                                return;
                              }
                              setSheetState(() => adding = true);
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
                                        content: Text(extractServerMessage(e,
                                            fallback: '添加失败，输入已保留')),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2)),
                                  );
                                }
                              } finally {
                                if (ctx.mounted &&
                                    ModalRoute.of(ctx)?.isCurrent == true) {
                                  setSheetState(() => adding = false);
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
                        adding ? '正在添加' : '确定添加',
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
    return result == true && mounted && await _deleteTodo(id);
  }

  void _forgetTodo(int id) {
    if (!mounted) return;
    setState(() => _todos = _todos.where((todo) => _id(todo) != id).toList());
    _loadTodos();
  }

  int _id(dynamic todo) => int.parse(todo['id'].toString());

  bool _completed(dynamic todo) =>
      todo['completed'] == true || todo['completed'] == 1;

  String _categoryFor(dynamic todo) {
    final key = (todo['category'] ?? 'daily').toString();
    return _categoryReverseMap[key] ?? key;
  }

  String _dateFor(dynamic todo) => (todo['due_date'] ?? todo['date'] ?? '')
      .toString()
      .split(RegExp('[T ]'))
      .first;

  List<dynamic> get _visibleTodos {
    final today = DateUtils.dateOnly(DateTime.now());
    final monday =
        DateTime(today.year, today.month, today.day - today.weekday + 1);
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    return _todos.where((todo) {
      if (_category != null && _categoryFor(todo) != _category) return false;
      if (_period == _TodoPeriod.all) return true;
      final due = DateTime.tryParse(_dateFor(todo));
      if (due == null) return false;
      final day = DateUtils.dateOnly(due);
      return _period == _TodoPeriod.today
          ? DateUtils.isSameDay(day, today)
          : !day.isBefore(monday) && day.isBefore(nextMonday);
    }).toList();
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
    // v4.0 分类色板收敛（v4-ui-token-plan §4）：Stripe 高饱靛蓝系退役，
    // 换 mood 低饱和版色板同源色相；沿用浅色常量（分类色属内容语义色，
    // 深色态不作黑灰反转，与心情 10 色同策略）
    switch (category) {
      case '学习':
        return const Color(0xFF63609E);
      case '工作':
        return const Color(0xFFB58860);
      case '运动':
        return const Color(0xFF4DB6A2);
      case '购物':
        return const Color(0xFF3A689F);
      case '其他':
        return const Color(0xFF9E9EAD);
      default:
        return const Color(0xFF8FAE8B);
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return RebuildPageBackground(child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading && _todos.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: context.lgInk),
      );
    }

    if (_error != null && _todos.isEmpty) {
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

    final visible = _visibleTodos;
    final categories = _todos.map(_categoryFor).toSet();
    final pending = visible.where((todo) => !_completed(todo)).length;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadTodos,
          color: context.lgInk,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RebuildGlass(
                          radius: 22,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Text(
                            '待完成 $pending 件',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          for (final entry in const {
                            _TodoPeriod.all: '全部',
                            _TodoPeriod.today: '今天',
                            _TodoPeriod.week: '本周',
                          }.entries)
                            RebuildChoiceChip(
                              label: Text(entry.value),
                              selected: _period == entry.key,
                              onSelected: (_) =>
                                  setState(() => _period = entry.key),
                            ),
                        ]),
                        if (categories.length > 1)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              for (final category in [null, ...categories])
                                Padding(
                                  padding: const EdgeInsets.only(right: 7),
                                  child: RebuildChoiceChip(
                                    label: Text(category ?? '所有分类'),
                                    selected: _category == category,
                                    onSelected: (_) =>
                                        setState(() => _category = category),
                                  ),
                                ),
                            ]),
                          ),
                        if (_loading) const LinearProgressIndicator(),
                        if (_error != null)
                          ListTile(
                            title: const Text('暂未更新，仍显示上次读取的待办'),
                            trailing: TextButton(
                                onPressed: _loadTodos, child: const Text('重试')),
                          ),
                      ]),
                ),
              ),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 260,
                    child: _todos.isEmpty
                        ? _buildEmptyState()
                        : const Center(child: Text('这个范围没有待办')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (_, index) => _buildTodoItem(visible[index]),
                  ),
                ),
            ],
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
    final id = _id(todo);
    final title = (todo['title'] ?? '').toString();
    final completed = _completed(todo);
    final date = _dateFor(todo);
    final category = _categoryFor(todo);
    final categoryColor = _getCategoryColor(category);
    final categoryIcon = _getCategoryIcon(category);

    return Dismissible(
      key: Key('todo_$id'),
      direction: _saving.contains(id)
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(id, title),
      onDismissed: (_) => _forgetTodo(id),
      // v4.0：删除手势底改功能性红（红=删除语义保留），不再墨色渐变
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: LoveGirlTheme.red,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        ),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
      child: Opacity(
        opacity: completed ? 0.55 : 1.0,
        child: LovePaper(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              // 手绘复选框（勾选色随分类低饱和色相）
              Semantics(
                label: title,
                checked: completed,
                child: IconButton(
                  onPressed:
                      _saving.contains(id) ? null : () => _toggleTodo(id),
                  icon: HandDrawnCheckbox(
                      checked: completed, color: categoryColor),
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
                          Flexible(
                            child: Text(
                              date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.lgTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // v4.0 分类=粉彩浅底徽章（icon+文字，softXxx 同浅底范式）
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
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
              IconButton(
                tooltip: '删除 $title',
                icon: const Icon(Icons.more_horiz, size: 20),
                onPressed: _saving.contains(id)
                    ? null
                    : () async {
                        if (await _confirmDelete(id, title)) _forgetTodo(id);
                      },
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
