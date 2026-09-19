import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/app_icon.dart';

class AnniversaryScreen extends StatefulWidget {
  const AnniversaryScreen({super.key});

  @override
  State<AnniversaryScreen> createState() => _AnniversaryScreenState();
}

class _AnniversaryScreenState extends State<AnniversaryScreen> {
  static const String _pageTitle = '\u7eaa\u5ff5\u65e5';
  static const String _addTitle = '\u65b0\u589e\u7eaa\u5ff5\u65e5';
  static const String _editTitle = '\u7f16\u8f91\u7eaa\u5ff5\u65e5';
  static const String _nameLabel = '\u7eaa\u5ff5\u65e5\u540d\u79f0';
  static const String _nameHint =
      '\u4f8b\u5982\uff1a\u604b\u7231\u5468\u5e74\u3001\u5979\u751f\u65e5';
  static const String _noteLabel = '\u5907\u6ce8\uff08\u53ef\u9009\uff09';
  static const String _noteHint =
      '\u628a\u8fd9\u4e00\u5929\u4e3a\u4ec0\u4e48\u91cd\u8981\u8bb0\u4e0b\u6765';
  static const String _typeLabel = '\u7eaa\u5ff5\u7c7b\u578b';
  static const String _dateLabel = '\u65e5\u671f';
  static const String _repeatLabelTitle = '\u63d0\u9192\u65b9\u5f0f';
  static const String _lunarTitle = '\u8fd9\u662f\u519c\u5386\u65e5\u671f';
  static const String _lunarHint =
      '\u5148\u4fdd\u7559\u6807\u8bb0\uff0c\u65e5\u671f\u8ba1\u7b97\u4ecd\u6309\u5f53\u524d\u4fdd\u5b58\u65e5\u671f\u5c55\u793a\u3002';
  static const String _saveFailed =
      '\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u518d\u8bd5';
  static const String _deleteFailed =
      '\u5220\u9664\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5';
  static const String _loadFailed =
      '\u7eaa\u5ff5\u65e5\u52a0\u8f7d\u5931\u8d25\u4e86\uff0c\u7a0d\u540e\u518d\u8bd5\u4e00\u4e0b\u3002';
  static const String _emptyTitle = '\u8fd8\u6ca1\u6709\u7eaa\u5ff5\u65e5';
  static const String _emptyBody =
      '\u628a\u91cd\u8981\u7684\u65e5\u5b50\u6536\u8fdb\u6765\uff0c\u5230\u65f6\u95f4\u65f6\u5c31\u4e0d\u4f1a\u9519\u8fc7\u3002';
  static const String _heroTitle = '\u91cd\u8981\u65e5\u5b50\u63d0\u9192';
  static const String _heroBody =
      '\u628a\u503c\u5f97\u8bb0\u4f4f\u7684\u65e5\u5b50\u6536\u8fdb\u6765\uff0c\u5230\u65f6\u95f4\u65f6\u5c31\u4e0d\u4f1a\u9519\u8fc7\u3002';
  static const String _heroEmpty =
      '\u8fd8\u6ca1\u6709\u7eaa\u5ff5\u65e5\uff0c\u5148\u628a\u6700\u91cd\u8981\u7684\u90a3\u4e00\u5929\u8bb0\u4e0b\u6765\u5427\u3002';
  static const String _allTitle = '\u5168\u90e8\u7eaa\u5ff5\u65e5';

  static const Map<String, _AnniversaryTypeMeta> _typeConfig = {
    'love': _AnniversaryTypeMeta(
      label: '\u604b\u7231',
      icon: Icons.favorite_rounded,
      color: LoveGirlTheme.primary,
      token: 'love',
    ),
    'birthday': _AnniversaryTypeMeta(
      label: '\u751f\u65e5',
      icon: Icons.cake_rounded,
      color: LoveGirlTheme.orange,
      token: 'cake',
    ),
    'first': _AnniversaryTypeMeta(
      label: '\u7b2c\u4e00\u6b21',
      icon: Icons.star_rounded,
      color: Color(0xFF9E78D8),
      token: 'star',
    ),
    'custom': _AnniversaryTypeMeta(
      label: '\u81ea\u5b9a\u4e49',
      icon: Icons.auto_awesome_rounded,
      color: LoveGirlTheme.secondary,
      token: 'sparkles',
    ),
  };

  static const Map<String, String> _repeatLabels = {
    'yearly': '\u6bcf\u5e74\u63d0\u9192',
    'once': '\u53ea\u63d0\u9192\u8fd9\u4e00\u6b21',
    'monthly': '\u6bcf\u6708\u63d0\u9192',
  };

  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _anniversaries = const [];
  Map<String, dynamic>? _nextAnniversary;
  int _nextDays = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _api.getAnniversaries();
      final raw = response.data?['data'];
      final list = raw is List
          ? raw.map((item) => _normalizeItem(item)).toList()
          : <Map<String, dynamic>>[];

      list.sort((a, b) => _nextOccurrence(a).compareTo(_nextOccurrence(b)));

      if (!mounted) return;
      setState(() {
        _anniversaries = list;
        _nextAnniversary = list.isEmpty ? null : list.first;
        _nextDays = list.isEmpty ? 0 : _daysUntil(_nextOccurrence(list.first));
        _loading = false;
      });
      LogService().info(
        'Anniversary',
        '\u52a0\u8f7d\u4e86 ${list.length} \u4e2a$_pageTitle',
      );
    } catch (e) {
      LogService().error('Anniversary', '\u52a0\u8f7d\u5931\u8d25: $e');
      if (!mounted) return;
      setState(() {
        _error = _loadFailed;
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeItem(dynamic raw) {
    final source =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final type = _text(source['type'], fallback: 'custom');

    return {
      'id': source['id'],
      'title': _text(source['title'], fallback: _pageTitle),
      'description': _text(source['description']),
      'type': type,
      'eventDate': _text(source['eventDate'] ?? source['event_date']),
      'icon': _text(
        source['icon'],
        fallback: (_typeConfig[type] ?? _typeConfig['custom']!).token,
      ),
      'isLunar': source['is_lunar'] == true || source['is_lunar'] == 1,
      'repeatType': _text(
        source['repeat_type'] ?? source['repeatType'],
        fallback: 'yearly',
      ),
    };
  }

  Future<void> _showAddEditSheet({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final titleCtrl =
        TextEditingController(text: item?['title']?.toString() ?? '');
    final descCtrl =
        TextEditingController(text: item?['description']?.toString() ?? '');
    var selectedType = _text(item?['type'], fallback: 'love');
    var selectedDate = _parseDate(_text(item?['eventDate'])) ?? DateTime.now();
    var isLunar = item?['isLunar'] == true;
    var repeatType = _text(item?['repeatType'], fallback: 'yearly');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final meta = _typeConfig[selectedType] ?? _typeConfig['custom']!;
            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: LovePaper(
                radius: 26,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: LoveGirlTheme.separator,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          LoveStickerIcon(
                            icon: meta.icon,
                            color: meta.color,
                            size: 42,
                            iconSize: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isEdit ? _editTitle : _addTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: LoveGirlTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: _nameLabel,
                          hintText: _nameHint,
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: _noteLabel,
                          hintText: _noteHint,
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: LoveGirlTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _typeConfig.entries.map((entry) {
                          final selected = entry.key == selectedType;
                          return ChoiceChip(
                            label: Text(entry.value.label),
                            selected: selected,
                            avatar: Icon(
                              entry.value.icon,
                              size: 16,
                              color:
                                  selected ? Colors.white : entry.value.color,
                            ),
                            selectedColor: entry.value.color,
                            backgroundColor: entry.value.color.withAlpha(20),
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color:
                                  selected ? Colors.white : entry.value.color,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? entry.value.color
                                  : entry.value.color.withAlpha(40),
                            ),
                            onSelected: (_) {
                              setSheetState(() => selectedType = entry.key);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        _dateLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: LoveGirlTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
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
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: LoveGirlTheme.paperWarm,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: LoveGirlTheme.separator),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event_rounded,
                                color: LoveGirlTheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _formatDate(selectedDate, withYear: true),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: LoveGirlTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        _repeatLabelTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: LoveGirlTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _repeatLabels.entries.map((entry) {
                          final selected = repeatType == entry.key;
                          return ChoiceChip(
                            label: Text(entry.value),
                            selected: selected,
                            selectedColor: LoveGirlTheme.secondary,
                            backgroundColor: LoveGirlTheme.secondarySoft,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : LoveGirlTheme.secondary,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? LoveGirlTheme.secondary
                                  : LoveGirlTheme.secondary.withAlpha(40),
                            ),
                            onSelected: (_) {
                              setSheetState(() => repeatType = entry.key);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile.adaptive(
                        value: isLunar,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          _lunarTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: LoveGirlTheme.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          _lunarHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: LoveGirlTheme.textMuted,
                          ),
                        ),
                        activeColor: LoveGirlTheme.primary,
                        onChanged: (value) {
                          setSheetState(() => isLunar = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('\u53d6\u6d88'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final title = titleCtrl.text.trim();
                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(_nameLabel),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                final payload = {
                                  'title': title,
                                  'description': descCtrl.text.trim(),
                                  'type': selectedType,
                                  'eventDate': _dateKey(selectedDate),
                                  'icon': meta.token,
                                  'is_lunar': isLunar,
                                  'repeat_type': repeatType,
                                };

                                try {
                                  if (isEdit) {
                                    await _api.updateAnniversary(
                                      _asInt(item['id']),
                                      payload,
                                    );
                                    LogService().userAction(
                                      '\u7eaa\u5ff5\u65e5\u7f16\u8f91 "$title"',
                                    );
                                  } else {
                                    await _api.createAnniversary(payload);
                                    LogService().userAction(
                                      '\u7eaa\u5ff5\u65e5\u6dfb\u52a0 "$title"',
                                    );
                                  }
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  await _loadData();
                                } catch (e) {
                                  LogService().error(
                                    'Anniversary',
                                    '\u4fdd\u5b58\u5931\u8d25: $e',
                                  );
                                  if (!ctx.mounted) return;
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(_saveFailed),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                isEdit
                                    ? '\u4fdd\u5b58\u4fee\u6539'
                                    : '\u6dfb\u52a0\u7eaa\u5ff5\u65e5',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAnniversary(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('\u5220\u9664\u7eaa\u5ff5\u65e5'),
        content: Text(
          '\u786e\u5b9a\u5220\u9664\u300c${item['title']}\u300d\u5417\uff1f',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '\u5220\u9664',
              style: TextStyle(color: LoveGirlTheme.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteAnniversary(_asInt(item['id']));
      LogService().userAction(
        '\u7eaa\u5ff5\u65e5\u5220\u9664 "${item['title']}"',
      );
      await _loadData();
    } catch (e) {
      LogService().error('Anniversary', '\u5220\u9664\u5931\u8d25: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_deleteFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(title: const Text(_pageTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: LoveGirlTheme.primary,
        foregroundColor: Colors.white,
        icon: AppIcon('plus'),
        label: const Text(_addTitle),
      ),
      body: LovePage(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 98),
            children: [
              _buildHero(),
              const SizedBox(height: 16),
              if (_error != null) ...[
                _ErrorBanner(message: _error!, onRetry: _loadData),
                const SizedBox(height: 16),
              ],
              _buildSectionHeader(),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_anniversaries.isEmpty)
                _buildEmptyState()
              else
                ..._anniversaries.map(_buildItemCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final next = _nextAnniversary;
    final meta =
        _typeConfig[_text(next?['type'], fallback: 'custom')] ??
            _typeConfig['custom']!;
    final nextDate = next == null ? null : _nextOccurrence(next);

    return LoveTicketCard(
      color: const Color(0xFFFFF7F1),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LoveStickerIcon(
                icon: meta.icon,
                color: meta.color,
                size: 44,
                iconSize: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _heroTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _heroBody,
                      style: TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (next == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: LoveGirlTheme.separator),
              ),
              child: const Text(
                _heroEmpty,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: LoveGirlTheme.textSecondary,
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 104,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: meta.color,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_nextDays',
                        style: const TextStyle(
                          fontSize: 38,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _nextDays == 0
                            ? '\u5c31\u662f\u4eca\u5929'
                            : '\u5929\u540e\u5230\u6765',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(180),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: LoveGirlTheme.separator),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(next['title'], fallback: _pageTitle),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: LoveGirlTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextDate == null
                              ? _text(next['eventDate'])
                              : _formatDate(nextDate, withYear: true),
                          style: const TextStyle(
                            fontSize: 13,
                            color: LoveGirlTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            LovePill(
                              text: meta.label,
                              icon: meta.icon,
                              color: meta.color,
                            ),
                            LovePill(
                              text: _repeatLabel(next['repeatType']),
                              color: LoveGirlTheme.secondary,
                              background: LoveGirlTheme.secondarySoft,
                            ),
                            if (next['isLunar'] == true)
                              const LovePill(
                                text: '\u519c\u5386\u6807\u8bb0',
                                icon: Icons.nights_stay_outlined,
                                color: LoveGirlTheme.textMuted,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Text(
          _allTitle,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: LoveGirlTheme.textPrimary,
          ),
        ),
        const Spacer(),
        LovePill(
          text: '${_anniversaries.length} \u4e2a',
          icon: Icons.event_note_rounded,
          color: LoveGirlTheme.secondary,
          background: LoveGirlTheme.secondarySoft,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return LovePaper(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: LoveGirlTheme.primary.withAlpha(16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 36,
              color: LoveGirlTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            _emptyTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            _emptyBody,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: LoveGirlTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _showAddEditSheet(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(_addTitle),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final meta =
        _typeConfig[_text(item['type'], fallback: 'custom')] ??
            _typeConfig['custom']!;
    final nextDate = _nextOccurrence(item);
    final daysUntil = _daysUntil(nextDate);
    final description = _displayDescription(item, daysUntil);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LoveTicketCard(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoveStickerIcon(
                  icon: meta.icon,
                  color: meta.color,
                  size: 40,
                  iconSize: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(item['title'], fallback: _pageTitle),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: LoveGirlTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(nextDate, withYear: true),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: LoveGirlTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: daysUntil == 0
                        ? LoveGirlTheme.primary
                        : LoveGirlTheme.paperWarm,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        daysUntil == 0 ? '\u4eca\u5929' : '$daysUntil',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: daysUntil == 0
                              ? Colors.white
                              : LoveGirlTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        daysUntil == 0 ? '\u5230\u5566' : '\u5929',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: daysUntil == 0
                              ? Colors.white
                              : LoveGirlTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: LoveGirlTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                LovePill(
                  text: meta.label,
                  icon: meta.icon,
                  color: meta.color,
                ),
                LovePill(
                  text: _repeatLabel(item['repeatType']),
                  color: LoveGirlTheme.secondary,
                  background: LoveGirlTheme.secondarySoft,
                ),
                if (item['isLunar'] == true)
                  const LovePill(
                    text: '\u519c\u5386\u6807\u8bb0',
                    icon: Icons.nights_stay_outlined,
                    color: LoveGirlTheme.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddEditSheet(item: item),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('\u7f16\u8f91'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteAnniversary(item),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LoveGirlTheme.red,
                      side: const BorderSide(color: LoveGirlTheme.red),
                    ),
                    label: const Text('\u5220\u9664'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime _nextOccurrence(Map<String, dynamic> item) {
    final baseDate = _parseDate(_text(item['eventDate'])) ?? DateTime.now();
    final repeatType = _text(item['repeatType'], fallback: 'yearly');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (repeatType == 'once') {
      final onceDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
      return onceDate.isBefore(today) ? today : onceDate;
    }

    var next = _safeDate(today.year, baseDate.month, baseDate.day);
    if (next.isBefore(today)) {
      next = _safeDate(today.year + 1, baseDate.month, baseDate.day);
    }
    return next;
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.difference(today).inDays;
  }

  DateTime _safeDate(int year, int month, int day) {
    final firstDayNextMonth =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final maxDay = firstDayNextMonth.subtract(const Duration(days: 1)).day;
    return DateTime(year, month, day.clamp(1, maxDay));
  }

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatDate(DateTime date, {required bool withYear}) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    if (!withYear) return '$month.$day';
    return '${date.year}.$month.$day';
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _repeatLabel(dynamic value) {
    final key = _text(value, fallback: 'yearly');
    return _repeatLabels[key] ?? _repeatLabels['yearly']!;
  }

  String _displayDescription(Map<String, dynamic> item, int daysUntil) {
    final description = _text(item['description']);
    final englishCountdown =
        RegExp(r'\bdays?\s+left\b', caseSensitive: false);
    if (description.isEmpty) return '';
    if (englishCountdown.hasMatch(description)) {
      return '\u8fd8\u5269 $daysUntil \u5929';
    }
    return description;
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LoveGirlTheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: LoveGirlTheme.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: LoveGirlTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('\u91cd\u8bd5'),
          ),
        ],
      ),
    );
  }
}

class _AnniversaryTypeMeta {
  final String label;
  final IconData icon;
  final Color color;
  final String token;

  const _AnniversaryTypeMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.token,
  });
}
