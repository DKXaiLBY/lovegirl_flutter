import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/daily_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/motion.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/weather_widget.dart';
import '../beans/beans_screen.dart';
import '../cooking/cooking_log_screen.dart';
import '../daily/daily_question_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../timeline/timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function(int tabIndex, int subTab)? onNavigateToSubTab;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.onNavigateToSubTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _partnerRecent = [];
  bool _partnerBound = false;

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
      }
    });
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
                      beanBalance: home.beanBalance,
                      onNavigateToTab: widget.onNavigateToTab,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_partnerBound) ...[
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
                  if (home.error != null &&
                      (home.today == null || home.memory == null)) ...[
                    _ErrorBanner(message: home.error!, onRetry: home.refresh),
                    const SizedBox(height: 16),
                  ],
                  StaggerIn(
                    index: 1,
                    child: _TodayCareSection(
                      today: home.today,
                      onFeedingTap: () => _push(const KitchenScreen()),
                      onTodoTap: () => widget.onNavigateToSubTab?.call(3, 0),
                      onTodoToggle: (id, complete) => context
                          .read<HomeProvider>()
                          .toggleTodo(id, complete: complete),
                    ),
                  ),
                  const SizedBox(height: 18),
                  StaggerIn(
                    index: 2,
                    child: _DailyQuestionTicket(onTap: () => _push(const DailyQuestionScreen())),
                  ),
                  const SizedBox(height: 18),
                  StaggerIn(
                    index: 3,
                    child: _MemoryTicket(
                      memory: home.memory,
                      onTap: () => _push(TimelineScreen()),
                      onGenerate: () => _showMemoryStubSheet(home.memory),
                    ),
                  ),
                  const SizedBox(height: 18),
                  StaggerIn(
                    index: 4,
                    child: _TravelTicket(
                      preview: _typedMap(home.today?['travelPreview']),
                      onTap: () => widget.onNavigateToTab?.call(1),
                    ),
                  ),
                  const SizedBox(height: 18),
                  StaggerIn(
                    index: 5,
                    child: _LifeSummaryTicket(
                      today: home.today,
                      onFinanceTap: () => widget.onNavigateToSubTab?.call(3, 1),
                      onCourseTap: () => widget.onNavigateToSubTab?.call(3, 2),
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

  void _showMemoryStubSheet(Map<String, dynamic>? memory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MemoryStubSheet(memory: memory),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final int loveDays;
  final int beanBalance;
  final void Function(int tabIndex)? onNavigateToTab;

  const _HomeHeader({
    required this.loveDays,
    required this.beanBalance,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('home_header'),
      // 两行结构：标题+天数 hero / 铃铛 → 天气 | 爱心豆，窄屏不再散成三行
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
              _BeanBadge(balance: beanBalance),
            ],
          ),
        ],
      ),
    );
  }
}

class _BellBadge extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateToTab;

  const _BellBadge({this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final unread = context.select(
        (NotificationProvider p) => p.unreadCount);
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
                  color: const Color(0xFFFBE3E3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFF1C9BC)),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 19,
                  color: Color(0xFFB85C38),
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
                    border: Border.all(color: Colors.white, width: 1.5),
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

class _BeanBadge extends StatelessWidget {
  final int balance;

  const _BeanBadge({required this.balance});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BeansScreen()),
      ),
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1D4B1)),
          ),
          child: const Center(child: _LoveBeanIcon(size: 22)),
        ),
        SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RollingNumber(
              value: balance,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: context.lgTextPrimary,
              ),
            ),
            Text(
              '\u7231\u5fc3\u8c46',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.lgTextMuted,
              ),
            ),
          ],
        ),
        const SizedBox(width: 2),
        Icon(
          Icons.chevron_right_rounded,
          size: 14,
          color: context.lgTextMuted,
        ),
      ],
      ),
    );
  }
}

class _LoveBeanIcon extends StatelessWidget {
  final double size;

  const _LoveBeanIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LoveBeanPainter()),
    );
  }
}

class _LoveBeanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final beanRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.72,
      height: size.height * 0.92,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.52);
    canvas.translate(-center.dx, -center.dy);

    final shadow = Paint()
      ..color = const Color(0xFFB96B2C).withAlpha(42)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(beanRect.shift(const Offset(0, 1.5)), shadow);

    final beanPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFD08E), Color(0xFFC7802E)],
      ).createShader(beanRect);
    canvas.drawOval(beanRect, beanPaint);

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFFA96324).withAlpha(150);
    canvas.drawOval(beanRect.deflate(0.7), edgePaint);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withAlpha(150);
    final highlightPath = Path()
      ..moveTo(size.width * 0.42, size.height * 0.25)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.42,
        size.width * 0.33,
        size.height * 0.58,
        size.width * 0.47,
        size.height * 0.74,
      );
    canvas.drawPath(highlightPath, highlight);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.lgInk.withAlpha(40)),
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
    final totalTodos = _positiveInt(todo['total'], fallback: 2);
    final activeTodos = _asInt(todo['active'], fallback: 1);

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
          badge: '$activeTodos/$totalTodos 完成',
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
    final badgeColor = switch (badgeTone) {
      _CareBadgeTone.ok => LoveGirlTheme.secondary,
      _CareBadgeTone.warn => LoveGirlTheme.orange,
      _CareBadgeTone.neutral => context.lgTextMuted,
    };
    return PressableScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.lgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.lgSeparator),
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
                              fontSize: 12,
                              color: context.lgTextMuted)),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge,
                    style: TextStyle(
                        color: badgeColor,
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
class _MemoryStubSheet extends StatelessWidget {
  final Map<String, dynamic>? memory;

  const _MemoryStubSheet({required this.memory});

  @override
  Widget build(BuildContext context) {
    final title = _localizedMemoryTitle(
      _asString(memory?['title'], fallback: '我们的一件小事'),
    );
    final subtitle = _asString(
      memory?['subtitle'],
      fallback: '把一起走过的地方、说过的话，慢慢收进这张票根里。',
    );
    final eventDate = _asString(memory?['eventDate'], fallback: '');
    final location = _asString(memory?['location'], fallback: '');
    final imageUrl = _memoryImageUrl(memory);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: LoveTicketCard(
        color: context.lgPaper,
        padding: const EdgeInsets.all(18),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LovePill(
                  text: '回忆票根 · MEMORY STUB',
                  icon: Icons.confirmation_number_outlined,
                  color: context.lgInk,
                ),
                SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: context.lgTextSecondary),
                ),
                SizedBox(height: 12),
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.lgPrimarySoft,
                          LoveGirlTheme.accent.withAlpha(90),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text('♥', style: TextStyle(fontSize: 34, color: context.lgInk)),
                    ),
                  ),
                SizedBox(height: 12),
                LoveTicketDivider(),
                SizedBox(height: 10),
                Row(
                  children: [
                    if (location.isNotEmpty)
                      Expanded(
                        child: Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: context.lgTextMuted),
                        ),
                      ),
                    Text(
                      eventDate,
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const LoveBarcode(width: 90, height: 34),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: LovePrimaryButton(
                    text: '去时光轴记录更多',
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TimelineScreen()));
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              top: 8,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: context.lgInk, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    color: context.lgPrimarySoft.withAlpha(200),
                  ),
                  child: Text('珍藏 ♥',
                      style: TextStyle(
                          color: context.lgInk,
                          fontWeight: FontWeight.w900,
                          fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TA 的近况：让"对方"在首页出现
class _PartnerRecentCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onTapCooking;
  final void Function(int)? onNavigateToTab;

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
        final first = visible.isNotEmpty ? visible.first['type']?.toString() : null;
        if (first == 'cooking') {
          onTapCooking();
        } else if (first == 'travel') {
          onNavigateToTab?.call(1);
        }
      },
      child: Container(
        key: const ValueKey('home_partner_recent'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.lgPaper,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          border: Border.all(color: context.lgSeparator),
          boxShadow: LoveGirlTheme.cardShadow(),
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
        decoration: BoxDecoration(
          color: context.lgPaperWarm,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          border: Border.all(color: context.lgSeparator),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.lgEmotion,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.quiz_rounded,
                  size: 20, color: Colors.white),
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
              decoration: BoxDecoration(
                color: context.lgBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.lgSeparator),
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
                      color: context.lgEmotion,
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
  final VoidCallback? onGenerate;

  const _MemoryTicket({
    required this.memory,
    required this.onTap,
    this.onGenerate,
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
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onGenerate ?? onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.lgInk,
              side: BorderSide(color: context.lgInk),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('生成票根',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800)),
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

class _TravelTicket extends StatelessWidget {
  final Map<String, dynamic> preview;
  final VoidCallback onTap;

  const _TravelTicket({
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _asString(preview['title'], fallback: '旅行计划');
    final city = _asString(preview['city'], fallback: '厦门之旅');
    final subtitle = _asString(
      preview['subtitle'],
      fallback: '一起去看海呀～',
    );
    final startDate = _asString(preview['startDate'], fallback: '');
    final endDate = _asString(preview['endDate'], fallback: '');
    final progress = _asString(preview['progress'], fallback: '');
    final people = _asInt(preview['people'], fallback: 2);
    final travelLabel = title == '旅行计划' ? '出发计划' : title;
    final dateRange = [
      if (startDate.isNotEmpty) startDate,
      if (endDate.isNotEmpty && endDate != startDate) endDate,
    ].join(' - ');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -8,
          left: 30,
          child: Opacity(
            opacity: context.lgIsDark ? 0.5 : 1,
            child: Transform.rotate(
              angle: -0.42,
              child: Image.asset('assets/images/deco/tape_sage_stripe.png',
                  width: 82, height: 22, fit: BoxFit.fill),
            ),
          ),
        ),
        LoveTicketCard(
      key: const ValueKey('home_travel_ticket'),
      color: context.lgSecondarySoft,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: context.lgSecondarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(Icons.travel_explore_rounded,
                    size: 22, color: LoveGirlTheme.secondary),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(travelLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: LoveGirlTheme.secondary)),
                  SizedBox(height: 2),
                  Text(city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: context.lgTextPrimary)),
                  SizedBox(height: 2),
                  Text(
                    [
                      subtitle,
                      if (dateRange.isNotEmpty) dateRange,
                      '$people 人',
                      if (progress.isNotEmpty) progress,
                    ].where((t) => t.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: context.lgTextMuted),
          ],
        ),
      ),
    )],
      );
  }
}

class _LifeSummaryTicket extends StatelessWidget {
  final Map<String, dynamic>? today;
  final VoidCallback onFinanceTap;
  final VoidCallback onCourseTap;

  const _LifeSummaryTicket({
    required this.today,
    required this.onFinanceTap,
    required this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final finance = _typedMap(today?['finance']);
    final course = _typedMap(today?['course']);
    final totalSpent = _asDouble(finance['totalSpent'], fallback: 1520);
    final remaining = _asDouble(finance['remaining'], fallback: 480);
    final title = _asString(
      course['title'],
      fallback: '\u8bbe\u8ba1\u5fc3\u7406\u5b66',
    );
    final time = _asString(course['time'], fallback: '14:00');
    final location = _asString(
      course['location'],
      fallback: '\u6559\u4e8c\u697c 302',
    );
    final weekday = _asString(course['weekday'], fallback: '\u5468\u56db');
    final totalCourses = _asInt(course['total'], fallback: 5);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 380;
        final financePanel = _LifePanel(
          icon: Icons.wallet_outlined,
          title: '\u672c\u6708\u5c0f\u8d26\u672c',
          accent: context.lgInk,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u603b\u652f\u51fa',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.lgTextMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      _money(totalSpent),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: context.lgInk,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      '\u5269\u4f59\u9884\u7b97',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.lgTextMuted,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      _money(remaining),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: LoveGirlTheme.secondary,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: onFinanceTap,
                      style: TextButton.styleFrom(
                        foregroundColor: context.lgTextPrimary,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        '\u53bb\u8bb0\u4e00\u7b14  \u203a',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 96,
                height: 110,
                child: Center(
                  child: _FinancePiePreview(),
                ),
              ),
            ],
          ),
        );
        final coursePanel = _LifePanel(
          icon: Icons.menu_book_outlined,
          title: '\u672c\u5468\u8bfe\u7a0b',
          accent: LoveGirlTheme.secondary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '\u660e\u5929 $weekday',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '\u5171 $totalCourses \u8282\u8bfe',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.lgTextMuted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                time,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: context.lgTextPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: context.lgTextPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                location,
                style: TextStyle(
                  fontSize: 12,
                  color: context.lgTextSecondary,
                ),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: onCourseTap,
                style: TextButton.styleFrom(
                  foregroundColor: context.lgTextPrimary,
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  '\u67e5\u770b\u8bfe\u8868  \u203a',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );

        return LoveTicketCard(
          key: const ValueKey('home_life_summary'),
          color: context.lgPaper,
          padding: const EdgeInsets.all(16),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    financePanel,
                    SizedBox(height: 14),
                    LoveTicketDivider(
                      axis: Axis.horizontal,
                      length: 260,
                    ),
                    SizedBox(height: 14),
                    coursePanel,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: financePanel),
                    SizedBox(width: 14),
                    LoveTicketDivider(length: 182),
                    SizedBox(width: 14),
                    Expanded(child: coursePanel),
                  ],
                ),
        );
      },
    );
  }
}

class _LifePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;

  const _LifePanel({
    required this.icon,
    required this.title,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: accent),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

class _FinancePiePreview extends StatelessWidget {
  const _FinancePiePreview();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FinancePiePainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _FinancePiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 6);
    final radius = size.width * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center.translate(0, 6), radius, shadowPaint);

    final slices = [
      (_SliceData(0.40, const Color(0xFFF5DCC2))),
      (_SliceData(0.34, const Color(0xFFD4D8B8))),
      (_SliceData(0.26, const Color(0xFFF4F4F5))),
    ];

    var start = -1.85;
    for (final slice in slices) {
      final sweep = 3.141592653589793 * 2 * slice.fraction;
      final paint = Paint()..color = slice.color;
      canvas.drawArc(rect, start, sweep, true, paint);
      start += sweep;
    }

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withAlpha(180);
    start = -1.85;
    for (final slice in slices) {
      final sweep = 3.141592653589793 * 2 * slice.fraction;
      canvas.drawArc(rect, start, sweep, true, strokePaint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SliceData {
  final double fraction;
  final Color color;

  const _SliceData(this.fraction, this.color);
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

int _positiveInt(dynamic value, {int fallback = 1}) {
  final parsed = _asInt(value, fallback: fallback);
  return parsed <= 0 ? fallback : parsed;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _money(double value) {
  final whole = value == value.roundToDouble();
  return whole
      ? '\u00a5${value.toStringAsFixed(0)}'
      : '\u00a5${value.toStringAsFixed(2)}';
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
    final displayRows = rows.isNotEmpty
        ? rows
        : const [
            {'id': 0, 'title': '提醒她多喝水', 'dueDate': ''},
            {'id': 0, 'title': '睡前讲故事', 'dueDate': '22:00'},
          ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.lgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.lgSeparator),
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
                  decoration: BoxDecoration(
                    color: (allDone
                            ? LoveGirlTheme.secondary
                            : context.lgTextMuted)
                        .withAlpha(26),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge,
                      style: TextStyle(
                          color: allDone
                              ? LoveGirlTheme.secondary
                              : context.lgTextMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: context.lgTextMuted),
              ],
            ),
          ),
          for (final row in displayRows)
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
                color:
                    _done ? context.lgTextMuted : context.lgTextPrimary,
                decoration:
                    _done ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
          ),
          if (widget.dueDate.isNotEmpty)
            Text(widget.dueDate,
                style: TextStyle(
                    fontSize: 12, color: context.lgTextMuted)),
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
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * ringProgress,
        false,
        ringPaint);

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

