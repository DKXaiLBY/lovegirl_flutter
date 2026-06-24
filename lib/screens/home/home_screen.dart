import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/weather_widget.dart';
import '../mood/mood_screen.dart';
import '../chat/chat_screen.dart';
import '../photo/photo_screen.dart';
import '../timeline/timeline_screen.dart';
import '../feeding/feeding_screen.dart';
import '../search/search_screen.dart';
import '../anniversary/anniversary_screen.dart';
import '../countdown/countdown_screen.dart';
import '../tasks/tasks_screen.dart';

/// 首页入口数据
class _HomeEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final int? targetTab;
  final Color color;
  const _HomeEntry({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.targetTab,
    this.route = '',
    this.color = LoveGirlTheme.primary,
  });
}

const _entries = <_HomeEntry>[
  _HomeEntry(icon: Icons.map_outlined, title: '旅行足迹', subtitle: '记录一起走过的地方', targetTab: 1, color: Color(0xFFFF6B8A)),
  _HomeEntry(icon: Icons.checklist_outlined, title: '待办事项', subtitle: '共同的生活计划', targetTab: 3, route: 'tab:3:0', color: Color(0xFFFFB347)),
  _HomeEntry(icon: Icons.account_balance_wallet_outlined, title: '记账本', subtitle: '管理生活开支', targetTab: 3, route: 'tab:3:1', color: Color(0xFF4CAF50)),
  _HomeEntry(icon: Icons.card_giftcard, title: '投喂站', subtitle: '给TA一份惊喜', route: 'feeding', color: Color(0xFFFF6B8A)),
  _HomeEntry(icon: Icons.favorite_border, title: '纪念日', subtitle: '记录重要日子', route: 'anniversary', color: Color(0xFFFF6B8A)),
  _HomeEntry(icon: Icons.timer_outlined, title: '倒计时', subtitle: '重要的日子', route: 'countdown', color: Color(0xFFE040FB)),
  _HomeEntry(icon: Icons.auto_awesome_outlined, title: '愿望清单', subtitle: '一起想做的事', route: 'tasks', color: Color(0xFF4CAF50)),
  _HomeEntry(icon: Icons.mood_outlined, title: '心情日记', subtitle: '记录每天心情', route: 'mood', color: Color(0xFF7B8CFF)),
  _HomeEntry(icon: Icons.search_rounded, title: '搜索', subtitle: '搜索一切记录', route: 'search', color: Color(0xFF7B8CFF)),
  _HomeEntry(icon: Icons.chat_bubble_outline, title: '聊天室', subtitle: '属于我们的悄悄话', route: 'chat', color: Color(0xFFE040FB)),
  _HomeEntry(icon: Icons.photo_library_outlined, title: '云端相册', subtitle: '珍藏美好瞬间', route: 'photo', color: Color(0xFF00BCD4)),
];

class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function(int tabIndex, int subTab)? onNavigateToSubTab;
  const HomeScreen({super.key, this.onNavigateToTab, this.onNavigateToSubTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _handleTap(_HomeEntry entry) {
    if (entry.targetTab != null && entry.route.startsWith('tab:')) {
      final parts = entry.route.split(':');
      if (parts.length == 3 && widget.onNavigateToSubTab != null) {
        widget.onNavigateToSubTab!(entry.targetTab!, int.parse(parts[2]));
        return;
      }
      if (widget.onNavigateToTab != null) {
        widget.onNavigateToTab!(entry.targetTab!);
      }
      return;
    }

    if (entry.targetTab != null && widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(entry.targetTab!);
      return;
    }

    switch (entry.route) {
      case 'mood':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodScreen()));
        break;
      case 'chat':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        break;
      case 'photo':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoScreen()));
        break;
      case 'timeline':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TimelineScreen()));
        break;
      case 'feeding':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedingScreen()));
        break;
      case 'anniversary':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AnniversaryScreen()));
        break;
      case 'countdown':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CountdownScreen()));
        break;
      case 'tasks':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()));
        break;
      case 'search':
        Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const SearchScreen())).then((result) {
          if (result != null && mounted) {
            final type = result['type'] as String? ?? '';
            if (type == 'travel' && widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(1);
            } else if (type == 'todo' && widget.onNavigateToSubTab != null) {
              widget.onNavigateToSubTab!(3, 0);
            } else if (type == 'finance' && widget.onNavigateToSubTab != null) {
              widget.onNavigateToSubTab!(3, 1);
            } else if (type == 'course' && widget.onNavigateToSubTab != null) {
              widget.onNavigateToSubTab!(3, 2);
            }
          }
        });
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${entry.title} — 即将上线'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final days = auth.loveDays;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            _buildHeader(user, days),
            const SizedBox(height: 16),
            const WeatherWidget(),
            const SizedBox(height: 20),
            _buildGrid(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? user, int days) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: LoveGirlTheme.gradientSunset,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        boxShadow: LoveGirlTheme.cardShadow(),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withAlpha(60),
            child: CircleAvatar(
              radius: 26,
              backgroundImage: (user?['avatar'] != null && (user!['avatar'] as String).isNotEmpty)
                  ? NetworkImage(user['avatar'])
                  : null,
              child: (user?['avatar'] == null || (user!['avatar'] as String).isEmpty)
                  ? const Icon(Icons.favorite_rounded, color: Colors.white, size: 24)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?['nickname'] ?? '亲爱的',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                '在一起 $days 天',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  '$days',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w300, color: Colors.white, height: 1),
                ),
                const SizedBox(height: 2),
                const Text('天', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.3,
      ),
      itemCount: _entries.length,
      itemBuilder: (context, index) => _buildCard(_entries[index]),
    );
  }

  Widget _buildCard(_HomeEntry entry) {
    return GestureDetector(
      onTap: () => _handleTap(entry),
      child: Container(
        decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: entry.color.withAlpha(22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, size: 22, color: entry.color),
            ),
            const Spacer(),
            Text(
              entry.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: LoveGirlTheme.textPrimary),
            ),
            if (entry.subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                entry.subtitle,
                style: const TextStyle(fontSize: 11, color: LoveGirlTheme.textMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
