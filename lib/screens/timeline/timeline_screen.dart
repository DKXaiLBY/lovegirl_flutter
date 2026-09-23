import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/app_icon.dart';

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
    'achievement': Icons.emoji_events,
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

    final types = [
      'first_meet',
      'love',
      'anniversary',
      'travel',
      'gift',
      'default'
    ];
    final typeLabels = ['初次相遇', '确定关系', '纪念日', '旅行', '礼物', '其他'];

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
            top: 24,
          ),
          decoration: BoxDecoration(
            color: context.lgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.lgTextMuted.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text('添加时刻',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: context.lgTextPrimary)),
              SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '标题',
                  hintText: '例如：第一次见面',
                  prefixIcon: Icon(Icons.title, color: context.lgInk),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '描述（选填）',
                  hintText: '记录这个美好的时刻...',
                  prefixIcon:
                      Icon(Icons.description, color: context.lgTextMuted),
                ),
              ),
              SizedBox(height: 12),
              // 类型选择
              Text('事件类型',
                  style: TextStyle(
                      fontSize: 14, color: context.lgTextSecondary)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(types.length, (i) {
                  final selected = eventType == types[i];
                  return ChoiceChip(
                    label: Text(typeLabels[i]),
                    selected: selected,
                    selectedColor: LoveGirlTheme.primary.withAlpha(30),
                    labelStyle: TextStyle(
                        color: selected
                            ? context.lgInk
                            : context.lgTextSecondary,
                        fontSize: 13),
                    onSelected: (_) =>
                        setSheetState(() => eventType = types[i]),
                  );
                }),
              ),
              SizedBox(height: 12),
              // 日期选择
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setSheetState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.lgBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withAlpha(10)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: context.lgInk),
                      SizedBox(width: 10),
                      Text(
                        DateFormat('yyyy年M月d日').format(selectedDate),
                        style: TextStyle(
                            fontSize: 15, color: context.lgTextPrimary),
                      ),
                    ],
                  ),
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
                      await _api.createTimeline({
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'eventDate':
                            DateFormat('yyyy-MM-dd').format(selectedDate),
                        'icon': eventType,
                      });
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      await _loadTimeline();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text('保存失败: $e'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2)),
                        );
                      }
                    }
                  },
                  child: const Text('保存',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('恋爱时光轴'),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.lgTextPrimary,
        ),
        leading: IconButton(
          icon: AppIcon('back'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? RefreshIndicator(
                  onRefresh: _loadTimeline,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: _buildError())
                    ],
                  ),
                )
              : _events.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _loadTimeline,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: _buildEmpty())
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTimeline,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        children: [
                          // 时间轴线条
                          ...List.generate(_events.length, (index) {
                            final event = _events[index];
                            return _buildTimelineItem(
                                event, index == _events.length - 1);
                          }),
                        ],
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: context.lgInk,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 删除前确认：时刻记录删了就找不回来了
  Future<void> _deleteEvent(Map<String, dynamic> event, dynamic id) async {
    if (id == null) return;
    final title = (event['title'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条时刻？', style: TextStyle(fontSize: 16)),
        content: Text(
            title.isEmpty ? '删除后不可恢复' : '「$title」删除后不可恢复',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('删除',
                  style: TextStyle(color: LoveGirlTheme.red.withAlpha(230)))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteTimeline(id);
      await _loadTimeline();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('删除失败，再试一次'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Widget _buildTimelineItem(Map<String, dynamic> event, bool isLast) {
    final title = event['title'] ?? '';
    final description = event['description'] ?? event['desc'] ?? '';
    final date = event['eventDate'] ?? event['date'] ?? '';
    final type = event['icon'] ?? event['type'] ?? 'default';
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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.lgInk.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: context.lgInk),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: context.lgSeparator,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 16),
          // 右侧内容
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.lgCard,
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: context.lgTextPrimary)),
                      ),
                      GestureDetector(
                        onTap: () => _deleteEvent(event, id),
                        child: Icon(Icons.delete_outline,
                            size: 16, color: context.lgTextMuted),
                      ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(description,
                        style: TextStyle(
                            fontSize: 14, color: context.lgTextSecondary)),
                  ],
                  SizedBox(height: 8),
                  Text(formattedDate,
                      style: TextStyle(
                          fontSize: 12,
                          color: context.lgInk,
                          fontWeight: FontWeight.w500)),
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
          Icon(Icons.cloud_off, size: 48, color: context.lgTextMuted),
          SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: context.lgTextSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
              onPressed: _loadTimeline,
              icon: AppIcon('refresh'),
              label: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 64, color: context.lgTextMuted),
          const SizedBox(height: 12),
          Text('还没有时刻记录',
              style:
                  TextStyle(fontSize: 17, color: context.lgTextSecondary)),
          Text('点击右下角添加你们的恋爱时刻',
              style: TextStyle(fontSize: 13, color: context.lgTextMuted)),
        ],
      ),
    );
  }
}
