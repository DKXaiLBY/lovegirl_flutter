import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_dates.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../anniversary/anniversary_screen.dart';
import '../couple/couple_binding_screen.dart';
import '../photo/photo_screen.dart';
import '../settings/log_screen.dart';
import '../settings/settings_screen.dart';
import '../timeline/timeline_screen.dart';
import '../version/update_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const ProfileScreen({super.key, this.onNavigateToTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _partnerName;
  int _beanBalance = 0;
  int _achievementCount = 0;
  int _loveDays = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      final results = await Future.wait([
        _api.getCoupleStatus(),
        _api.getBeanBalance(),
        _api.getAchievements(),
        _api.getAnniversaries(),
      ]);

      String? partnerName;
      int beanBalance = 0;
      int achievementCount = 0;
      int loveDays = auth.loveDays;

      final coupleData = results[0].data?['data'];
      if (coupleData is Map &&
          coupleData['coupled'] == true &&
          coupleData['partner'] is Map) {
        partnerName = coupleData['partner']['nickname']?.toString();
      }

      final beanData = results[1].data?['data'];
      if (beanData is Map) {
        beanBalance = int.tryParse(beanData['balance']?.toString() ?? '0') ?? 0;
      }

      final achievementData = results[2].data?['data'];
      if (achievementData is List) {
        achievementCount = achievementData.length;
      } else if (achievementData is Map) {
        achievementCount = int.tryParse(
              achievementData['total']?.toString() ??
                  achievementData['count']?.toString() ??
                  '0',
            ) ??
            0;
      }

      final anniversaryData = results[3].data?['data'];
      final anniversaryList = anniversaryData is List
          ? anniversaryData
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
          : <Map<String, dynamic>>[];
      loveDays = resolveLoveDays(
        explicitDate: user?['loveStartDate']?.toString(),
        anniversaries: anniversaryList,
        fallbackDays: loveDays,
      );

      if (!mounted) return;
      setState(() {
        _partnerName = partnerName;
        _beanBalance = beanBalance;
        _achievementCount = achievementCount;
        _loveDays = loveDays;
        _loading = false;
      });
    } catch (e) {
      LogService().error('Profile', '加载我的页数据失败: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: LovePage(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              _buildHeader(context),
              const SizedBox(height: 18),
              _ProfileHero(
                user: user,
                partnerName: _partnerName,
                loveDays: _loveDays,
                beanBalance: _beanBalance,
                loading: _loading,
              ),
              const SizedBox(height: 18),
              _buildDataZone(context, _loveDays, _partnerName),
              const SizedBox(height: 14),
              _buildFunctionZone(context, auth.isAdmin),
              const SizedBox(height: 14),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\u5173\u7cfb\u8d44\u6599\u5939',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                  SizedBox(width: 6),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: LoveGirlTheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '\u628a\u4f60\u4eec\u7684\u5173\u7cfb\u3001\u56de\u5fc6\u548c\u65e5\u5e38\u90fd\u6536\u5728\u8fd9\u91cc\u3002',
                style: TextStyle(
                  fontSize: 12,
                  color: LoveGirlTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        LoveIconButton(
          icon: Icons.timeline_rounded,
          tooltip: '\u65f6\u5149\u8f74',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimelineScreen()),
          ),
        ),
        const SizedBox(width: 10),
        LoveIconButton(
          icon: Icons.settings_outlined,
          tooltip: '\u8bbe\u7f6e',
          onTap: () => _openSettings(context),
        ),
      ],
    );
  }

  Widget _buildDataZone(
    BuildContext context,
    int loveDays,
    String? partnerName,
  ) {
    return LoveTicketCard(
      color: const Color(0xFFFFFBF8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.menu_book_rounded,
            title: '\u5173\u7cfb\u6863\u6848',
            color: LoveGirlTheme.primary,
          ),
          const SizedBox(height: 8),
          LoveMenuRow(
            icon: Icons.event_note_rounded,
            title: '\u7eaa\u5ff5\u65e5\u4e0e\u5012\u6570',
            value: '纪念日、倒数日和小约定放在同一个资料夹',
            color: LoveGirlTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnniversaryScreen()),
            ),
          ),
          const Divider(),
          LoveMenuRow(
            icon: Icons.link_rounded,
            title: '\u4f34\u4fa3\u7ed1\u5b9a',
            value: partnerName == null
                ? '\u8fd8\u6ca1\u6709\u7ed1\u5b9a\u4f34\u4fa3'
                : '\u5df2\u7ed1\u5b9a \u00b7 $partnerName',
            color: LoveGirlTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CoupleBindingScreen()),
            ),
          ),
          const Divider(),
          LoveMenuRow(
            icon: Icons.timeline_rounded,
            title: '\u65f6\u5149\u8f74',
            value:
                '\u628a\u7b2c $loveDays \u5929\u4ee5\u6765\u7684\u5c0f\u4e8b\u90fd\u6536\u8fdb\u53bb',
            color: LoveGirlTheme.secondary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TimelineScreen()),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStatPill(
                  icon: Icons.favorite_rounded,
                  label: '\u604b\u7231\u5929\u6570',
                  value: '$loveDays',
                  color: LoveGirlTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatPill(
                  icon: Icons.savings_rounded,
                  label: '\u7231\u5fc3\u8c46',
                  value: '$_beanBalance',
                  color: LoveGirlTheme.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatPill(
                  icon: Icons.emoji_events_outlined,
                  label: '\u6210\u5c31',
                  value: '$_achievementCount',
                  color: LoveGirlTheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionZone(BuildContext context, bool isAdmin) {
    return LoveTicketCard(
      color: LoveGirlTheme.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.collections_bookmark_rounded,
            title: '\u56de\u5fc6\u4e0e\u7ba1\u7406',
            color: LoveGirlTheme.primary,
          ),
          const SizedBox(height: 8),
          LoveMenuRow(
            icon: Icons.photo_library_outlined,
            title: '\u76f8\u518c\u4e0e\u56de\u5fc6\u7167\u7247',
            value:
                '\u628a\u597d\u770b\u7684\u7167\u7247\u7edf\u4e00\u6536\u8d77\u6765',
            color: LoveGirlTheme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PhotoScreen()),
            ),
          ),
          const Divider(),
          LoveMenuRow(
            icon: Icons.confirmation_number_outlined,
            title: '\u65c5\u884c\u7968\u6839',
            value:
                '\u67e5\u770b\u5730\u56fe\u3001\u8def\u7ebf\u548c\u6253\u5361\u56de\u5fc6',
            color: LoveGirlTheme.secondary,
            onTap: () => widget.onNavigateToTab?.call(1),
          ),
          const Divider(),
          LoveMenuRow(
            icon: Icons.settings_outlined,
            title: '\u8bbe\u7f6e',
            value: '\u504f\u597d\u3001\u6743\u9650\u4e0e\u8d26\u53f7',
            color: LoveGirlTheme.secondary,
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return LovePaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.info_outline_rounded,
            title: '\u7248\u672c\u4e0e\u8bca\u65ad',
            color: LoveGirlTheme.primary,
          ),
          const SizedBox(height: 8),
          LoveMenuRow(
            icon: Icons.sync_rounded,
            title: '\u68c0\u67e5\u66f4\u65b0',
            value: 'v${AppConstants.versionName} (${AppConstants.versionCode})',
            color: LoveGirlTheme.primary,
            onTap: () => manualCheckVersion(context),
          ),
          const Divider(),
          LoveMenuRow(
            icon: Icons.article_outlined,
            title: '\u67e5\u770b\u8fd0\u884c\u65e5\u5fd7',
            value: '\u8c03\u8bd5\u4e0e\u8bca\u65ad',
            color: LoveGirlTheme.textMuted,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogScreen()),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final Map<String, dynamic>? user;
  final String? partnerName;
  final int loveDays;
  final int beanBalance;
  final bool loading;

  const _ProfileHero({
    required this.user,
    required this.partnerName,
    required this.loveDays,
    required this.beanBalance,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = user?['nickname']?.toString();
    final avatar = user?['avatar']?.toString() ?? '';

    return LoveTicketCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      color: const Color(0xFFFFF7F1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        LovePill(
                          text: '\u5173\u7cfb\u8d44\u6599\u5939',
                          icon: Icons.folder_copy_outlined,
                          color: LoveGirlTheme.secondary,
                          background: LoveGirlTheme.secondarySoft,
                        ),
                        const Spacer(),
                        LovePill(
                          text: '$beanBalance \u7231\u5fc3\u8c46',
                          icon: Icons.savings_rounded,
                          color: LoveGirlTheme.accent,
                          background: const Color(0xFFFFF2E1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 116,
                          height: 74,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                top: 0,
                                child: _AvatarBubble(
                                  avatar: avatar,
                                  fallback: _firstChar(nickname, '\u6211'),
                                ),
                              ),
                              Positioned(
                                left: 48,
                                top: 0,
                                child: _AvatarBubble(
                                  fallback: _firstChar(partnerName, '\u5979'),
                                  tint: LoveGirlTheme.primarySoft,
                                ),
                              ),
                              Positioned(
                                left: 42,
                                top: 44,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: LoveGirlTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nickname?.isNotEmpty == true
                                    ? nickname!
                                    : '\u6211\u4eec',
                                style: const TextStyle(
                                  fontSize: 28,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: LoveGirlTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: LoveGirlTheme.textPrimary,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text:
                                          '\u6211\u4eec\u5728\u4e00\u8d77\u7684\u7b2c ',
                                    ),
                                    TextSpan(
                                      text: '$loveDays',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: LoveGirlTheme.primary,
                                      ),
                                    ),
                                    const TextSpan(text: ' \u5929'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(170),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: LoveGirlTheme.separator.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            partnerName == null
                                ? Icons.inventory_2_outlined
                                : Icons.verified_rounded,
                            size: 16,
                            color: partnerName == null
                                ? LoveGirlTheme.textMuted
                                : LoveGirlTheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loading
                                  ? '\u6b63\u5728\u6574\u7406\u4f60\u4eec\u7684\u5173\u7cfb\u6863\u6848'
                                  : partnerName == null
                                      ? '\u8fd8\u6ca1\u6709\u7ed1\u5b9a\u4f34\u4fa3\uff0c\u4f46\u56de\u5fc6\u5df2\u7ecf\u5148\u88ab\u597d\u597d\u6536\u8d77\u6765\u4e86'
                                      : '\u5df2\u7ed1\u5b9a \u00b7 \u53ea\u5c5e\u4e8e\u4f60\u4eec\u4e24\u4e2a',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: partnerName == null
                                    ? LoveGirlTheme.textSecondary
                                    : LoveGirlTheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LovePill(
            text: '$loveDays \u5929\u7684\u6545\u4e8b',
            icon: Icons.auto_stories_rounded,
            color: LoveGirlTheme.secondary,
            background: LoveGirlTheme.secondarySoft,
          ),
        ],
      ),
    );
  }

  String _firstChar(String? text, String fallback) {
    if (text == null || text.isEmpty) return fallback;
    return text.substring(0, 1);
  }
}

class _AvatarBubble extends StatelessWidget {
  final String? avatar;
  final String fallback;
  final Color tint;

  const _AvatarBubble({
    this.avatar,
    required this.fallback,
    this.tint = LoveGirlTheme.secondarySoft,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 34,
      backgroundColor: Colors.white,
      child: CircleAvatar(
        radius: 31,
        backgroundColor: tint,
        backgroundImage: (avatar != null && avatar!.isNotEmpty)
            ? NetworkImage(avatar!)
            : null,
        child: avatar == null || avatar!.isEmpty
            ? Text(
                fallback,
                style: const TextStyle(
                  color: LoveGirlTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: LoveGirlTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _CardTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: LoveGirlTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
