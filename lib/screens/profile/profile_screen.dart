import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../settings/settings_screen.dart';
import '../feeding/feeding_screen.dart';
import '../anniversary/anniversary_screen.dart';
import '../mood/mood_screen.dart';
import '../chat/chat_screen.dart';
import '../photo/photo_screen.dart';
import '../timeline/timeline_screen.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  const ProfileScreen({super.key, this.onNavigateToTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),
            _buildUserCard(user, auth),
            const SizedBox(height: 24),
            _buildMenu(auth),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic>? user, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
        border: Border.all(color: LoveGirlTheme.separator.withAlpha(130)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: LoveGirlTheme.separator,
            backgroundImage: (user?['avatar'] != null && (user!['avatar']?.toString().isNotEmpty == true))
                ? NetworkImage(user!['avatar'].toString())
                : null,
            child: (user?['avatar'] == null || user!['avatar']?.toString().isEmpty != false)
                ? const Icon(Icons.person, color: LoveGirlTheme.textMuted)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?['nickname'] ?? '亲爱的',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '在一起 ${auth.loveDays} 天',
                  style: const TextStyle(fontSize: 13, color: LoveGirlTheme.primary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: LoveGirlTheme.textMuted),
        ],
      ),
    );
  }

  Widget _buildMenu(AuthProvider auth) {
    final items = <_MenuItem>[
      _MenuItem(icon: Icons.photo_library_outlined, title: '云端相册', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoScreen()));
      }),
      _MenuItem(icon: Icons.favorite_outline, title: '恋爱时光轴', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TimelineScreen()));
      }),
      _MenuItem(icon: Icons.mood_outlined, title: '心情日记', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodScreen()));
      }),
      _MenuItem(icon: Icons.chat_bubble_outline, title: '私密聊天', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
      }),
      _MenuItem(icon: Icons.card_giftcard, title: '投喂站', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedingScreen()));
      }),
      _MenuItem(icon: Icons.favorite_border, title: '纪念日', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AnniversaryScreen()));
      }),
      _MenuItem(icon: Icons.map_outlined, title: '旅行足迹', onTap: () {
        if (widget.onNavigateToTab != null) {
          widget.onNavigateToTab!(1);
        }
      }),
      _MenuItem(icon: Icons.settings_outlined, title: '设置', onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }),
    ];

    return Container(
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
        border: Border.all(color: LoveGirlTheme.separator.withAlpha(130)),
      ),
      child: Column(
        children: items.map((item) {
          final last = items.last == item;
          return InkWell(
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(item.icon, size: 22, color: LoveGirlTheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(item.title, style: const TextStyle(fontSize: 16)),
                  ),
                  if (!last)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.chevron_right, size: 18, color: LoveGirlTheme.textMuted),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, required this.onTap});
}
