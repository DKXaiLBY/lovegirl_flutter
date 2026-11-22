import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lovegirl_flutter/services/app_storage.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/rebuild_controls.dart';
import '../../features/creations/creation_files.dart';
import 'package:lovegirl_flutter/widgets/glass_routes.dart';
/// 恋爱时光轴页面
class TimelineScreen extends StatefulWidget {
  final ApiService? api;
  const TimelineScreen({super.key, this.api});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  int _request = 0;

  bool _selectionMode = false;
  bool _deleting = false;
  final Set<int> _selectedIds = {};

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
    if (!mounted) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getTimeline();
      if (!mounted || request != _request) return;
      final data = res.data['data'];
      if (data is! List) throw const FormatException('无效的时光轴');
      _events = data.whereType<Map>().map(Map<String, dynamic>.from).toList();
      _selectedIds.retainAll(_events.map(_eventId).whereType<int>());
    } catch (e) {
      if (!mounted || request != _request) return;
      _error = extractServerMessage(e, fallback: '时光轴暂未读取，可以重试');
    }
    setState(() => _loading = false);
  }

  int? _eventId(Map<String, dynamic> event) {
    final id = event['id'];
    return id is num ? id.toInt() : null;
  }

  void _toggleSelect(int id) {
    setState(() {
      if (!_selectionMode) _selectionMode = true;
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      for (final e in _events) {
        final id = _eventId(e);
        if (id != null) _selectedIds.add(id);
      }
    });
  }

  /// 批量删除：一次确认，逐条调用，统计失败数
  Future<void> _deleteSelected() async {
    if (_deleting) return;
    final n = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LoveGirlTheme.radiusXl)),
        title: Text('删除 $n 条时刻？', style: const TextStyle(fontSize: 16)),
        content: const Text('删除后不可恢复', style: TextStyle(fontSize: 13)),
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
    if (confirm != true || !mounted) return;
    setState(() => _deleting = true);
    var failed = 0;
    final removed = <int>{};
    for (final id in _selectedIds.toList()) {
      try {
        await _api.deleteTimeline(id);
        removed.add(id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _deleting = false;
    _events.removeWhere((event) => removed.contains(_eventId(event)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed == 0 ? '已删除 $n 条' : '有 $failed 条删除失败'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
    _exitSelectionMode();
    _loadTimeline();
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String eventType = 'default';
    bool saving = false;
    String? saveError;
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

    showGlassSheet(
      context: context,
      isScrollControlled: true,
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
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(LoveGirlTheme.radiusXl)),
          ),
          child: SingleChildScrollView(
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
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.lgBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.lgCardBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: context.lgInk),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy年M月d日').format(selectedDate),
                            style: TextStyle(
                                fontSize: 15, color: context.lgTextPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                if (saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(saveError!,
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error)),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (titleCtrl.text.trim().isEmpty) {
                              setSheetState(() => saveError = '请填写标题');
                              return;
                            }
                            setSheetState(() {
                              saving = true;
                              saveError = null;
                            });
                            try {
                              await _api.createTimeline({
                                'title': titleCtrl.text.trim(),
                                'description': descCtrl.text.trim(),
                                'eventDate': DateFormat('yyyy-MM-dd')
                                    .format(selectedDate),
                                'icon': eventType,
                              });
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              await _loadTimeline();
                            } catch (e) {
                              if (!ctx.mounted) return;
                              setSheetState(() {
                                saving = false;
                                saveError = extractServerMessage(e,
                                    fallback: '保存失败，输入已保留');
                              });
                            }
                          },
                    style: rebuildFilledStyle(ctx),
                    child: Text(saving ? '正在保存' : '保存'),
                  ),
                ),
              ],
            ),
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
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: context.lgBg,
        appBar: _selectionMode ? _selectionAppBar() : _normalAppBar(),
        body: RebuildPageBackground(
          child: _loading && _events.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTimeline,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_error != null)
                        SliverToBoxAdapter(
                          child: ListTile(
                            title: Text(_error!),
                            trailing: TextButton(
                              onPressed: _loadTimeline,
                              child: const Text('重试'),
                            ),
                          ),
                        ),
                      if (_events.isEmpty && _error == null)
                        SliverFillRemaining(
                            hasScrollBody: false, child: _buildEmpty()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        sliver: SliverList.builder(
                          itemCount: _events.length,
                          itemBuilder: (_, index) => _buildTimelineItem(
                              _events[index], index == _events.length - 1),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        floatingActionButton: _selectionMode
            ? null
            : RebuildGlassButton(
                label: '添加时刻',
                icon: Icons.add,
                onPressed: _showAddDialog,
                selected: true,
                showLabel: true,
              ),
      ),
    );
  }

  PreferredSizeWidget _normalAppBar() {
    return AppBar(
      flexibleSpace: const RebuildGlassHeader(),
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
      actions: [
        if (_events.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.checklist_rounded),
            tooltip: '批量管理',
            onPressed:
                _deleting ? null : () => setState(() => _selectionMode = true),
          ),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar() {
    final foreground = context.lgIsDark ? context.lgBg : Colors.white;
    return AppBar(
      flexibleSpace: const RebuildGlassHeader(),
      backgroundColor: context.lgInk,
      foregroundColor: foreground,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelectionMode,
      ),
      title: Text('已选 ${_selectedIds.length}',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: foreground)),
      actions: [
        TextButton(
            onPressed: _deleting ? null : _selectAll,
            child: Text('全选',
                style:
                    TextStyle(color: foreground, fontWeight: FontWeight.w800))),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: '批量删除',
          onPressed: _selectedIds.isEmpty || _deleting ? null : _deleteSelected,
        ),
      ],
    );
  }

  /// 删除前确认：时刻记录删了就找不回来了
  Future<void> _deleteEvent(Map<String, dynamic> event, int id) async {
    if (_deleting) return;
    final title = (event['title'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlertDialog(
        title: const Text('删除这条时刻？', style: TextStyle(fontSize: 16)),
        content: Text(title.isEmpty ? '删除后不可恢复' : '「$title」删除后不可恢复',
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
    setState(() => _deleting = true);
    try {
      await _api.deleteTimeline(id);
      if (!mounted) return;
      _events.removeWhere((event) => _eventId(event) == id);
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
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Widget _buildTimelineItem(Map<String, dynamic> event, bool isLast) {
    final title = (event['title'] ?? '').toString();
    final description =
        (event['description'] ?? event['desc'] ?? '').toString();
    final date = (event['eventDate'] ?? event['date'] ?? '').toString();
    final type = (event['icon'] ?? event['type'] ?? 'default').toString();
    final image =
        (event['imageUrl'] ?? event['image_url'] ?? '').toString().trim();
    final icon = _getIcon(type);
    final eid = _eventId(event);
    final bool selected = eid != null && _selectedIds.contains(eid);

    final parsedDate = DateTime.tryParse(date)?.toLocal();
    final formattedDate =
        parsedDate == null ? date : DateFormat('yyyy年M月d日').format(parsedDate);

    return Stack(children: [
      if (!isLast)
        Positioned(
          left: 19,
          top: 20,
          bottom: 0,
          child: Container(width: 2, color: context.lgSeparator),
        ),
      Positioned(
        left: 0,
        top: 0,
        child: CircleAvatar(
          radius: 20,
          backgroundColor: context.lgPrimarySoft,
          foregroundColor: context.lgInk,
          child: Icon(icon, size: 20),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 52, bottom: 14),
        child: RebuildGlass(
          radius: 18,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _selectionMode && eid != null && !_deleting
                ? () => _toggleSelect(eid)
                : null,
            onLongPress:
                eid == null || _deleting ? null : () => _toggleSelect(eid),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 6, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(formattedDate,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.lgTextSecondary))),
                      if (_selectionMode && eid != null)
                        Checkbox(
                            value: selected,
                            onChanged:
                                _deleting ? null : (_) => _toggleSelect(eid))
                      else if (eid != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 19),
                          tooltip: '删除时刻',
                          onPressed:
                              _deleting ? null : () => _deleteEvent(event, eid),
                        ),
                    ]),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    if (image.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1.75,
                          child: CachedNetworkImage(
                            cacheManager: MediaCache.instance,
                            imageUrl: creationUrl(image),
                            memCacheWidth: 680,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description,
                          style: TextStyle(color: context.lgTextSecondary)),
                    ],
                  ]),
            ),
          ),
        ),
      ),
    ]);
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
              style: TextStyle(fontSize: 17, color: context.lgTextSecondary)),
          Text('点击右下角添加你们的恋爱时刻',
              style: TextStyle(fontSize: 13, color: context.lgTextMuted)),
        ],
      ),
    );
  }
}
