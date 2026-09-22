import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/notification_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';
import '../cooking/cooking_log_screen.dart';
import '../daily/daily_question_screen.dart';
import '../profile/achievements_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../letter/slow_letter_screen.dart';

/// 通知中心：分组列表 + 全部已读 + 点击深链接
class NotificationCenterScreen extends StatefulWidget {
  /// 用于深链接跳回主 tab（旅行=1）。由宿主（HomeScreen）传入。
  final void Function(int tab)? onNavigateToTab;

  const NotificationCenterScreen({super.key, this.onNavigateToTab});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<NotificationProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: context.lgBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(context, provider),
            Expanded(
              child: provider.loading && provider.items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: LoveGirlTheme.primary),
                    )
                  : RefreshIndicator(
                      color: LoveGirlTheme.primary,
                      onRefresh: () => provider.refresh(),
                      child: provider.items.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 120),
                              EmptyState(
                                icon: Icons.notifications_none_rounded,
                                title: '还没有通知',
                                subtitle: 'TA 的订单、打卡和心意都会出现在这里',
                                onRetry: () => provider.refresh(),
                                retryText: '刷新',
                              ),
                            ])
                          : _buildList(context, provider),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(
      BuildContext context, NotificationProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 4),
      child: Row(
        children: [
          LoveIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          Text(
            '通知中心',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: context.lgTextPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed:
                provider.unreadCount > 0 ? () => _markAllRead(provider) : null,
            style: TextButton.styleFrom(
              foregroundColor: context.lgInk,
              disabledForegroundColor: context.lgTextMuted.withAlpha(120),
            ),
            child: const Text('全部已读',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllRead(NotificationProvider provider) async {
    await provider.markAllRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('全部标记为已读'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 1),
    ));
  }

  Widget _buildList(BuildContext context, NotificationProvider provider) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        if (provider.todayItems.isNotEmpty) ...[
          LoveSectionTitle(title: '今天'),
          _buildGroupCard(context, provider, provider.todayItems),
          const SizedBox(height: 20),
        ],
        if (provider.earlierItems.isNotEmpty) ...[
          LoveSectionTitle(title: '更早'),
          _buildGroupCard(context, provider, provider.earlierItems),
        ],
      ],
    );
  }

  Widget _buildGroupCard(
      BuildContext context, NotificationProvider provider, List<NotificationItem> group) {
    return LovePaper(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < group.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 62, color: context.lgSeparator),
            _NotificationRow(
              item: group[i],
              onTap: () => _handleTap(provider, group[i]),
            ),
          ],
        ],
      ),
    );
  }

  void _handleTap(NotificationProvider provider, NotificationItem item) async {
    await provider.markRead(item);
    if (!mounted) return;
    final payload = item.payload;
    switch (item.type) {
      case 'kitchen_order':
      case 'feeding_order':
      case 'feeding_status':
      case 'feeding_urge':
      case 'feeding_delivery':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const KitchenScreen()));
        break;
      case 'travel_checkin':
        // 先回到根，再切到旅行 tab
        Navigator.of(context).popUntil((route) => route.isFirst);
        widget.onNavigateToTab?.call(1);
        break;
      case 'daily_question':
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DailyQuestionScreen()));
        break;
      case 'cooking':
      case 'cooking_taste':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CookingLogScreen()));
        break;
      case 'achievement':
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AchievementsScreen()));
        break;
      case 'slow_letter':
        final letterId = (item.payload['letter_id'] as num?)?.toInt();
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => letterId != null
                ? LetterReadScreen(letterId: letterId)
                : const SlowLetterScreen()));
        break;
      default:
        if (payload['order_id'] != null) {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const KitchenScreen()));
        }
        break;
    }
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationRow({required this.item, required this.onTap});

  IconData get _icon {
    switch (item.type) {
      case 'kitchen_order':
        return Icons.restaurant_rounded;
      case 'feeding_order':
      case 'feeding_status':
      case 'feeding_urge':
      case 'feeding_delivery':
        return Icons.local_cafe_outlined;
      case 'travel_checkin':
        return Icons.map_rounded;
      case 'daily_question':
        return Icons.quiz_outlined;
      case 'slow_letter':
        return Icons.mark_email_unread_outlined;
      case 'cooking':
      case 'cooking_taste':
        return Icons.restaurant_rounded;
      case 'achievement':
        return Icons.emoji_events_outlined;
      case 'version':
        return Icons.system_update_outlined;
      default:
        return Icons.favorite_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.lgInk,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (unread) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.lgInk,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w600,
                            color: context.lgTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.lgTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.relativeTime(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.lgTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
