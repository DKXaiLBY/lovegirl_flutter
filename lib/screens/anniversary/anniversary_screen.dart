import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';

/// 纪念日管理页面
class AnniversaryScreen extends StatefulWidget {
  const AnniversaryScreen({super.key});

  @override
  State<AnniversaryScreen> createState() => _AnniversaryScreenState();
}

class _AnniversaryScreenState extends State<AnniversaryScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _anniversaries = [];
  Map<String, dynamic>? _nextAnniversary;
  int _nextDays = 0;
  bool _loading = true;
  String? _error;

  static const _typeConfig = {
    'love':    {'icon': Icons.favorite_rounded,      'color': Color(0xFFFF6B8A), 'label': '恋爱纪念'},
    'birthday':{'icon': Icons.cake_rounded,           'color': Color(0xFFFFB347), 'label': '生日'},
    'first':   {'icon': Icons.star_rounded,           'color': Color(0xFFE040FB), 'label': '第一次'},
    'custom':  {'icon': Icons.auto_awesome_rounded,   'color': Color(0xFF7B8CFF), 'label': '自定义'},
  };

  static const _typeOptions = ['love', 'birthday', 'first', 'custom'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getAnniversaries();
      final data = res.data?['data'];
      List raw = data is List ? data : (data is Map ? (data['list'] ?? []) : []);
      _anniversaries = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      _anniversaries.sort((a, b) {
        final da = _nextOccurrence(a);
        final db = _nextOccurrence(b);
        return da.compareTo(db);
      });
      _calcNext();
      LogService().info('Anniversary', '加载${_anniversaries.length}个纪念日');
    } catch (e) {
      setState(() => _error = '加载失败');
      LogService().error('Anniversary', '加载失败: $e');
    }
    setState(() => _loading = false);
  }

  /// 计算下一个纪念日
  void _calcNext() {
    if (_anniversaries.isEmpty) {
      _nextAnniversary = null;
      _nextDays = 0;
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<String, dynamic>? closest;
    int minDiff = 99999;

    for (final item in _anniversaries) {
      final date = _nextOccurrence(item);
      final diff = date.difference(today).inDays;
      if (diff >= 0 && diff < minDiff) {
        minDiff = diff;
        closest = item;
      }
    }

    _nextAnniversary = closest ?? _anniversaries.first;
    _nextDays = minDiff == 99999 ? 0 : minDiff;
  }

  /// 获取下一个发生日期（今年或明年）
  DateTime _nextOccurrence(Map<String, dynamic> item) {
    final dateStr = (item['date'] ?? '').toString();
    if (dateStr.isEmpty) return DateTime(2099);
    final parts = dateStr.split('-');
    if (parts.length < 2) return DateTime(2099);

    final month = int.tryParse(parts.length >= 2 ? parts[1] : '1') ?? 1;
    final day = int.tryParse(parts.length >= 3 ? parts[2] : '1') ?? 1;

    final now = DateTime.now();
    DateTime next = DateTime(now.year, month, day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, month, day);
    }
    return next;
  }

  /// 计算距今天数
  int _daysUntil(String dateStr) {
    if (dateStr.isEmpty) return 99999;
    final parts = dateStr.split('-');
    if (parts.length < 2) return 99999;
    final month = int.tryParse(parts.length >= 2 ? parts[1] : '1') ?? 1;
    final day = int.tryParse(parts.length >= 3 ? parts[2] : '1') ?? 1;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime next = DateTime(now.year, month, day);
    if (next.isBefore(today)) {
      next = DateTime(now.year + 1, month, day);
    }
    return next.difference(today).inDays;
  }

  void _showAddEditSheet({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    String selectedType = existing?['type'] ?? 'love';

    // 解析日期
    String dateStr = existing?['date'] ?? '';
    DateTime? initDate;
    if (dateStr.isNotEmpty) {
      initDate = DateTime.tryParse(dateStr);
    } else {
      initDate = DateTime.now();
    }
    DateTime selectedDate = initDate ?? DateTime.now();
    bool isLunar = existing?['is_lunar'] == true || existing?['is_lunar'] == 1;
    int repeatType = existing?['repeat_type'] ?? 0; // 0=每年, 1=不重复

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20, right: 20, top: 24,
          ),
          decoration: const BoxDecoration(
            color: LoveGirlTheme.cardLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.textMuted.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEdit ? '编辑纪念日' : '添加纪念日',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: LoveGirlTheme.textPrimary),
                ),
                const SizedBox(height: 20),

                // 标题
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: '纪念日名称',
                    hintText: '例如：恋爱周年、她生日...',
                    prefixIcon: const Icon(Icons.edit_note, color: LoveGirlTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),

                // 描述
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: '备注（可选）',
                    hintText: '记录一点小心思...',
                    prefixIcon: const Icon(Icons.description_outlined, color: LoveGirlTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),

                // 类型选择
                const Text('类型', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LoveGirlTheme.textSecondary)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _typeOptions.map((type) {
                    final config = _typeConfig[type]!;
                    final selected = selectedType == type;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? config['color'] as Color : (config['color'] as Color).withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: selected ? null : Border.all(color: (config['color'] as Color).withAlpha(60)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(config['icon'] as IconData, size: 16, color: selected ? Colors.white : config['color'] as Color),
                            const SizedBox(width: 6),
                            Text(
                              config['label'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: selected ? Colors.white : config['color'] as Color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 日期选择
                const Text('日期', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LoveGirlTheme.textSecondary)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2099),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.bgLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: LoveGirlTheme.separator),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: LoveGirlTheme.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: LoveGirlTheme.textPrimary),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: LoveGirlTheme.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 选项行
                Row(
                  children: [
                    // 农历
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isLunar,
                          onChanged: (v) => setSheetState(() => isLunar = v ?? false),
                          activeColor: LoveGirlTheme.primary,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('农历', style: TextStyle(fontSize: 14, color: LoveGirlTheme.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    // 重复
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: repeatType == 0,
                          onChanged: (v) => setSheetState(() => repeatType = (v ?? true) ? 0 : 1),
                          activeColor: LoveGirlTheme.primary,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        const Text('每年重复', style: TextStyle(fontSize: 14, color: LoveGirlTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('请输入纪念日名称'), behavior: SnackBarBehavior.floating),
                        );
                        return;
                      }
                      final body = {
                        'title': title,
                        'description': descCtrl.text.trim(),
                        'type': selectedType,
                        'date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        'is_lunar': isLunar,
                        'repeat_type': repeatType,
                      };
                      try {
                        if (isEdit) {
                          await _api.updateAnniversary(existing!['id'], body);
                          LogService().userAction('纪念日:编辑 "$title"');
                        } else {
                          await _api.createAnniversary(body);
                          LogService().userAction('纪念日:添加 "$title"');
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadData();
                      } catch (e) {
                        LogService().error('Anniversary', '保存失败: $e');
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('保存失败，请检查网络'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LoveGirlTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      isEdit ? '保存修改' : '添加纪念日',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  void _deleteAnniversary(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除纪念日'),
        content: Text('确定删除「${item['title'] ?? ''}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteAnniversary(item['id']);
                LogService().userAction('纪念日:删除 "${item['title']}"');
                await _loadData();
              } catch (e) {
                LogService().error('Anniversary', '删除失败: $e');
              }
            },
            child: const Text('删除', style: TextStyle(color: LoveGirlTheme.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('纪念日'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddEditSheet(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: _buildError())],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (_nextAnniversary != null) ...[
                        _buildCountdownCard(),
                        const SizedBox(height: 24),
                      ],
                      _buildListHeader(),
                      const SizedBox(height: 12),
                      if (_anniversaries.isEmpty)
                        _buildEmpty()
                      else
                        ...List.generate(_anniversaries.length, (i) {
                          final isLast = i == _anniversaries.length - 1;
                          return _buildAnniversaryCard(_anniversaries[i], isLast: isLast);
                        }),
                    ],
                  ),
                ),
      floatingActionButton: _anniversaries.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showAddEditSheet(),
              backgroundColor: LoveGirlTheme.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  // ==================== 倒计时卡片 ====================
  Widget _buildCountdownCard() {
    final config = _typeConfig[_nextAnniversary!['type']] ?? _typeConfig['custom']!;
    final title = _nextAnniversary!['title'] ?? '';
    final desc = _nextAnniversary!['description'] ?? '';
    final lunarLabel = _nextAnniversary!['is_lunar'] == true || _nextAnniversary!['is_lunar'] == 1 ? '农历' : '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: LoveGirlTheme.gradientSunset,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        boxShadow: LoveGirlTheme.cardShadow(),
      ),
      child: Column(
        children: [
          Icon(config['icon'] as IconData, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (desc.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc.toString(),
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
          if (lunarLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(lunarLabel, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ),
          ],
          const SizedBox(height: 20),
          // 倒计时数字
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_nextDays',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w200, color: Colors.white, height: 1),
                ),
                const SizedBox(height: 2),
                const Text('天', style: TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _nextDays == 0 ? '就是今天！🎉' : '距离纪念日还有 $_nextDays 天',
            style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ==================== 列表头部 ====================
  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(color: LoveGirlTheme.primary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          const Text('所有纪念日', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LoveGirlTheme.textSecondary)),
          const Spacer(),
          Text('${_anniversaries.length}个', style: const TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
        ],
      ),
    );
  }

  // ==================== 纪念日卡片 ====================
  Widget _buildAnniversaryCard(Map<String, dynamic> item, {bool isLast = false}) {
    final type = item['type'] ?? 'custom';
    final config = _typeConfig[type] ?? _typeConfig['custom']!;
    final title = item['title'] ?? '';
    final desc = item['description'] ?? '';
    final dateStr = item['date'] ?? '';
    final daysUntil = _daysUntil(dateStr);
    final lunarMark = item['is_lunar'] == true || item['is_lunar'] == 1 ? ' (农历)' : '';

    // 格式化日期显示
    String displayDate = '';
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        displayDate = '${dt.month}月${dt.day}日$lunarMark';
      } else {
        displayDate = dateStr;
      }
    } catch (_) {
      displayDate = dateStr;
    }

    return GestureDetector(
      onLongPress: () => _deleteAnniversary(item),
      onTap: () => _showAddEditSheet(existing: item),
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Row(
          children: [
            // 类型图标
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: (config['color'] as Color).withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(config['icon'] as IconData, color: config['color'] as Color, size: 24),
            ),
            const SizedBox(width: 14),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LoveGirlTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (config['color'] as Color).withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          config['label'] as String,
                          style: TextStyle(fontSize: 11, color: config['color'] as Color, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayDate,
                    style: const TextStyle(fontSize: 14, color: LoveGirlTheme.textSecondary),
                  ),
                  if (desc.toString().isNotEmpty)
                    Text(
                      desc.toString(),
                      style: const TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 倒计时
            Column(
              children: [
                Text(
                  daysUntil == 0 ? '今天' : '$daysUntil',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: daysUntil <= 3 ? LoveGirlTheme.primary : LoveGirlTheme.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysUntil == 0 ? '🎉' : '天',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysUntil <= 3 ? LoveGirlTheme.primary : LoveGirlTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: LoveGirlTheme.textMuted),
          ],
        ),
      ),
    );
  }

  // ==================== 空状态 ====================
  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: LoveGirlTheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border_rounded, size: 40, color: LoveGirlTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text('还没有纪念日', style: TextStyle(fontSize: 16, color: LoveGirlTheme.textSecondary)),
            const SizedBox(height: 4),
            const Text('记录属于你们的重要日子吧~', style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddEditSheet(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加第一个纪念日'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LoveGirlTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 错误 ====================
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
