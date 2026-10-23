import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/daily_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/travel_provider.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/motion.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/weather_widget.dart';
import '../cooking/cooking_log_screen.dart';
import '../photo/photo_screen.dart';
import '../daily/daily_question_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../anniversary/anniversary_screen.dart';
import '../life/life_screen.dart';
import '../life/widgets/todo_list.dart';
import '../../utils/app_section.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<AppSection>? onNavigateToTab;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _partnerRecent = [];
  bool _partnerBound = false;
  Map<String, dynamic>? _memoryToday; // W5 弹药库 7.3/10.2：N 年前的今天

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HomeProvider>().refresh();
        context.read<NotificationProvider>().refreshCount();
        context.read<DailyProvider>().refresh();
        _loadPartnerRecent();
        _loadMemoryToday();
      }
    });
  }

  /// W5「N 年前的今天」回忆卡（白卡+蜜桃点缀；不进渐变白名单；X 关闭当天不再出现）
  Widget _buildMemoryTodayCard() {
    final m = _memoryToday!;
    final years = m['years'] as int;
    final isPhoto = m['type'] == 'photo';
    final title = (m['title'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: context.lgCard,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          onTap: () {
            _dismissMemoryToday();
            if (isPhoto) {
              _push(const PhotoScreen());
            } else {
              widget.onNavigateToTab?.call(AppSection.travel);
            }
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
              border: Border(
                  left: BorderSide(color: LoveGirlTheme.peach, width: 3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.peach.withAlpha(28),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_rounded,
                      size: 22, color: LoveGirlTheme.peach),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$years 年前的今天',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: LoveGirlTheme.peachText)),
                      const SizedBox(height: 2),
                      Text(
                        title.isEmpty
                            ? (isPhoto ? '我们拍下过一张照片' : '我们去过一个地方')
                            : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: context.lgTextPrimary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: context.lgTextMuted),
                  onPressed: _dismissMemoryToday,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// W5「N 年前的今天」：轻量拉取照片+足迹，命中则渲染回忆卡（失败/无命中零痕迹）
  Future<void> _loadMemoryToday() async {
    List<Map<String, dynamic>> photos = const [];
    List<TravelSpot> spots = const [];
    try {
      final res = await ApiService().getPhotos();
      final d = res.data?['data'];
      if (d is List) {
        photos = d.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    try {
      final res = await ApiService().getTravelSpots();
      final d = res.data?['data'];
      final rawList = d is List ? d : (d is Map ? d['list'] as List? : null);
      if (rawList != null) {
        spots = rawList
            .map((e) => TravelSpot.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final now = DateTime.now();
    final todayKey =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    if (prefs.getString('memory_dismiss_last') == todayKey) return;
    final m = pickMemoryToday(photos, spots, now);
    if (m == null || !mounted) return;
    setState(() => _memoryToday = m);
  }

  Future<void> _dismissMemoryToday() async {
    final now = DateTime.now();
    final key =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('memory_dismiss_last', key);
    if (mounted) setState(() => _memoryToday = null);
  }

  Future<void> _loadPartnerRecent() async {
    try {
      final res = await ApiService().getPartnerRecent();
      final d = res.data?['data'];
      if (!mounted) return;
      setState(() {
        _partnerBound = d?['hasPartner'] == true;
        _partnerRecent = (d?['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 从后台切回时刷新角标/每日一问（对方可能刚产生了新动态）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationProvider>().refreshCount();
      context.read<DailyProvider>().refresh();
      _loadPartnerRecent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: context.lgBg,
      body: LovePage(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: home.refresh,
          child: (home.isLoading && home.today == null)
              ? const HomeSkeleton()
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    StaggerIn(
                      index: 0,
                      child: _HomeHeader(
                        loveDays: math.max(auth.loveDays, home.loveDays),
                        onNavigateToTab: widget.onNavigateToTab,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_memoryToday != null) ...[
                      _buildMemoryTodayCard(),
                      const SizedBox(height: 14),
                    ],
                    if (_partnerBound && _partnerRecent.isNotEmpty) ...[
                      StaggerIn(
                        index: 0,
                        child: _PartnerRecentCard(
                          items: _partnerRecent,
                          onTapCooking: () => _push(const CookingLogScreen()),
                          onNavigateToTab: widget.onNavigateToTab,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (home.error != null) ...[
                      _ErrorBanner(message: home.error!, onRetry: home.refresh),
                      const SizedBox(height: 16),
                    ],
                    StaggerIn(
                      index: 1,
                      child: _TodayCareSection(
                        today: home.today,
                        onFeedingTap: () => _push(const KitchenScreen()),
                        onTodoTap: () => _push(const LifeToolScreen(
                            title: '待办', child: TodoListWidget())),
                        onTodoToggle: (id, complete) => context
                            .read<HomeProvider>()
                            .toggleTodo(id, complete: complete),
                      ),
                    ),
                    if (home.today?['anniversary'] is Map) ...[
                      const SizedBox(height: 14),
                      LoveMenuRow(
                        icon: Icons.event_outlined,
                        title: home.today!['anniversary']['title'].toString(),
                        value: home.today!['anniversary']['days'] == 0
                            ? '就是今天'
                            : '还有 ${home.today!['anniversary']['days']} 天',
                        color: context.lgInk,
                        onTap: () => _push(const AnniversaryScreen()),
                      ),
                    ],
                    const SizedBox(height: 18),
                    StaggerIn(
                      index: 2,
                      child: _DailyQuestionTicket(
                          onTap: () => _push(const DailyQuestionScreen())),
                    ),
                    const SizedBox(height: 18),
                    if (_memoryToday == null && home.memory?.isNotEmpty == true)
                      StaggerIn(
                        index: 3,
                        child: _MemoryTicket(
                          memory: home.memory,
                          onTap: () =>
                              widget.onNavigateToTab?.call(AppSection.memories),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _HomeHeader extends StatelessWidget {
  final int loveDays;
  final ValueChanged<AppSection>? onNavigateToTab;

  const _HomeHeader({
    required this.loveDays,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('home_header'),
      // v4.0 浅灰渐变 hero（渐变白名单三处之一，接替 gradientSunrise；
      // 深色态维持 primarySoftDark 单色不上渐变）
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.lgPrimarySoft,
          gradient: context.lgIsDark
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: LoveGirlTheme.surfaceGradient,
                ),
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusXl),
        ),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'LoveGirl',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 30,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: context.lgTextPrimary,
                            ),
                          ),
                          SizedBox(width: 6),
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 15,
                              color: context.lgEmotion,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // 数字层级：恋爱天数是整屏视觉锚点（清爽化 v2 数字 hero）
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '我们在一起的第 ',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.lgTextSecondary,
                              ),
                            ),
                            RollingNumber(
                              value: loveDays,
                              style: TextStyle(
                                fontSize: 38,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                color: context.lgEmotion,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '天',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.lgTextSecondary,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 13,
                                color: context.lgEmotion,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                _BellBadge(onNavigateToTab: onNavigateToTab),
              ],
            ),
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: WeatherWidget(compact: true),
                  ),
                ),
              ],
            ),
          ],
        ), // Column 收尾
      ), // Container（日出 hero）收尾
    );
  }
}

class _BellBadge extends StatelessWidget {
  final ValueChanged<AppSection>? onNavigateToTab;

  const _BellBadge({this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final unread = context.select((NotificationProvider p) => p.unreadCount);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              NotificationCenterScreen(onNavigateToTab: onNavigateToTab))),
      child: SizedBox(
        height: 42,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.lgCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.lgSeparator),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 19,
                  color: context.lgInk,
                ),
              ),
            ),
            if (unread > 0)
              Positioned(
                top: -2,
                right: -4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.red,
                    borderRadius: BorderRadius.circular(10),
                    // 角标白圈随卡片底（深色跟随 cardDark，不再突兀白环）
                    border: Border.all(color: context.lgCard, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
    final safeMessage = _sanitizeNetworkMessage(message);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // v4.0：底随主题（原 Colors.white 硬编码深色不破），细线描边对齐卡片体系
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgCardBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: context.lgInk,
            size: 18,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              safeMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.lgTextSecondary,
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

String _sanitizeNetworkMessage(String message) {
  if (message.contains('DioException') ||
      message.contains('HttpException') ||
      message.contains('Connection closed before full header was received') ||
      message.contains('connection error')) {
    return '网络有点不稳定，刚刚有一部分内容没加载出来。';
  }
  return message;
}

class _TodayCareSection extends StatelessWidget {
  final Map<String, dynamic>? today;
  final VoidCallback onFeedingTap;
  final VoidCallback onTodoTap;
  final void Function(int id, bool complete)? onTodoToggle;

  const _TodayCareSection({
    required this.today,
    required this.onFeedingTap,
    required this.onTodoTap,
    this.onTodoToggle,
  });

  @override
  Widget build(BuildContext context) {
    final feed = _typedMap(today?['feed']);
    final todo = _typedMap(today?['todo']);
    final todoItems = (todo['items'] is List)
        ? (todo['items'] as List).map(_typedMap).toList()
        : const <Map<String, dynamic>>[];
    final totalTodos = _asInt(todo['total']).clamp(0, 1 << 30);
    final activeTodos = _asInt(todo['active']).clamp(0, totalTodos);
    final completedTodos = totalTodos - activeTodos;

    // v3.23 清单化重设计：两个横向条目（厨房/待办），高度减半信息密度更高
    final badge = feed['statusLabel']?.toString() ?? '还没点单';
    final careEntries = Column(
      key: const ValueKey('home_today_care'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('今天要照顾的事',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: context.lgTextPrimary)),
        ),
        if (feed['hasActiveOrder'] == true)
          _CareEntry(
            emoji: '🍳',
            title: '情侣厨房',
            badge: badge,
            badgeTone:
                badge == '还没点单' ? _CareBadgeTone.warn : _CareBadgeTone.ok,
            subtitle: feed['title']?.toString(),
            onTap: onFeedingTap,
          ),
        const SizedBox(height: 10),
        _TodoCareTile(
          badge: totalTodos == 0 ? '暂无待办' : '$completedTodos/$totalTodos 完成',
          allDone: activeTodos == 0,
          rows: todoItems
              .map((item) => {
                    'id': (item['id'] as num?)?.toInt() ?? 0,
                    'title': _asString(item['title']),
                    'dueDate': _asString(item['dueDate']),
                  })
              .toList(),
          onTap: onTodoTap,
          onToggle: onTodoToggle,
        ),
      ],
    );
    return careEntries;
  }
}

/// 清单条目（首页"今天要照顾的事"）
enum _CareBadgeTone { ok, warn, neutral }

class _CareEntry extends StatelessWidget {
  final String? emoji;
  final String title;
  final String badge;
  final _CareBadgeTone badgeTone;
  final String? subtitle;
  final VoidCallback onTap;

  const _CareEntry({
    this.emoji,
    required this.title,
    required this.badge,
    required this.badgeTone,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // v4.0 状态徽章语义浅底（深色走 primarySoftDark+浅 fg，参考图⑥）
    final (badgeBg, badgeFg) = switch (badgeTone) {
      _CareBadgeTone.ok => (context.lgSoftGreenBg, context.lgSoftGreenText),
      _CareBadgeTone.warn => (context.lgSoftYellowBg, context.lgSoftYellowText),
      _CareBadgeTone.neutral => (context.lgBadgeBg, context.lgBadgeText),
    };
    return PressableScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.lgCard,
            borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
            border: Border.all(color: context.lgCardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.lgPrimarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: emoji != null
                      ? Text(emoji!, style: const TextStyle(fontSize: 20))
                      : Icon(Icons.star_rounded,
                          size: 20, color: context.lgInk),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: context.lgTextPrimary)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: context.lgTextMuted)),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge,
                    style: TextStyle(
                        color: badgeFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.lgTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// TA 的近况：让"对方"在首页出现
class _PartnerRecentCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onTapCooking;
  final ValueChanged<AppSection>? onNavigateToTab;

  const _PartnerRecentCard({
    required this.items,
    required this.onTapCooking,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final visible = items.take(2).toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 点击优先跳最近动态对应页；无动态进手账
        final first =
            visible.isNotEmpty ? visible.first['type']?.toString() : null;
        if (first == 'cooking') {
          onTapCooking();
        } else if (first == 'travel') {
          onNavigateToTab?.call(AppSection.travel);
        }
      },
      child: Container(
        key: const ValueKey('home_partner_recent'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // v4.0：1px 细线替代阴影（参考图②）
        decoration: BoxDecoration(
          color: context.lgPaper,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          border: Border.all(color: context.lgCardBorder),
        ),
        child: visible.isEmpty
            ? Row(
                children: [
                  Icon(Icons.favorite_outline,
                      size: 15, color: context.lgEmotion),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TA 还没有新动态，去记一道今天的菜吧',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.lgTextSecondary,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded,
                          size: 13, color: context.lgEmotion),
                      const SizedBox(width: 5),
                      Text(
                        'TA 的近况',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.lgEmotion,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  for (final item in visible) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Icon(
                            item['type'] == 'cooking'
                                ? Icons.restaurant_rounded
                                : item['type'] == 'travel'
                                    ? Icons.map_rounded
                                    : Icons.quiz_outlined,
                            size: 13,
                            color: context.lgTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['text']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.lgTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// 每日一问入口卡：状态三态（待作答 / 等 TA / 已揭晓）
class _DailyQuestionTicket extends StatelessWidget {
  final VoidCallback onTap;

  const _DailyQuestionTicket({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final daily = context.watch<DailyProvider>();
    final t = daily.today;

    final String status;
    final IconData statusIcon;
    if (t == null) {
      status = '看看今天的问题';
      statusIcon = Icons.campaign_outlined;
    } else if (t.myAnswer == null) {
      status = '去作答';
      statusIcon = Icons.edit_rounded;
    } else if (!t.bothAnswered) {
      status = '等 TA 揭晓';
      statusIcon = Icons.hourglass_top_rounded;
    } else {
      status = '已揭晓';
      statusIcon = Icons.auto_awesome_rounded;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        key: const ValueKey('home_daily_question'),
        padding: const EdgeInsets.all(16),
        // v4.0：纯白卡+细线描边（阴影≈0，立体感交描边）
        decoration: BoxDecoration(
          color: context.lgPaper,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          border: Border.all(color: context.lgCardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              // v4.0 黑底座图标：深色态用米白底+深色图标（原白图标对浅底对比度塌陷）
              decoration: BoxDecoration(
                color: context.lgEmotion,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.quiz_rounded,
                  size: 20,
                  color:
                      context.lgIsDark ? LoveGirlTheme.bgDark : Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '每日一问',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (t != null && t.streakCurrent > 0) ...[
                        Icon(Icons.local_fire_department_rounded,
                            size: 13, color: LoveGirlTheme.orange),
                        const SizedBox(width: 2),
                        Text(
                          '连续${t.streakCurrent}天',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: LoveGirlTheme.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t?.question ?? '两个人每天答一题，都提交后才互相揭晓',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.lgTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              // v4.0：状态胶囊走中性徽章体系（lgBadgeBg 深色安全）
              decoration: BoxDecoration(
                color: context.lgBadgeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 13, color: context.lgEmotion),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.lgInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryTicket extends StatelessWidget {
  final Map<String, dynamic>? memory;
  final VoidCallback onTap;

  const _MemoryTicket({
    required this.memory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _localizedMemoryTitle(
      _asString(memory?['title'], fallback: '留一张回忆票根'),
    );
    final eventDate = _asString(memory?['eventDate'], fallback: '');
    final location = _asString(memory?['location'], fallback: '');
    final imageUrl = _memoryImageUrl(memory);
    final dateLabel = eventDate.isEmpty ? '' : _relativeDayLabel(eventDate);

    return LoveTicketCard(
      key: const ValueKey('home_memory_ticket'),
      color: context.lgPaperWarm,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _memPlaceholder())
                  : _memPlaceholder(),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.lgTextPrimary)),
                SizedBox(height: 3),
                Text(
                  [
                    if (dateLabel.isNotEmpty) dateLabel,
                    if (location.isNotEmpty) location,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.lgTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.lgInk,
              side: BorderSide(color: context.lgInk),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('查看回忆',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _memPlaceholder() => Image.asset(
        'assets/images/icons/placeholder_memory.png',
        fit: BoxFit.cover,
      );
}

Map<String, dynamic> _typedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  return const {};
}

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _localizedMemoryTitle(String value) {
  const moodMap = {
    'excited': '那天很期待',
    'happy': '那天很开心',
    'sad': '那天有点低落',
    'angry': '那天有点生气',
    'tired': '那天有点累',
    'calm': '那天很平静',
    'romantic': '那天很浪漫',
    'neutral': '那天很普通',
  };
  return moodMap[value.toLowerCase()] ?? value;
}

String _memoryImageUrl(Map<String, dynamic>? memory) {
  if (memory == null) return '';
  const keys = [
    'imageUrl',
    'image_url',
    'photoUrl',
    'photo_url',
    'cover',
    'coverUrl',
  ];
  for (final key in keys) {
    final value = memory[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _parseDate(String value) {
  if (value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String _relativeDayLabel(String value) {
  final date = _parseDate(value);
  if (date == null) {
    return '\u628a\u559c\u6b22\u7684\u5c0f\u4e8b\uff0c\u5b58\u6210\u4e00\u5f20\u7968\u6839';
  }
  final today = DateTime.now();
  final diff =
      today.difference(DateTime(date.year, date.month, date.day)).inDays;
  if (diff <= 0) return '\u4eca\u5929\u4e5f\u503c\u5f97\u7559\u4e0b\u6765';
  if (diff == 1) return '\u6628\u5929\u7684\u8fd9\u4e00\u5929';
  if (diff < 30) return '$diff \u5929\u524d\u7684\u4eca\u5929';
  final months = diff ~/ 30;
  if (months < 12) return '$months \u4e2a\u6708\u524d\u7684\u4eca\u5929';
  final years = diff ~/ 365;
  return '$years \u5e74\u524d\u7684\u4eca\u5929';
}

/// 待办清单条目（内联待办行：圆圈点击直接切换，DRAW 勾选动画）
class _TodoCareTile extends StatelessWidget {
  final String badge;
  final bool allDone;
  final List<Map<String, dynamic>> rows;
  final VoidCallback onTap;
  final void Function(int id, bool complete)? onToggle;

  const _TodoCareTile({
    required this.badge,
    required this.allDone,
    required this.rows,
    required this.onTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.lgCard,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.lgPrimarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(Icons.checklist_rounded,
                        size: 20, color: context.lgInk),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('待办清单',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: context.lgTextPrimary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  // v4.0 状态徽章：完成=绿族浅底，未完=中性浅灰（getter 深色安全）
                  decoration: BoxDecoration(
                    color: allDone ? context.lgSoftGreenBg : context.lgBadgeBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          color: allDone
                              ? context.lgSoftGreenText
                              : context.lgBadgeText,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: context.lgTextMuted),
              ],
            ),
          ),
          for (final row in rows)
            _HomeTodoRow(
              id: (row['id'] as num?)?.toInt() ?? 0,
              title: (row['title'] ?? '').toString(),
              dueDate: (row['dueDate'] ?? '').toString(),
              onToggle: onToggle == null
                  ? null
                  : (complete) =>
                      onToggle!((row['id'] as num?)?.toInt() ?? 0, complete),
            ),
        ],
      ),
    );
  }
}

/// 首页待办行：圆圈点击直接切换完成（DRAW 描边动画）
class _HomeTodoRow extends StatefulWidget {
  final int id;
  final String title;
  final String dueDate;
  final void Function(bool complete)? onToggle;

  const _HomeTodoRow({
    required this.id,
    required this.title,
    required this.dueDate,
    this.onToggle,
  });

  @override
  State<_HomeTodoRow> createState() => _HomeTodoRowState();
}

class _HomeTodoRowState extends State<_HomeTodoRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.id == 0 || widget.onToggle == null) return;
    setState(() => _done = !_done);
    if (_done) {
      _ctrl.forward(from: 0);
      HapticFeedback.selectionClick();
    }
    widget.onToggle!(_done);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: SizedBox(
              width: 26,
              height: 26,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  final p = _ctrl.value;
                  if (_done && p >= 1) {
                    return const Icon(Icons.check_circle_rounded,
                        size: 22, color: LoveGirlTheme.secondary);
                  }
                  return CustomPaint(
                    painter: _CheckDrawPainter(
                        progress: p, color: LoveGirlTheme.secondary),
                    child: p == 0
                        ? Icon(Icons.radio_button_unchecked,
                            size: 20, color: context.lgTextMuted)
                        : const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: _done ? context.lgTextMuted : context.lgTextPrimary,
                decoration:
                    _done ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          ),
          if (widget.dueDate.isNotEmpty)
            Text(widget.dueDate,
                style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
        ],
      ),
    );
  }
}

class _CheckDrawPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckDrawPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;

    final ringProgress = (progress / 0.6).clamp(0.0, 1.0);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, 2 * math.pi * ringProgress, false, ringPaint);

    if (progress > 0.6) {
      final checkProgress = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
      final p1 = Offset(center.dx - radius * 0.45, center.dy + radius * 0.05);
      final p2 = Offset(center.dx - radius * 0.1, center.dy + radius * 0.4);
      final p3 = Offset(center.dx + radius * 0.5, center.dy - radius * 0.35);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);
      final metrics = path.computeMetrics().toList();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = color;
      var drawn = 0.0;
      for (final metric in metrics) {
        final target = metric.length * checkProgress;
        if (target <= drawn) break;
        canvas.drawPath(
            metric.extractPath(0, (target - drawn).clamp(0.0, metric.length)),
            paint);
        drawn += metric.length;
      }
    }
  }

  @override
  bool shouldRepaint(_CheckDrawPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// W5 弹药库 7.3/10.2：确定性挑选「N 年前的今天」（年最远优先→照片优先→id 升序；
/// photo_date 空用 created_at 兜底；候选年 ≥ 当年跳过）
Map<String, dynamic>? pickMemoryToday(
    List<Map<String, dynamic>> photos, List<TravelSpot> spots, DateTime now) {
  DateTime? parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.length < 10) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T')) ??
        DateTime.tryParse(s.substring(0, 10));
  }

  final candidates = <Map<String, dynamic>>[];
  for (final p in photos) {
    final d = parseDate(p['photo_date'] ?? p['created_at']);
    if (d == null || !d.isBefore(now)) continue;
    if (d.month != now.month || d.day != now.day) continue;
    candidates.add({
      'type': 'photo',
      'date': d,
      'id': (p['id'] as num?)?.toInt() ?? 0,
      'title': p['description']?.toString() ?? '',
    });
  }
  for (final s in spots) {
    final d = parseDate(s.visitedDate);
    if (d == null || !d.isBefore(now)) continue;
    if (d.month != now.month || d.day != now.day) continue;
    candidates.add({
      'type': 'travel',
      'date': d,
      'id': s.id,
      'title': s.name,
    });
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final ya = (a['date'] as DateTime).year;
    final yb = (b['date'] as DateTime).year;
    if (ya != yb) return ya.compareTo(yb);
    final pa = a['type'] == 'photo' ? 0 : 1;
    final pb = b['type'] == 'photo' ? 0 : 1;
    if (pa != pb) return pa.compareTo(pb);
    return (a['id'] as int).compareTo(b['id'] as int);
  });
  final c = candidates.first;
  final years = now.year - (c['date'] as DateTime).year;
  return {
    'type': c['type'],
    'years': years,
    'id': c['id'],
    'title': c['title'],
  };
}
