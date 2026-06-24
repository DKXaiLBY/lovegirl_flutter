import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';
import 'countdown_form.dart';

/// 倒计时管理页面
class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key});

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  List<Map<String, dynamic>> _countdowns = [];
  bool _loading = true;

  static const _iconMap = <int, IconData>{
    0xe87d: Icons.favorite_rounded,
    0xe1b7: Icons.cake_rounded,
    0xe539: Icons.flight_rounded,
    0xe80c: Icons.school_rounded,
    0xe88a: Icons.home_rounded,
    0xe769: Icons.celebration_rounded,
    0xe838: Icons.star_rounded,
    0xe3a3: Icons.fitness_center_rounded,
    0xe405: Icons.music_note_rounded,
    0xe865: Icons.book_rounded,
    0xe56c: Icons.restaurant_rounded,
    0xe8f9: Icons.work_rounded,
  };

  static const _iconColors = <int, Color>{
    0xe87d: Color(0xFFFF6B8A),
    0xe1b7: Color(0xFFFFB347),
    0xe539: Color(0xFF7B8CFF),
    0xe80c: Color(0xFF4CAF50),
    0xe88a: Color(0xFFFF9800),
    0xe769: Color(0xFFE040FB),
    0xe838: Color(0xFFFFD700),
    0xe3a3: Color(0xFF26C6DA),
    0xe405: Color(0xFFFF6B8A),
    0xe865: Color(0xFF7B8CFF),
    0xe56c: Color(0xFFFF9800),
    0xe8f9: Color(0xFF6B6B7B),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('countdowns') ?? '[]';
      final List<dynamic> raw = jsonDecode(jsonStr);
      _countdowns = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      // 按目标日期排序
      _countdowns.sort((a, b) {
        final da = a['targetDate'] ?? '';
        final db = b['targetDate'] ?? '';
        return da.compareTo(db);
      });
    } catch (_) {
      _countdowns = [];
    }
    setState(() => _loading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('countdowns', jsonEncode(_countdowns));
  }

  int _daysRemaining(String dateStr) {
    if (dateStr.isEmpty) return 99999;
    final target = DateTime.tryParse(dateStr);
    if (target == null) return 99999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    return targetDay.difference(today).inDays;
  }

  IconData _getIcon(int codePoint) {
    return _iconMap[codePoint] ?? Icons.favorite_rounded;
  }

  Color _getIconColor(int codePoint) {
    return _iconColors[codePoint] ?? LoveGirlTheme.primary;
  }

  void _navigateToForm({Map<String, dynamic>? item}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CountdownForm(item: item),
      ),
    );
    if (result == null) return;

    setState(() {
      if (item != null) {
        // 编辑：找到并替换
        final idx = _countdowns.indexWhere((e) => e['id'] == item['id']);
        if (idx >= 0) {
          _countdowns[idx] = result;
        }
      } else {
        // 新增
        _countdowns.add(result);
      }
      // 重新排序
      _countdowns.sort((a, b) {
        final da = a['targetDate'] ?? '';
        final db = b['targetDate'] ?? '';
        return da.compareTo(db);
      });
    });
    await _saveData();
  }

  void _deleteItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('删除倒计时'),
        content: Text('确定删除「${item['name'] ?? ''}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _countdowns.removeWhere((e) => e['id'] == item['id']);
              });
              await _saveData();
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
        title: const Text('倒计时'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _countdowns.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _countdowns.length,
                  itemBuilder: (context, index) {
                    return _buildCountdownCard(_countdowns[index]);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        backgroundColor: LoveGirlTheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  // ==================== 倒计时卡片 ====================
  Widget _buildCountdownCard(Map<String, dynamic> item) {
    final name = item['name'] ?? '';
    final targetDate = item['targetDate'] ?? '';
    final iconCodePoint = item['iconCodePoint'] ?? 0xe87d;
    final days = _daysRemaining(targetDate);
    final iconColor = _getIconColor(iconCodePoint);

    // 日期副标题
    String dateSubtitle = targetDate;
    try {
      final dt = DateTime.tryParse(targetDate);
      if (dt != null) {
        dateSubtitle = '${dt.year}年${dt.month}月${dt.day}日';
      }
    } catch (_) {}

    // 天数文字
    String daysText;
    Color daysColor;
    if (days > 0) {
      daysText = '还有 $days 天';
      daysColor = LoveGirlTheme.primary;
    } else if (days == 0) {
      daysText = '就是今天！🎉';
      daysColor = LoveGirlTheme.secondary;
    } else {
      daysText = '已过 ${-days} 天';
      daysColor = LoveGirlTheme.textMuted;
    }

    return GestureDetector(
      onTap: () => _navigateToForm(item: item),
      onLongPress: () => _deleteItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Row(
          children: [
            // 图标圆圈
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(_getIcon(iconCodePoint), color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LoveGirlTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateSubtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: LoveGirlTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 天数
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  days == 0 ? '今天' : '$days',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: daysColor,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysText,
                  style: TextStyle(fontSize: 12, color: daysColor, fontWeight: FontWeight.w500),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: LoveGirlTheme.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, size: 40, color: LoveGirlTheme.primary),
          ),
          const SizedBox(height: 16),
          const Text('还没有倒计时', style: TextStyle(fontSize: 16, color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 4),
          const Text('添加一个重要的日子开始倒计时吧~', style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToForm(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('添加倒计时'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LoveGirlTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
