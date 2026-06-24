import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/widgets/organic_ui.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

/// ===== 波浪分割线绘制器 =====
class WaveDividerPainter extends CustomPainter {
  final Color color;
  final double amplitude;

  WaveDividerPainter({
    this.color = Colors.white,
    this.amplitude = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final h = size.height / 2;
    path.moveTo(0, h);
    final seg = 6;
    final sw = size.width / seg;
    for (int i = 0; i < seg; i++) {
      final x1 = sw * (i + 0.25);
      final y1 = h + (i.isEven ? -amplitude : amplitude);
      final x2 = sw * (i + 0.75);
      final y2 = h + (i.isEven ? amplitude : -amplitude);
      final x3 = sw * (i + 1);
      path.cubicTo(x1, y1, x2, y2, x3, h);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveDividerPainter old) =>
      old.color != color;
}

/// ===== 有机形状箭头按钮 =====
class OrganicArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const OrganicArrowButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: OrganicClipper(borderRadius: 10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: LoveGirlTheme.primary.withAlpha(15),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Icon(
              icon,
              color: LoveGirlTheme.primary,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== 记账列表 =====
class FinanceListWidget extends StatefulWidget {
  const FinanceListWidget({super.key});

  @override
  State<FinanceListWidget> createState() => _FinanceListWidgetState();
}

class _FinanceListWidgetState extends State<FinanceListWidget> {
  final ApiService _api = ApiService();
  late DateTime _currentMonth;
  List<dynamic> _records = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _loadData();
  }

  String get _monthStr =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getFinanceRecords(_monthStr),
        _api.getFinanceStats(_monthStr),
      ]);
      setState(() {
        _records = results[0].data['data'] ?? [];
        _stats = results[1].data['data'] ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败，下拉重试';
        _loading = false;
      });
    }
  }

  void _prevMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadData();
  }

  void _showAddDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = '支出';
    String category = '餐饮';
    final dateCtrl = TextEditingController(
      text:
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
    );

    final expenseCategories = [
      '餐饮',
      '交通',
      '购物',
      '娱乐',
      '住房',
      '通讯',
      '医疗',
      '教育',
      '其他',
    ];
    final incomeCategories = [
      '工资',
      '兼职',
      '红包',
      '投资',
      '其他',
    ];

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
              color: LoveGirlTheme.cardLight,
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
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.textMuted.withAlpha(60),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '添加账单',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                // 类型切换
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            type = '支出';
                            category = expenseCategories.contains(category)
                                ? category
                                : expenseCategories[0];
                          });
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: type == '支出'
                                ? LoveGirlTheme.pink.withAlpha(25)
                                : LoveGirlTheme.bgLight,
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: type == '支出'
                                  ? LoveGirlTheme.pink.withAlpha(60)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.trending_down_rounded,
                                size: 18,
                                color: type == '支出'
                                    ? LoveGirlTheme.pink
                                    : LoveGirlTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '支出',
                                style: TextStyle(
                                  color: type == '支出'
                                      ? LoveGirlTheme.pink
                                      : LoveGirlTheme.textMuted,
                                  fontWeight: type == '支出'
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            type = '收入';
                            category = incomeCategories.contains(category)
                                ? category
                                : incomeCategories[0];
                          });
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: type == '收入'
                                ? LoveGirlTheme.accent.withAlpha(25)
                                : LoveGirlTheme.bgLight,
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: type == '收入'
                                  ? LoveGirlTheme.accent.withAlpha(60)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                size: 18,
                                color: type == '收入'
                                    ? LoveGirlTheme.accent
                                    : LoveGirlTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '收入',
                                style: TextStyle(
                                  color: type == '收入'
                                      ? LoveGirlTheme.accent
                                      : LoveGirlTheme.textMuted,
                                  fontWeight: type == '收入'
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 金额
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '金额',
                    hintText: '0.00',
                    prefixText: '¥ ',
                    prefixStyle: TextStyle(
                      color: LoveGirlTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: Icon(
                      Icons.monetization_on_rounded,
                      color: LoveGirlTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 分类
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children:
                        (type == '支出' ? expenseCategories : incomeCategories)
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: category == c,
                                  selectedColor: (type == '支出'
                                          ? LoveGirlTheme.pink
                                          : LoveGirlTheme.accent)
                                      .withAlpha(30),
                                  labelStyle: TextStyle(
                                    color: category == c
                                        ? (type == '支出'
                                            ? LoveGirlTheme.pink
                                            : LoveGirlTheme.accent)
                                        : LoveGirlTheme.textSecondary,
                                    fontWeight: category == c
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  side: BorderSide(
                                    color: category == c
                                        ? (type == '支出'
                                                ? LoveGirlTheme.pink
                                                : LoveGirlTheme.accent)
                                            .withAlpha(80)
                                        : LoveGirlTheme.textMuted
                                            .withAlpha(40),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  onSelected: (_) =>
                                      setSheetState(() => category = c),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // 日期
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
                          colorScheme: const ColorScheme.light(
                            primary: LoveGirlTheme.primary,
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
                  decoration: const InputDecoration(
                    labelText: '日期',
                    prefixIcon: Icon(
                      Icons.calendar_today_rounded,
                      color: LoveGirlTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 备注
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: '备注（选填）',
                    hintText: '备注信息...',
                    prefixIcon: Icon(
                      Icons.notes_rounded,
                      color: LoveGirlTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text);
                      if (amount == null || amount <= 0) return;
                      try {
                        // 字段名映射：前端 -> 后端
                        await _api.addFinanceRecord({
                          'type': type == '支出' ? 'expense' : 'income',
                          'category': category,
                          'amount': amount,
                          'recordDate': dateCtrl.text,
                          'description': noteCtrl.text.trim(),
                        });
                        Navigator.pop(ctx);
                        await _loadData();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('添加失败: $e'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LoveGirlTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '确定添加',
                      style: TextStyle(
                        fontSize: 16,
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

  Map<String, List<dynamic>> _groupByDate(List<dynamic> records) {
    final map = <String, List<dynamic>>{};
    for (final r in records) {
      // 后端返回 recordDate，前端兼容 date
      final date = (r['recordDate'] ?? r['date'])?.toString() ?? '未知日期';
      map.putIfAbsent(date, () => []).add(r);
    }
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    final sortedMap = <String, List<dynamic>>{};
    for (final k in sortedKeys) {
      sortedMap[k] = map[k]!;
    }
    return sortedMap;
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
        final dt =
            DateTime(int.parse(parts[0]), m, d);
        return '${m}月${d}日 周${weekdays[dt.weekday - 1]}';
      }
    } catch (_) {}
    return dateStr;
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case '餐饮':
        return Icons.restaurant_rounded;
      case '交通':
        return Icons.directions_car_rounded;
      case '购物':
        return Icons.shopping_bag_rounded;
      case '娱乐':
        return Icons.sports_esports_rounded;
      case '住房':
        return Icons.home_rounded;
      case '通讯':
        return Icons.phone_android_rounded;
      case '医疗':
        return Icons.local_hospital_rounded;
      case '教育':
        return Icons.school_rounded;
      case '工资':
        return Icons.payments_rounded;
      case '兼职':
        return Icons.work_outline_rounded;
      case '红包':
        return Icons.card_giftcard_rounded;
      case '投资':
        return Icons.trending_up_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: OrganicCard(
        organic: true,
        padding: EdgeInsets.zero,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: LoveGirlTheme.primary),
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
              color: LoveGirlTheme.textMuted.withAlpha(100),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: LoveGirlTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final income = (_stats['income'] ?? 0).toDouble();
    final expense = (_stats['expense'] ?? 0).toDouble();
    final balance = income - expense;
    final grouped = _groupByDate(_records);
    final monthNames = [
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
      '十二月',
    ];

    return RefreshIndicator(
      onRefresh: _loadData,
      color: LoveGirlTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          // ---- 月份切换 ----
          OrganicCard(
            organic: true,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OrganicArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _prevMonth,
                ),
                Text(
                  '${_currentMonth.year}年 ${monthNames[_currentMonth.month]}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.5,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                OrganicArrowButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // ---- 概览卡片（绿→粉渐变 + 有机波浪分割） ----
          OrganicCard(
            organic: true,
            padding: EdgeInsets.zero,
            gradient: const [
              LoveGirlTheme.accent,
              LoveGirlTheme.pink,
            ],
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.trending_down_rounded,
                          label: '支出',
                          amount: expense,
                        ),
                      ),
                      // 有机波浪分割
                      SizedBox(
                        width: 40,
                        height: 60,
                        child: CustomPaint(
                          painter: WaveDividerPainter(
                            color: Colors.white.withAlpha(50),
                            amplitude: 5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.trending_up_rounded,
                          label: '收入',
                          amount: income,
                        ),
                      ),
                    ],
                  ),
                ),
                // 底部结余
                ClipPath(
                  clipper: OrganicClipper(borderRadius: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    color: Colors.white.withAlpha(35),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          balance >= 0
                              ? Icons.savings_rounded
                              : Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.white.withAlpha(200),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          balance >= 0 ? '本月结余  ' : '本月超支  ',
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '¥${balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- 账单明细标题 ----
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '账单明细',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ---- 账单列表 ----
          if (_records.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: LoveGirlTheme.textMuted.withAlpha(60),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '本月暂无账单',
                    style: TextStyle(color: LoveGirlTheme.textMuted),
                  ),
                ],
              ),
            )
          else
            ...grouped.entries.map(
              (entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Text(
                      _formatDate(entry.key),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: LoveGirlTheme.textSecondary.withAlpha(180),
                      ),
                    ),
                  ),
                  OrganicCard(
                    organic: true,
                    padding: EdgeInsets.zero,
                    margin: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      children: entry.value
                          .map((r) => _buildRecordItem(
                                r,
                                isLast: r == entry.value.last,
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required double amount,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white.withAlpha(200)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordItem(dynamic r, {bool isLast = true}) {
    final id =
        r['id'] is int ? r['id'] : int.parse(r['id'].toString());
    // 后端返回 'expense'/'income'，前端兼容 '支出'/'收入'
    final typeStr = r['type']?.toString() ?? '';
    final isExpense = typeStr == 'expense' || typeStr == '支出';
    final amountStr = r['amount']?.toString() ?? '0';
    final amount = double.tryParse(amountStr) ?? 0;
    final category = r['category'] ?? '其他';
    // 后端返回 description，前端兼容 note
    final note = (r['description'] ?? r['note'])?.toString() ?? '';
    final icon = _getCategoryIcon(category);

    return Dismissible(
      key: Key('finance_$id'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final result = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('删除账单'),
            content: Text(
              '确定删除这笔${isExpense ? '支出' : '收入'}吗？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  '取消',
                  style: TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  '删除',
                  style: TextStyle(color: LoveGirlTheme.pink),
                ),
              ),
            ],
          ),
        );
        if (result == true) {
          try {
            await _api.deleteFinanceRecord(id);
            await _loadData();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('删除失败: $e'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
              );
            }
            await _loadData(); // 恢复原状态
          }
        }
        return false;
      },
      background: ClipPath(
        clipper: OrganicClipper(borderRadius: 12),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [LoveGirlTheme.pink, LoveGirlTheme.pinkLight],
            ),
          ),
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: LoveGirlTheme.textMuted.withAlpha(15),
                    width: 1,
                  ),
                ),
        ),
        child: Row(
          children: [
            // 分类图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isExpense
                        ? LoveGirlTheme.pink
                        : LoveGirlTheme.accent)
                    .withAlpha(18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isExpense ? LoveGirlTheme.pink : LoveGirlTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            // 分类 & 备注
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.textMuted.withAlpha(160),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 金额
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: (isExpense
                        ? LoveGirlTheme.pink
                        : LoveGirlTheme.accent)
                    .withAlpha(12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${isExpense ? '-' : '+'}¥${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isExpense
                      ? LoveGirlTheme.pink
                      : LoveGirlTheme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
