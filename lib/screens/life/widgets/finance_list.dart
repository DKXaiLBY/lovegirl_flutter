import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import '../../../widgets/rebuild_controls.dart';

class FinanceListWidget extends StatefulWidget {
  final bool createOnOpen;
  final ApiService? api;
  const FinanceListWidget({super.key, this.createOnOpen = false, this.api});

  @override
  State<FinanceListWidget> createState() => _FinanceListWidgetState();
}

class _FinanceListWidgetState extends State<FinanceListWidget> {
  late final ApiService _api = widget.api ?? ApiService();
  late DateTime _currentMonth;
  List<dynamic> _records = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;
  String? _sourceFilter;
  String? _loadedMonth;
  int _request = 0;
  int _trendRequest = 0;
  final _deleting = <int>{};

  // 趋势图数据
  List<Map<String, dynamic>> _trendData = [];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddDialog();
      });
    }
    _loadData();
    _loadTrendData();
  }

  String get _monthStr =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    if (!mounted) return;
    final request = ++_request;
    final month = _monthStr;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getFinanceRecords(month),
        _api.getFinanceStats(month),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _records = results[0].data['data'] ?? [];
        _stats = results[1].data['data'] ?? {};
        _loadedMonth = month;
        if (!_hasSources) _sourceFilter = null;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = extractServerMessage(e, fallback: '账单加载失败，可以重试'));
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  bool get _hasSources => _records.any((record) => _isTravel(record));

  bool _isTravel(Map record) =>
      record['source'] == 'travel' ||
      record['sourceModule'] == 'travel' ||
      record['source_module'] == 'travel' ||
      record['category'] == 'travel';

  bool _isExpense(Map record) =>
      record['type'] == 'expense' || record['type'] == '支出';

  String _dateOf(Map record) => (record['recordDate'] ?? record['date'] ?? '')
      .toString()
      .split(RegExp('[T ]'))
      .first;

  double? _amountOf(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '');
    return amount?.isFinite == true ? amount : null;
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadData();
  }

  Future<void> _loadTrendData() async {
    final request = ++_trendRequest;
    final now = DateTime.now();
    final trend = await Future.wait(List.generate(6, (i) async {
      final month = DateTime(now.year, now.month - 5 + i);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      try {
        final response = await _api.getFinanceStats(key);
        final data = response.data['data'] as Map;
        final income = _amountOf(data['totalIncome'] ?? data['income']);
        final expense = _amountOf(data['totalExpense'] ?? data['expense']);
        if (income == null || expense == null) return null;
        return <String, dynamic>{
          'month': month.month,
          'income': income,
          'expense': expense
        };
      } catch (_) {
        return null;
      }
    }));
    if (!mounted || request != _trendRequest) return;
    setState(() => _trendData = trend.any((point) => point == null)
        ? []
        : trend.whereType<Map<String, dynamic>>().toList());
  }

  void _showAddDialog([Map? record]) {
    final amountCtrl = TextEditingController(
        text: _amountOf(record?['amount']) == null
            ? null
            : record!['amount'].toString());
    final noteCtrl = TextEditingController(
        text: (record?['description'] ?? record?['note'])?.toString());
    String type = record == null || _isExpense(record) ? '支出' : '收入';
    String category = record?['category']?.toString() ?? '餐饮';
    final now = DateTime.now();
    final dateCtrl = TextEditingController(
      text: record == null
          ? now.toIso8601String().substring(0, 10)
          : _dateOf(record),
    );
    var saving = false;
    String? error;

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
                // v4.1：72%→58%，磨砂透底感更接近参考图（底层渐变可被 blur 出来）
                color: context.lgCard.withValues(alpha: 0.58),
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
                  const SizedBox(height: 20),
                  Text(
                    record == null ? '添加账单' : '编辑账单',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.lgTextPrimary,
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              // v4.0：支出选中=primarySoft 中性浅底（未选中同底，靠描边区分）
                              color: context.lgPrimarySoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: type == '支出'
                                    ? context.lgInk.withAlpha(60)
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
                                      ? context.lgInk
                                      : context.lgTextMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '支出',
                                  style: TextStyle(
                                    color: type == '支出'
                                        ? context.lgInk
                                        : context.lgTextMuted,
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
                      SizedBox(width: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              // v4.0：收入选中浅底走 softOrange 语义（蜜桃浅底徽章族），
                              // 未选中与支出侧一致=primarySoft 中性浅底
                              color: type == '收入'
                                  ? context.lgSoftOrangeBg
                                  : context.lgPrimarySoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: type == '收入'
                                    ? context.lgSoftOrangeText
                                        .withValues(alpha: 0.35)
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
                                      ? context.lgSoftOrangeText
                                      : context.lgTextMuted,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '收入',
                                  style: TextStyle(
                                    color: type == '收入'
                                        ? context.lgSoftOrangeText
                                        : context.lgTextMuted,
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
                  SizedBox(height: 14),
                  // 金额
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '金额',
                      hintText: '0.00',
                      prefixText: '¥ ',
                      prefixStyle: TextStyle(
                        color: context.lgTextPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: Icon(
                        Icons.monetization_on_rounded,
                        color: context.lgInk,
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
                                        ? context.lgPrimarySoft
                                        : context.lgSoftOrangeBg),
                                    labelStyle: TextStyle(
                                      color: category == c
                                          ? (type == '支出'
                                              ? context.lgInk
                                              : context.lgSoftOrangeText)
                                          : context.lgTextSecondary,
                                      fontWeight: category == c
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                    side: BorderSide(
                                      color: category == c
                                          ? (type == '支出'
                                                  ? context.lgInk
                                                  : context.lgSoftOrangeText)
                                              .withAlpha(80)
                                          : context.lgCardBorder,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    onSelected: (_) =>
                                        setSheetState(() => category = c),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  SizedBox(height: 12),
                  // 日期
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(dateCtrl.text) ?? now,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                        // 深浅两态：色板跟随当前亮度
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
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
                  SizedBox(height: 12),
                  // 备注
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: '备注（选填）',
                      hintText: '备注信息...',
                      prefixIcon: Icon(
                        Icons.notes_rounded,
                        color: context.lgTextMuted,
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: rebuildFilledStyle(ctx),
                    onPressed: saving
                        ? null
                        : () async {
                            if (saving) return;
                            final raw = amountCtrl.text.trim();
                            final amount = _amountOf(raw);
                            final hidden = record != null &&
                                _amountOf(record['amount']) == null;
                            if ((!hidden || raw.isNotEmpty) &&
                                (amount == null || amount <= 0)) {
                              setSheetState(() => error = '请填写有效的正数金额');
                              return;
                            }
                            if (DateTime.tryParse(dateCtrl.text) == null) {
                              setSheetState(() => error = '请选择账单日期');
                              return;
                            }
                            setSheetState(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              final data = {
                                'type': type == '支出' ? 'expense' : 'income',
                                'category': category,
                                if (amount != null) 'amount': amount,
                                'recordDate': dateCtrl.text,
                                'description': noteCtrl.text.trim(),
                              };
                              if (record == null) {
                                await _api.addFinanceRecord(data);
                              } else {
                                await _api.put('/api/finance/${record['id']}',
                                    data: data);
                              }
                              if (!mounted || !ctx.mounted) return;
                              final date = DateTime.parse(dateCtrl.text);
                              setState(() => _currentMonth =
                                  DateTime(date.year, date.month));
                              Navigator.pop(ctx);
                              await _loadData();
                              if (mounted) _loadTrendData();
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheetState(() {
                                  saving = false;
                                  error = extractServerMessage(e,
                                      fallback: '保存失败，输入已保留');
                                });
                              }
                            }
                          },
                    child: Text(saving ? '正在保存' : '保存账单'),
                  ),
                ],
              ),
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
      final day = _dateOf(r);
      final date = day.isEmpty ? '未知日期' : day;
      map.putIfAbsent(date, () => []).add(r);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
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
        final dt = DateTime(int.parse(parts[0]), m, d);
        return '$m月$d日 周${weekdays[dt.weekday - 1]}';
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
  Widget build(BuildContext context) =>
      RebuildPageBackground(child: _buildBody());

  Widget _buildBody() {
    final hasMonth = _loadedMonth == _monthStr;
    final filtered = hasMonth
        ? _records
            .where((record) =>
                _sourceFilter == null ||
                (_sourceFilter == 'travel') == _isTravel(record))
            .toList()
        : <dynamic>[];
    final grouped = _groupByDate(filtered);

    double? total({required bool expense}) {
      if (!hasMonth) return null;
      if (_sourceFilter == null) {
        return _amountOf(expense
            ? _stats['totalExpense'] ?? _stats['expense']
            : _stats['totalIncome'] ?? _stats['income']);
      }
      double sum = 0;
      for (final record in filtered.where((r) => _isExpense(r) == expense)) {
        final amount = _amountOf(record['amount']);
        if (amount == null) return null;
        sum += amount;
      }
      return sum;
    }

    final income = total(expense: false);
    final expense = total(expense: true);
    final balance = income != null && expense != null ? income - expense : null;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
        children: [
          Row(children: [
            RebuildGlassButton(
                label: '上个月', icon: Icons.chevron_left, onPressed: _prevMonth),
            Expanded(
                child: Text('${_currentMonth.year}年${_currentMonth.month}月',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge)),
            RebuildGlassButton(
                label: '下个月', icon: Icons.chevron_right, onPressed: _nextMonth),
          ]),
          const SizedBox(height: 12),
          RebuildGlass(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: _buildStatItem(label: '支出', amount: expense)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildStatItem(label: '收入', amount: income)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _buildStatItem(
                            label: '本月结余', amount: balance, compact: true)),
                    RebuildGlassButton(
                        label: '记一笔',
                        icon: Icons.add,
                        showLabel: true,
                        selected: true,
                        onPressed: _showAddDialog),
                  ]),
                ]),
          ),
          if (hasMonth && _hasSources)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, children: [
                _buildSourceChip(null, '全部'),
                _buildSourceChip('', '日常记账'),
                _buildSourceChip('travel', '旅行花费'),
              ]),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            ListTile(
              title: Text(hasMonth ? '暂未更新，仍显示上次读取的账单' : _error!),
              trailing:
                  TextButton(onPressed: _loadData, child: const Text('重试')),
            ),
          if (hasMonth) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('账单明细',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            ),
            if (filtered.isEmpty)
              const RebuildGlass(
                radius: 16,
                padding: EdgeInsets.all(16),
                child: Text('本月暂无账单'),
              ),
            for (final entry in grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(_formatDate(entry.key),
                    style: TextStyle(color: context.lgTextSecondary)),
              ),
              RebuildGlass(
                radius: 18,
                child: Column(children: [
                  for (final (index, row) in entry.value.indexed) ...[
                    if (index > 0)
                      const Divider(height: 1, indent: 44, endIndent: 12),
                    _buildRecordItem(row),
                  ],
                ]),
              ),
              const SizedBox(height: 10),
            ],
          ],
          // ---- 月度趋势图 ----
          if (_trendData.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: context.lgInk.withAlpha(100),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '月度趋势',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.lgTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            LovePaper(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1000,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: context.lgTextMuted.withAlpha(20),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${(value / 1000).toStringAsFixed(0)}k',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.lgTextMuted.withAlpha(150),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < _trendData.length) {
                                  return Text(
                                    '${_trendData[idx]['month']}月',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: context.lgTextMuted.withAlpha(150),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          // 收入线（v4.0：lgPeachText 深色态自动切 peachTextDark）
                          LineChartBarData(
                            spots: List.generate(_trendData.length, (i) {
                              return FlSpot(
                                  i.toDouble(), _trendData[i]['income']);
                            }),
                            isCurved: true,
                            color: context.lgPeachText,
                            barWidth: 2,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) {
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: context.lgPeachText,
                                  strokeWidth: 0,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: context.lgPeachText.withAlpha(20),
                            ),
                          ),
                          // 支出线
                          LineChartBarData(
                            spots: List.generate(_trendData.length, (i) {
                              return FlSpot(
                                  i.toDouble(), _trendData[i]['expense']);
                            }),
                            isCurved: true,
                            color: context.lgInk,
                            barWidth: 2,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) {
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: context.lgInk,
                                  strokeWidth: 0,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: context.lgInk.withAlpha(20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 图例
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: context.lgPeachText,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '收入',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.lgTextMuted,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: context.lgInk,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '支出',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.lgTextMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ---- 账单明细标题 ----
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: context.lgInk.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '账单明细',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.lgTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
          {required String label,
          required double? amount,
          bool compact = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: context.lgTextSecondary)),
        Text(amount == null ? '—' : '¥${amount.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: compact ? 17 : 23, fontWeight: FontWeight.w700)),
      ]);

  Widget _buildSourceChip(String? value, String label) => RebuildChoiceChip(
        label: Text(label),
        selected: _sourceFilter == value,
        onSelected: (_) => setState(() => _sourceFilter = value),
      );

  Future<void> _deleteRecord(Map record) async {
    final id = int.parse(record['id'].toString());
    if (_deleting.contains(id)) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('删除账单'),
        content: const Text('确定删除这笔账单吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (accepted != true || !mounted || !_deleting.add(id)) return;
    setState(() {});
    try {
      await _api.deleteFinanceRecord(id);
      if (!mounted) return;
      await _loadData();
      if (mounted) _loadTrendData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractServerMessage(e, fallback: '删除失败，账单仍然保留')),
        ));
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(id));
    }
  }

  Widget _buildRecordItem(Map record) {
    final id = int.parse(record['id'].toString());
    final amount = _amountOf(record['amount']);
    final category = record['category'] == 'travel'
        ? '旅行花费'
        : record['category']?.toString() ?? '其他';
    final note = (record['description'] ?? record['note'])?.toString() ?? '';
    final disabled = _deleting.contains(id);
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 12, right: 4),
      leading: Icon(_getCategoryIcon(category), color: context.lgInk),
      title:
          Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
          [
            amount == null
                ? '金额不可见'
                : '${_isExpense(record) ? '−' : '+'}¥${amount.toStringAsFixed(2)}',
            if (_isTravel(record) && category != '旅行花费') '旅行花费',
            if (note.isNotEmpty) note,
          ].join(' · '),
          style: TextStyle(color: context.lgTextSecondary)),
      onTap: disabled ? null : () => _showAddDialog(record),
      trailing: PopupMenuButton<String>(
        tooltip: '账单操作',
        enabled: !disabled,
        onSelected: (action) {
          if (action == 'edit') {
            _showAddDialog(record);
          } else {
            _deleteRecord(record);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑账单')),
          PopupMenuItem(value: 'delete', child: Text('删除账单')),
        ],
      ),
    );
  }
}
