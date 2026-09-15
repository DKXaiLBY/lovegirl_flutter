import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/weather_widget.dart';
import '../feeding/feeding_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HomeProvider>().refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: LovePage(
        padding: EdgeInsets.zero,
        child: RefreshIndicator(
          onRefresh: home.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              _HomeHeader(
                loveDays: math.max(auth.loveDays, home.loveDays),
                beanBalance: home.beanBalance,
              ),
              const SizedBox(height: 18),
              if (home.error != null &&
                  (home.today == null || home.memory == null)) ...[
                _ErrorBanner(message: home.error!, onRetry: home.refresh),
                const SizedBox(height: 16),
              ],
              _TodayCareSection(
                today: home.today,
                onFeedingTap: () => _push(const FeedingScreen()),
                onTodoTap: () => widget.onNavigateToSubTab?.call(3, 0),
              ),
              const SizedBox(height: 18),
              _MemoryTicket(
                memory: home.memory,
                onTap: () => _push(const TimelineScreen()),
              ),
              const SizedBox(height: 18),
              _TravelTicket(
                preview: _typedMap(home.today?['travelPreview']),
                onTap: () => widget.onNavigateToTab?.call(1),
              ),
              const SizedBox(height: 18),
              _LifeSummaryTicket(
                today: home.today,
                onFinanceTap: () => widget.onNavigateToSubTab?.call(3, 1),
                onCourseTap: () => widget.onNavigateToSubTab?.call(3, 2),
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
  final int beanBalance;

  const _HomeHeader({
    required this.loveDays,
    required this.beanBalance,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('home_header'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackMetrics = constraints.maxWidth < 320;
          final metrics = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const WeatherWidget(compact: true),
              Container(
                width: 1,
                height: 42,
                color: LoveGirlTheme.separator,
              ),
              _BeanBadge(balance: beanBalance),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'LoveGirl',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 34,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: LoveGirlTheme.textPrimary,
                                ),
                              ),
                              SizedBox(width: 6),
                              Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(
                                  Icons.favorite_rounded,
                                  size: 16,
                                  color: LoveGirlTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: LoveGirlTheme.textSecondary,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      '\u6211\u4eec\u5728\u4e00\u8d77\u7684\u7b2c ',
                                ),
                                TextSpan(
                                  text: '$loveDays',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: LoveGirlTheme.primary,
                                  ),
                                ),
                                const TextSpan(text: ' \u5929 \u2665'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!stackMetrics) ...[
                    const SizedBox(width: 12),
                    metrics,
                  ],
                ],
              ),
              if (stackMetrics) ...[
                const SizedBox(height: 14),
                metrics,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BeanBadge extends StatelessWidget {
  final int balance;

  const _BeanBadge({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D9),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFF1D4B1)),
          ),
          child: const Center(child: _LoveBeanIcon(size: 22)),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$balance',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: LoveGirlTheme.textPrimary,
              ),
            ),
            const Text(
              '\u7231\u5fc3\u8c46',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: LoveGirlTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(width: 2),
        const Icon(
          Icons.chevron_right_rounded,
          size: 14,
          color: LoveGirlTheme.textMuted,
        ),
      ],
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
              safeMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
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

  const _TodayCareSection({
    required this.today,
    required this.onFeedingTap,
    required this.onTodoTap,
  });

  @override
  Widget build(BuildContext context) {
    final feed = _typedMap(today?['feed']);
    final todo = _typedMap(today?['todo']);
    final todoItems = (todo['items'] is List)
        ? (todo['items'] as List).map(_typedMap).toList()
        : const <Map<String, dynamic>>[];
    final feedingTitle = _asString(
      feed['title'],
      fallback: '\u829d\u829d\u6843\u6843',
    );
    final feedingShop = _asString(feed['shop'], fallback: '\u559c\u8336');
    final feedingStatus = _asString(
      feed['statusLabel'],
      fallback: '\u5f85\u63a5\u5355',
    );
    final feedingPrice = _money(_asDouble(feed['price'], fallback: 25));
    final feedingOperator =
        _asString(feed['operator'], fallback: '\u5927\u767d');
    final totalTodos = _positiveInt(todo['total'], fallback: 2);
    final activeTodos = _asInt(todo['active'], fallback: 1);

    return LoveTicketCard(
      key: const ValueKey('home_today_care'),
      color: const Color(0xFFFFFCF8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LoveStickerIcon(
                icon: Icons.favorite_outline_rounded,
                color: LoveGirlTheme.primary,
                size: 40,
                iconSize: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\u4eca\u5929\u8981\u7167\u987e\u7684\u4e8b',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '\u7231\u662f\u628a\u5c0f\u4e8b\uff0c\u653e\u5728\u5fc3\u4e0a \u2665',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: LoveGirlTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const _CareDecoration(),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 260;
              final feedingCard = _FeedingCareCard(
                shop: feedingShop,
                title: feedingTitle,
                status: feedingStatus,
                price: feedingPrice,
                operatorName: feedingOperator,
                onTap: onFeedingTap,
              );
              final todoCard = _TodoCareCard(
                totalTodos: totalTodos,
                activeTodos: activeTodos,
                items: todoItems,
                onTap: onTodoTap,
              );

              if (stacked) {
                return Column(
                  children: [
                    feedingCard,
                    const SizedBox(height: 10),
                    todoCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: feedingCard),
                  const SizedBox(width: 10),
                  Expanded(child: todoCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CareDecoration extends StatelessWidget {
  const _CareDecoration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      height: 74,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 8,
            child: Transform.rotate(
              angle: -0.12,
              child: Container(
                width: 46,
                height: 56,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFEFC),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: LoveGirlTheme.primary.withAlpha(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 2,
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.primary.withAlpha(90),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: LoveGirlTheme.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 8,
                        color: LoveGirlTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            bottom: 0,
            child: Container(
              width: 44,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFEAD9C8),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(14),
                  bottom: Radius.circular(6),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 10,
            child: _FlowerDot(
              size: 16,
              color: const Color(0xFFF5D6BD),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 24,
            child: _FlowerDot(
              size: 14,
              color: const Color(0xFFF7E4C8),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 10,
            child: _FlowerDot(
              size: 18,
              color: const Color(0xFFFFE3DD),
            ),
          ),
          Positioned(
            left: 40,
            bottom: 26,
            child: _FlowerDot(
              size: 14,
              color: const Color(0xFFF4EAD1),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 0,
            child: Transform.rotate(
              angle: -0.45,
              child: Container(
                width: 2,
                height: 30,
                decoration: BoxDecoration(
                  color: LoveGirlTheme.secondary.withAlpha(120),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          Positioned(
            left: 32,
            bottom: 0,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 2,
                height: 34,
                decoration: BoxDecoration(
                  color: LoveGirlTheme.secondary.withAlpha(140),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowerDot extends StatelessWidget {
  final double size;
  final Color color;

  const _FlowerDot({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

class _FeedingCareCard extends StatelessWidget {
  final String shop;
  final String title;
  final String status;
  final String price;
  final String operatorName;
  final VoidCallback onTap;

  const _FeedingCareCard({
    required this.shop,
    required this.title,
    required this.status,
    required this.price,
    required this.operatorName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        final productIcon = Container(
          width: compact ? 58 : 74,
          height: compact ? 58 : 92,
          decoration: BoxDecoration(
            color: LoveGirlTheme.primary.withAlpha(10),
            borderRadius: BorderRadius.circular(compact ? 16 : 18),
          ),
          child: const Center(
            child: Icon(
              Icons.local_drink_rounded,
              size: 34,
              color: LoveGirlTheme.primary,
            ),
          ),
        );
        final productInfo = Column(
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: compact ? 15 : 17,
                height: 1.25,
                fontWeight: FontWeight.w900,
                color: LoveGirlTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              shop,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                fontSize: 13,
                color: LoveGirlTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                price,
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 22 : 24,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: LoveGirlTheme.primary,
                ),
              ),
            ),
          ],
        );

        final actionButton = OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: LoveGirlTheme.primary,
            side: const BorderSide(color: LoveGirlTheme.primary),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 9 : 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '去看看',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );

        return Container(
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: LoveGirlTheme.separator),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '投喂她',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: _StatusChip(label: status)),
                ],
              ),
              SizedBox(height: compact ? 10 : 12),
              if (compact) ...[
                Center(child: productIcon),
                const SizedBox(height: 8),
                productInfo,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    productIcon,
                    const SizedBox(width: 12),
                    Expanded(child: productInfo),
                  ],
                ),
              SizedBox(height: compact ? 12 : 14),
              if (compact) ...[
                Text(
                  operatorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: actionButton),
              ] else
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.separator.withAlpha(110),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: LoveGirlTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            operatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: LoveGirlTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status == '待接单' ? '还在等你接单' : '已经在处理这份小心意',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: LoveGirlTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    actionButton,
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TodoCareCard extends StatelessWidget {
  final int totalTodos;
  final int activeTodos;
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  const _TodoCareCard({
    required this.totalTodos,
    required this.activeTodos,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayItems = items.isNotEmpty
        ? items.take(2).toList()
        : const [
            {'title': '\u63d0\u9192\u5979\u591a\u559d\u6c34', 'dueDate': ''},
            {'title': '\u7761\u524d\u8bb2\u6545\u4e8b', 'dueDate': '22:00'},
          ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LoveGirlTheme.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '待办清单',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$activeTodos/$totalTodos \u5b8c\u6210',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < displayItems.length; index++) ...[
            _TodoItemRow(
              title: _asString(displayItems[index]['title']),
              dueDate: _asString(displayItems[index]['dueDate']),
              completed: index < activeTodos,
            ),
            if (index != displayItems.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: LoveGirlTheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                '\u65b0\u589e\u4e00\u4ef6\u4e8b',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoItemRow extends StatelessWidget {
  final String title;
  final String dueDate;
  final bool completed;

  const _TodoItemRow({
    required this.title,
    required this.dueDate,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          completed
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 22,
          color: completed
              ? LoveGirlTheme.secondary.withAlpha(180)
              : LoveGirlTheme.textMuted.withAlpha(150),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: completed
                  ? LoveGirlTheme.textSecondary
                  : LoveGirlTheme.textPrimary,
            ),
          ),
        ),
        if (dueDate.isNotEmpty)
          Text(
            dueDate,
            style: const TextStyle(
              fontSize: 12,
              color: LoveGirlTheme.textMuted,
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LoveGirlTheme.primary.withAlpha(12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LoveGirlTheme.primary.withAlpha(60)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: LoveGirlTheme.primary,
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
      _asString(
        memory?['title'],
        fallback: '留一张回忆票根，把喜欢的小事存下来',
      ),
    );
    final subtitle = _asString(
      memory?['subtitle'],
      fallback:
          '\u628a\u4e00\u8d77\u8d70\u8fc7\u7684\u5730\u65b9\u3001\u8bf4\u8fc7\u7684\u8bdd\uff0c\u6162\u6162\u6536\u8fdb\u8fd9\u5f20\u7968\u6839\u91cc\u3002',
    );
    final eventDate = _asString(memory?['eventDate'], fallback: '2025-02-14');
    final location = _asString(
      memory?['location'],
      fallback: '\u676d\u5dde \u00b7 \u94b1\u5858\u6c5f\u8fb9',
    );
    final imageUrl = _memoryImageUrl(memory);

    return LoveTicketCard(
      key: const ValueKey('home_memory_ticket'),
      color: LoveGirlTheme.paperWarm,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 332;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LovePill(
                text: _relativeDayLabel(eventDate),
                icon: Icons.history_toggle_off_rounded,
                color: LoveGirlTheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                  color: LoveGirlTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: LoveGirlTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: LoveGirlTheme.textSecondary,
                ),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemoryPreviewCard(imageUrl: imageUrl),
                    const SizedBox(width: 14),
                    Expanded(child: content),
                  ],
                ),
                const SizedBox(height: 16),
                const LoveTicketDivider(axis: Axis.horizontal, length: 260),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: _MemoryDateRail(
                    eventDate: eventDate,
                    onTap: onTap,
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MemoryPreviewCard(imageUrl: imageUrl),
              const SizedBox(width: 14),
              Expanded(child: content),
              const SizedBox(width: 12),
              const LoveTicketDivider(length: 132),
              const SizedBox(width: 12),
              _MemoryDateRail(
                eventDate: eventDate,
                onTap: onTap,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryPreviewCard extends StatelessWidget {
  final String imageUrl;

  const _MemoryPreviewCard({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 108,
        height: 126,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7D8CB),
              Color(0xFFDADFEA),
            ],
          ),
        ),
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MemoryPreviewFallback(),
              )
            : const _MemoryPreviewFallback(),
      ),
    );
  }
}

class _MemoryPreviewFallback extends StatelessWidget {
  const _MemoryPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 34,
            color: const Color(0xFFB9C8DB).withAlpha(170),
          ),
        ),
        Positioned(
          right: -10,
          bottom: 12,
          child: Icon(
            Icons.location_city_rounded,
            size: 56,
            color: Colors.white.withAlpha(90),
          ),
        ),
        Positioned(
          left: 10,
          right: 10,
          bottom: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.waves_rounded,
                size: 20,
                color: Colors.white.withAlpha(170),
              ),
              const Spacer(),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(145),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 15,
                  color: LoveGirlTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryDateRail extends StatelessWidget {
  final String eventDate;
  final VoidCallback onTap;

  const _MemoryDateRail({
    required this.eventDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _yearText(eventDate),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: LoveGirlTheme.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _monthDayText(eventDate),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: LoveGirlTheme.primary,
              side: const BorderSide(color: LoveGirlTheme.primary),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '\u751f\u6210\u56de\u5fc6\u7968\u6839',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    final title =
        _asString(preview['title'], fallback: '\u65c5\u884c\u8ba1\u5212');
    final city =
        _asString(preview['city'], fallback: '\u53a6\u95e8\u4e4b\u65c5');
    final subtitle = _asString(
      preview['subtitle'],
      fallback: '\u4e00\u8d77\u53bb\u770b\u6d77\u5440\uff5e',
    );
    final startDate = _asString(preview['startDate'], fallback: '05.20');
    final endDate = _asString(preview['endDate'], fallback: '05.24');
    final duration = _asString(
      preview['duration'],
      fallback: '4 \u5929 3 \u665a',
    );
    final progress = _asString(
      preview['progress'],
      fallback: '\u5df2\u89c4\u5212 3/6',
    );
    final people = _asInt(preview['people'], fallback: 2);
    final travelLabel = title == '\u65c5\u884c\u8ba1\u5212'
        ? '\u51fa\u53d1\u8ba1\u5212'
        : title;

    final mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: LoveGirlTheme.secondary.withAlpha(16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            travelLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: LoveGirlTheme.secondary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          city,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: LoveGirlTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: LoveGirlTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFE8E0D9),
              child: Icon(Icons.person, size: 16),
            ),
            const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFF3DDD4),
              child: Icon(Icons.person_2_rounded, size: 16),
            ),
            Text(
              '$people \u4eba',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: LoveGirlTheme.textMuted,
              ),
            ),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 16,
                  color: LoveGirlTheme.secondary,
                ),
                SizedBox(width: 6),
                Text(
                  '\u8fdb\u884c\u4e2d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: LoveGirlTheme.separator.withAlpha(120),
            ),
          ),
          child: const Row(
            children: [
              SizedBox(width: 12),
              Icon(
                Icons.airplanemode_active_rounded,
                size: 16,
                color: LoveGirlTheme.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '把想去的地方慢慢串起来，出发的时候会更顺。',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: LoveGirlTheme.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 12),
            ],
          ),
        ),
      ],
    );

    final routeRail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$startDate - $endDate',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: LoveGirlTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          duration,
          style: const TextStyle(
            fontSize: 12,
            color: LoveGirlTheme.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 74,
          height: 6,
          decoration: BoxDecoration(
            color: LoveGirlTheme.separator,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 42,
            height: 6,
            decoration: BoxDecoration(
              color: LoveGirlTheme.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          progress,
          style: const TextStyle(
            fontSize: 12,
            color: LoveGirlTheme.textMuted,
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: LoveGirlTheme.secondary,
            side: BorderSide(
              color: LoveGirlTheme.secondary.withAlpha(120),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: const Text(
            '\u67e5\u770b\u8def\u7ebf',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            RotatedBox(
              quarterTurns: 1,
              child: LoveBarcode(
                width: 42,
                height: 18,
                color: LoveGirlTheme.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '\u65c5\u884c\n\u7968\u6839',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return LoveTicketCard(
      key: const ValueKey('home_travel_ticket'),
      color: const Color(0xFFFFFCF8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mainContent,
                const SizedBox(height: 14),
                const LoveTicketDivider(
                  axis: Axis.horizontal,
                  length: 260,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: routeRail),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: mainContent),
              const SizedBox(width: 12),
              const LoveTicketDivider(length: 164),
              const SizedBox(width: 12),
              SizedBox(width: 108, child: routeRail),
            ],
          );
        },
      ),
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
          accent: LoveGirlTheme.primary,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '\u603b\u652f\u51fa',
                      style: TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(totalSpent),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: LoveGirlTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '\u5269\u4f59\u9884\u7b97',
                      style: TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(remaining),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: LoveGirlTheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: onFinanceTap,
                      style: TextButton.styleFrom(
                        foregroundColor: LoveGirlTheme.textPrimary,
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
              const SizedBox(width: 10),
              const SizedBox(
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '\u5171 $totalCourses \u8282\u8bfe',
                    style: const TextStyle(
                      fontSize: 12,
                      color: LoveGirlTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: LoveGirlTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: LoveGirlTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 12,
                  color: LoveGirlTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: onCourseTap,
                style: TextButton.styleFrom(
                  foregroundColor: LoveGirlTheme.textPrimary,
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
          color: LoveGirlTheme.paper,
          padding: const EdgeInsets.all(16),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    financePanel,
                    const SizedBox(height: 14),
                    const LoveTicketDivider(
                      axis: Axis.horizontal,
                      length: 260,
                    ),
                    const SizedBox(height: 14),
                    coursePanel,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: financePanel),
                    const SizedBox(width: 14),
                    const LoveTicketDivider(length: 182),
                    const SizedBox(width: 14),
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
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: LoveGirlTheme.textPrimary,
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
      (_SliceData(0.26, const Color(0xFFFFF3E8))),
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

String _yearText(String value) {
  final date = _parseDate(value);
  return date == null ? '2025' : '${date.year}';
}

String _monthDayText(String value) {
  final date = _parseDate(value);
  if (date == null) return '02.14';
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month.$day';
}
