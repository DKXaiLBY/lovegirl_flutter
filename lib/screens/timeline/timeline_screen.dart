import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';

/// 恋爱时光轴页面
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  static const _eventIcons = {
    'love': Icons.favorite,
    'first_meet': Icons.waving_hand,
    'travel': Icons.flight,
    'gift': Icons.card_giftcard,
    'anniversary': Icons.celebration,
    'default': Icons.auto_awesome,
  };

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getTimeline();
      final data = res.data['data'];
      _events = (data is List)
          ? data.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      _error = '加载失败，下拉重试';
    }
    setState(() => _loading = false);
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String eventType = 'default';
    DateTime selectedDate = DateTime.now();

    final types = ['first_meet', 'love', 'anniversary', 'travel', 'gift', 'default'];
    final typeLabels = ['初次相遇', '确定关系', '纪念日', '旅行', '礼物', '其他'];

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
              const Text('添加时刻', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: LoveGirlTheme.textPrimary)),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '例如：第一次见面',
                  prefixIcon: Icon(Icons.title, color: LoveGirlTheme.primary),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '描述（选填）',
                  hintText: '记录这个美好的时刻...',
                  prefixIcon: Icon(Icons.description, color: LoveGirlTheme.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              // 类型选择
              const Text('事件类型', style: TextStyle(fontSize: 14, color: LoveGirlTheme.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(types.length, (i) {
                  final selected = eventType == types[i];
                  return ChoiceChip(
                    label: Text(typeLabels[i]),
                    selected: selected,
                    selectedColor: LoveGirlTheme.primary.withAlpha(30),
                    labelStyle: TextStyle(color: selected ? LoveGirlTheme.primary : LoveGirlTheme.textSecondary, fontSize: 13),
                    onSelected: (_) => setSheetState(() => eventType = types[i]),
                  );
                }),
              ),
              const SizedBox(height: 12),
              // 日期选择
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.bgLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withAlpha(10)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: LoveGirlTheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('yyyy年M月d日').format(selectedDate),
                        style: const TextStyle(fontSize: 15, color: LoveGirlTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    try {
                      await _api.createTimeline({
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'type': eventType,
                        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
                      });
                      Navigator.pop(ctx);
                      await _loadTimeline();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('保存失败: $e'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
                        );
                      }
                    }
                  },
                  child: const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    return _eventIcons[type] ?? _eventIcons['default']!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('恋爱时光轴'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _events.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadTimeline,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        children: [
                          // 时间轴线条
                          ...List.generate(_events.length, (index) {
                            final event = _events[index];
                            return _buildTimelineItem(event, index == _events.length - 1);
                          }),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: LoveGirlTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> event, bool isLast) {
    final title = event['title'] ?? '';
    final description = event['description'] ?? event['desc'] ?? '';
    final date = event['date'] ?? '';
    final type = event['type'] ?? 'default';
    final id = event['id'];
    final icon = _getIcon(type);

    String formattedDate = '';
    try {
      formattedDate = DateFormat('M月d日').format(DateTime.parse(date));
    } catch (_) {
      formattedDate = date;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧时间轴
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: LoveGirlTheme.primary),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: LoveGirlTheme.separator,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 右侧内容
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LoveGirlTheme.cardLight,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: LoveGirlTheme.textPrimary)),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (id != null) {
                            try {
                              await _api.deleteTimeline(id);
                              await _loadTimeline();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('删除失败'), behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
                                );
                              }
                            }
                          }
                        },
                        child: const Icon(Icons.delete_outline, size: 16, color: LoveGirlTheme.textMuted),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description, style: const TextStyle(fontSize: 14, color: LoveGirlTheme.textSecondary)),
                  ],
                  const SizedBox(height: 8),
                  Text(formattedDate, style: const TextStyle(fontSize: 12, color: LoveGirlTheme.pink, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(onPressed: _loadTimeline, icon: const Icon(Icons.refresh), label: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 64, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          const Text('还没有时刻记录', style: TextStyle(fontSize: 16, color: LoveGirlTheme.textSecondary)),
          const Text('点击右下角添加你们的恋爱时刻', style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
        ],
      ),
    );
  }
}
