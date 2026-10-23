import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_dates.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../anniversary/anniversary_screen.dart';
import '../couple/couple_binding_screen.dart';
import '../profile/achievements_screen.dart';
import '../settings/settings_screen.dart';
import '../beans/beans_screen.dart';
import '../voucher/wish_voucher_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

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
    _loveDays = context.read<AuthProvider>().loveDays;
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
      backgroundColor: context.lgBg,
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
                loading: _loading,
              ),
              const SizedBox(height: 18),
              _buildDataZone(context, _partnerName),
              const SizedBox(height: 14),
              _buildFunctionZone(context),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '我们',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: context.lgTextPrimary,
                    ),
                  ),
                  SizedBox(width: 6),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: context.lgEmotion,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                '伴侣关系与账号设置',
                style: TextStyle(
                  fontSize: 12,
                  color: context.lgTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataZone(BuildContext context, String? partnerName) {
    return LovePaper(
      child: Column(
        children: [
          LoveMenuRow(
            icon: Icons.event_note_rounded,
            title: '纪念日',
            value: '重要日子与倒数',
            color: context.lgInk,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnniversaryScreen())),
          ),
          const Divider(height: 1),
          LoveMenuRow(
            icon: Icons.link_rounded,
            title: '伴侣绑定',
            value: partnerName == null ? '还没有绑定伴侣' : '已绑定 · $partnerName',
            color: context.lgInk,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CoupleBindingScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionZone(BuildContext context) {
    return LovePaper(
      child: Column(
        children: [
          LoveMenuRow(
            icon: Icons.savings_outlined,
            title: '爱心豆',
            value: '余额 $_beanBalance · 签到与流水',
            color: context.lgInk,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BeansScreen())),
          ),
          const Divider(height: 1),
          LoveMenuRow(
            icon: Icons.redeem_outlined,
            title: '愿望兑换券',
            value: '兑换两个人的小约定',
            color: context.lgInk,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WishVoucherScreen())),
          ),
          const Divider(height: 1),
          LoveMenuRow(
            icon: Icons.emoji_events_outlined,
            title: '成就',
            value: '$_achievementCount 项',
            color: context.lgInk,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AchievementsScreen())),
          ),
          const Divider(height: 1),
          LoveMenuRow(
            icon: Icons.settings_outlined,
            title: '设置',
            value: '资料、隐私、更新与诊断',
            color: context.lgInk,
            onTap: () => _openSettings(context),
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
  final bool loading;

  const _ProfileHero({
    required this.user,
    required this.partnerName,
    required this.loveDays,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = user?['nickname']?.toString();
    final avatar = user?['avatar']?.toString() ?? '';

    return LoveTicketCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      color: context.lgPaper,
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
                                  tint: context.lgPrimarySoft,
                                ),
                              ),
                              Positioned(
                                left: 42,
                                top: 44,
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: context.lgInk,
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
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nickname?.isNotEmpty == true
                                    ? nickname!
                                    : '\u6211\u4eec',
                                style: TextStyle(
                                  fontSize: 25,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: context.lgTextPrimary,
                                ),
                              ),
                              SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: context.lgTextPrimary,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text:
                                          '\u6211\u4eec\u5728\u4e00\u8d77\u7684\u7b2c ',
                                    ),
                                    TextSpan(
                                      text: '$loveDays',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: context.lgInk,
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
                      // v4.0：半透明白条换 paperWarm+细线（深色可读）
                      decoration: BoxDecoration(
                        color: context.lgPaperWarm,
                        borderRadius:
                            BorderRadius.circular(LoveGirlTheme.radiusLg),
                        border: Border.all(
                          color: context.lgCardBorder,
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
                                ? context.lgTextMuted
                                : LoveGirlTheme.secondary,
                          ),
                          SizedBox(width: 8),
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
                                    ? context.lgTextSecondary
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
  final Color? tint;

  const _AvatarBubble({
    this.avatar,
    required this.fallback,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 34,
      backgroundColor: context.lgPaper,
      child: CircleAvatar(
        radius: 31,
        backgroundColor: tint ?? context.lgSecondarySoft,
        backgroundImage: (avatar != null && avatar!.isNotEmpty)
            ? NetworkImage(avatar!)
            : null,
        child: avatar == null || avatar!.isEmpty
            ? Text(
                fallback,
                style: TextStyle(
                  color: context.lgTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
  }
}
