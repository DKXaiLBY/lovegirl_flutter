import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  int _unlocked = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getAchievements();
      final data = res.data?['data'];
      final list = data is Map ? data['list'] : data;
      final parsed = list is List
          ? list
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _items = parsed;
        _unlocked = int.tryParse('${data is Map ? data['unlocked'] : ''}') ??
            parsed.where((item) => item['unlocked'] == true).length;
        _total = int.tryParse('${data is Map ? data['total'] : ''}') ??
            parsed.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '成就加载失败，请稍后重试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('成就'),
        backgroundColor: LoveGirlTheme.bgLight,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            LovePaper(
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: LoveGirlTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '已解锁 $_unlocked / $_total',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              LovePaper(
                child: Text(
                  _error!,
                  style: const TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              )
            else if (_items.isEmpty)
              const LovePaper(
                child: Text(
                  '暂无成就数据',
                  style: TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              )
            else
              ..._items.map(_achievementTile),
          ],
        ),
      ),
    );
  }

  Widget _achievementTile(Map<String, dynamic> item) {
    final unlocked = item['unlocked'] == true;
    final title = item['title']?.toString() ??
        item['name']?.toString() ??
        item['code']?.toString() ??
        '未命名成就';
    final description = item['description']?.toString() ?? '';
    final progress = int.tryParse('${item['progress'] ?? 0}') ?? 0;
    final target = int.tryParse('${item['target'] ?? 1}') ?? 1;
    final ratio = target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LovePaper(
        elevated: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unlocked
                      ? Icons.emoji_events_rounded
                      : Icons.lock_outline_rounded,
                  color: unlocked
                      ? LoveGirlTheme.primary
                      : LoveGirlTheme.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$progress/$target',
                  style: const TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: LoveGirlTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: LoveGirlTheme.separator,
                valueColor: AlwaysStoppedAnimation<Color>(
                  unlocked ? LoveGirlTheme.primary : LoveGirlTheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
