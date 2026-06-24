import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/travel_form_screen.dart';
import 'package:lovegirl_flutter/widgets/travel_map_widget.dart';
import 'package:lovegirl_flutter/widgets/organic_ui.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

/// 旅行主页——有机形态UI重写
/// 上半部：地图（OrganicCard包裹） + 下半部：有机风格地点列表
class TravelMainScreen extends StatefulWidget {
  const TravelMainScreen({super.key});

  @override
  State<TravelMainScreen> createState() => _TravelMainScreenState();
}

class _TravelMainScreenState extends State<TravelMainScreen> {
  final GlobalKey<TravelMapWidgetState> _mapKey = GlobalKey();
  final ScrollController _listScrollCtrl = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TravelProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _listScrollCtrl.dispose();
    super.dispose();
  }

  void _onMarkerTap(TravelSpot spot) {
    final provider = context.read<TravelProvider>();
    provider.highlightSpot(spot.id);

    // 地图动画滑动到标记
    _mapKey.currentState?.animateToSpot(spot);

    // 滚动列表到对应项
    _scrollToItem(spot.id);
  }

  void _scrollToItem(int spotId) {
    final key = _itemKeys[spotId];
    if (key == null || key.currentContext == null) return;

    final box = key.currentContext!.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final pos = box.localToGlobal(Offset.zero);
    final scrollOffset = _listScrollCtrl.offset + pos.dy - 100;

    _listScrollCtrl.animateTo(
      scrollOffset.clamp(0.0, _listScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );

    // 2秒后取消高亮
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<TravelProvider>().highlightSpot(null);
      }
    });
  }

  void _openForm(BuildContext context, {TravelSpot? spot}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TravelFormScreen(spot: spot),
      ),
    );
    if (mounted) {
      context.read<TravelProvider>().highlightSpot(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TravelProvider>(
      builder: (context, provider, _) {
        _rebuildItemKeys(provider.filteredSpots);

        return Scaffold(
          backgroundColor: LoveGirlTheme.bgLight,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshAll(),
              child: CustomScrollView(
                slivers: [
                  // ======== 地图区域（有机卡片包裹） ========
                  SliverToBoxAdapter(child: _buildMapSection(provider)),

                  // ======== 波浪装饰分隔线 ========
                  SliverToBoxAdapter(child: _buildWavyDivider()),

                  // ======== 统计卡片行（4个有机小卡片） ========
                  SliverToBoxAdapter(child: _buildStatsRow(provider)),

                  // ======== 有机筛选器（波浪形手绘按钮） ========
                  SliverToBoxAdapter(child: _buildOrganicFilter(provider)),

                  // ======== 地点列表 ========
                  if (provider.loading && provider.spots.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.filteredSpots.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(provider),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final spot = provider.filteredSpots[index];
                            return _buildSpotCard(spot, provider);
                          },
                          childCount: provider.filteredSpots.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: _buildOrganicFab(),
        );
      },
    );
  }

  void _rebuildItemKeys(List<TravelSpot> spots) {
    _itemKeys.clear();
    for (final spot in spots) {
      _itemKeys[spot.id] = GlobalKey();
    }
  }

  // ==================== 地图区域（无边全景） ====================

  Widget _buildMapSection(TravelProvider provider) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.44;

    return SizedBox(
      height: mapHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 地图本身——全宽无边
          TravelMapWidget(
            key: _mapKey,
            spots: provider.spots,
            highlightedId: provider.highlightedId,
            onMarkerTap: _onMarkerTap,
          ),
          // 底部渐变——无缝过渡到下方内容
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 40,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      LoveGirlTheme.bgLight.withAlpha(0),
                      LoveGirlTheme.bgLight,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 右上角"已探索"标签
          Positioned(
            right: 16,
            top: 8,
            child: _buildExploredBadge(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildExploredBadge(TravelProvider provider) {
    final cityCount = provider.stats?.cities ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LoveGirlTheme.primary.withAlpha(30),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.explore, size: 14, color: LoveGirlTheme.primary),
          const SizedBox(width: 4),
          Text(
            '已探索 $cityCount 个城市',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 波浪装饰分隔线 ====================

  Widget _buildWavyDivider() {
    return SizedBox(
      height: 20,
      child: WavyBackground(
        colors: [
          LoveGirlTheme.primary.withAlpha(12),
          LoveGirlTheme.accent.withAlpha(8),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        child: const SizedBox(height: 40),
      ),
    );
  }

  // ==================== 统计卡片行 ====================

  Widget _buildStatsRow(TravelProvider provider) {
    final stats = provider.stats;
    final items = [
      {
        'label': '去过',
        'value': '${stats?.visited ?? 0}',
        'iconData': Icons.check_circle_rounded,
        'gradient': [
          const Color(0xFF00D4AA).withAlpha(35),
          const Color(0xFF00D4AA).withAlpha(8),
        ],
        'color': LoveGirlTheme.visited,
      },
      {
        'label': '想去',
        'value': '${stats?.wish ?? 0}',
        'iconData': Icons.star_rounded,
        'gradient': [
          const Color(0xFFFF9800).withAlpha(35),
          const Color(0xFFFF9800).withAlpha(8),
        ],
        'color': LoveGirlTheme.wish,
      },
      {
        'label': '规划中',
        'value': '${stats?.planned ?? 0}',
        'iconData': Icons.assignment_rounded,
        'gradient': [
          const Color(0xFF9C27B0).withAlpha(35),
          const Color(0xFF9C27B0).withAlpha(8),
        ],
        'color': LoveGirlTheme.planned,
      },
      {
        'label': '城市',
        'value': '${stats?.cities ?? 0}',
        'iconData': Icons.location_city_rounded,
        'gradient': [
          LoveGirlTheme.primary.withAlpha(35),
          LoveGirlTheme.primary.withAlpha(8),
        ],
        'color': LoveGirlTheme.primary,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: items.map((item) {
          final color = item['color'] as Color;
          final gradient = item['gradient'] as List<Color>;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OrganicCard(
                organic: true,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                gradient: gradient,
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['iconData'] as IconData,
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['value'] as String,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withAlpha(180),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== 有机筛选器 ====================

  Widget _buildOrganicFilter(TravelProvider provider) {
    final filters = [
      {'key': '', 'label': '全部', 'iconData': Icons.public_rounded},
      {'key': 'visited', 'label': '去过', 'iconData': Icons.check_circle_rounded},
      {'key': 'wish', 'label': '想去', 'iconData': Icons.star_rounded},
      {'key': 'planned', 'label': '规划中', 'iconData': Icons.assignment_rounded},
    ];

    return Container(
      height: 88,
      padding: const EdgeInsets.only(top: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final active = provider.activeStatus == f['key'];
          final color = f['key'] == ''
              ? LoveGirlTheme.primary
              : _statusColor(f['key'] as String);

          // 波浪偏移——每个按钮在波浪上有不同高度
          final waveOffset = sin((index - 1.5) * 0.9) * 7;

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Transform.translate(
              offset: Offset(0, waveOffset),
              child: GestureDetector(
                onTap: () => provider.setStatus(f['key'] as String),
                child: ClipPath(
                  clipper: _OrganicCircleClipper(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    width: active ? 72 : 60,
                    height: active ? 72 : 60,
                    decoration: BoxDecoration(
                      color: active
                          ? color
                          : Colors.white.withAlpha(235),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: color.withAlpha(70),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            provider.setStatus(f['key'] as String),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                f['iconData'] as IconData,
                                size: active ? 24 : 20,
                                color: active ? Colors.white : LoveGirlTheme.textSecondary,
                              ),
                              if (active)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 1),
                                  child: Text(
                                    f['label'] as String,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 有机浮动按钮 ====================

  Widget _buildOrganicFab() {
    return ClipPath(
      clipper: _OrganicFabClipper(),
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF7B73FF),
              Color(0xFF635BFF),
              Color(0xFF4A42E8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: LoveGirlTheme.primary.withAlpha(80),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: LoveGirlTheme.primary.withAlpha(40),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openForm(context),
            customBorder: const CircleBorder(),
            child: const Center(
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 地点卡片 ====================

  Widget _buildSpotCard(TravelSpot spot, TravelProvider provider) {
    final highlighted = provider.highlightedId == spot.id;
    final color = _statusColor(spot.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => _openForm(context, spot: spot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          key: _itemKeys[spot.id],
          transform: highlighted
              ? (Matrix4.identity()..scale(1.01))
              : Matrix4.identity(),
          child: OrganicCard(
            organic: true,
            padding: EdgeInsets.zero,
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: color.withAlpha(40),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: color.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左侧彩色有机竖条装饰
                  Container(
                    width: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color,
                          color.withAlpha(180),
                          color.withAlpha(80),
                        ],
                      ),
                    ),
                  ),
                  // 内容区域
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 顶部行：emoji + 名称 + 状态标签
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(
                                    _spotIcon(spot.status),
                                    size: 22,
                                    color: color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      spot.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: LoveGirlTheme.textPrimary,
                                      ),
                                    ),
                                    if (spot.city.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 13,
                                              color: LoveGirlTheme.textMuted,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              spot.city,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: LoveGirlTheme.textMuted
                                                    .withAlpha(200),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              _buildStatusTag(spot.status),
                            ],
                          ),

                          // ======== Visited 专属 ========
                          if (spot.status == 'visited') ...[
                            const SizedBox(height: 10),
                            if (spot.rating != null && spot.rating! > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: List.generate(5, (i) {
                                    return Icon(
                                      i < spot.rating!
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: const Color(0xFFFFB800),
                                      size: 16,
                                    );
                                  }),
                                ),
                              ),
                            if (spot.visitedDate != null)
                              _buildInfoRow(
                                Icons.calendar_today,
                                spot.visitedDate!,
                              ),
                            if (spot.diary != null && spot.diary!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  spot.diary!.length > 60
                                      ? '${spot.diary!.substring(0, 60)}...'
                                      : spot.diary!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: LoveGirlTheme.textSecondary
                                        .withAlpha(200),
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],

                          // ======== Wish 专属 ========
                          if (spot.status == 'wish') ...[
                            const SizedBox(height: 8),
                            if (spot.reason != null && spot.reason!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  spot.reason!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: LoveGirlTheme.textSecondary
                                        .withAlpha(200),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (spot.desire != null)
                              Row(
                                children: [
                                  const Text(
                                    '渴望度: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: LoveGirlTheme.textMuted,
                                    ),
                                  ),
                                  ...List.generate(
                                    spot.desire!,
                                    (_) => const Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 16,
                                      color: LoveGirlTheme.orange,
                                    ),
                                  ),
                                ],
                              ),
                          ],

                          // ======== Planned 专属 ========
                          if (spot.status == 'planned') ...[
                            const SizedBox(height: 8),
                            if (spot.plannedDate != null) ...[
                              _buildInfoRow(Icons.event, spot.plannedDate!),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _buildCountdown(spot.plannedDate!),
                              ),
                            ],
                            if (spot.budget != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: _buildInfoRow(
                                  Icons.monetization_on_outlined,
                                  '预算 ¥${spot.budget!.toStringAsFixed(0)}',
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 空状态 ====================

  Widget _buildEmpty(TravelProvider provider) {
    String msg;
    String subMsg = '点击右下角的 + 添加吧';
    if (provider.activeStatus == 'visited') {
      msg = '还没有去过的地方';
    } else if (provider.activeStatus == 'wish') {
      msg = '还没有想去的地方';
    } else if (provider.activeStatus == 'planned') {
      msg = '还没有规划中的地方';
    } else {
      msg = '还没有旅行地点';
      subMsg = '点击右下角 + 添加你们的足迹吧';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 有机 blob 装饰
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _BlobPainterSimple(
                  color: LoveGirlTheme.primary.withAlpha(30),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: LoveGirlTheme.textMuted.withAlpha(200),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subMsg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: LoveGirlTheme.textMuted.withAlpha(140),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 辅助组件 ====================

  Widget _buildStatusTag(String status) {
    Color bg;
    Color textColor;
    String label;

    switch (status) {
      case 'visited':
        bg = LoveGirlTheme.visited.withAlpha(25);
        textColor = LoveGirlTheme.visited;
        label = '已打卡';
      case 'wish':
        bg = LoveGirlTheme.wish.withAlpha(25);
        textColor = LoveGirlTheme.wish;
        label = '心愿单';
      case 'planned':
        bg = LoveGirlTheme.planned.withAlpha(25);
        textColor = LoveGirlTheme.planned;
        label = '计划中';
      default:
        bg = LoveGirlTheme.textMuted.withAlpha(25);
        textColor = LoveGirlTheme.textMuted;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: LoveGirlTheme.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: LoveGirlTheme.textSecondary.withAlpha(200),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown(String plannedDate) {
    try {
      final target = DateTime.parse(plannedDate);
      final now = DateTime.now();
      final diff =
          target.difference(DateTime(now.year, now.month, now.day)).inDays;

      if (diff < 0) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 13,
              color: LoveGirlTheme.visited.withAlpha(180),
            ),
            const SizedBox(width: 4),
            Text(
              '已过期 ${-diff} 天',
              style: TextStyle(
                fontSize: 12,
                color: LoveGirlTheme.visited.withAlpha(180),
              ),
            ),
          ],
        );
      } else if (diff == 0) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alarm, size: 13, color: Colors.red),
            const SizedBox(width: 4),
            const Text(
              '就是今天！',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      } else {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 13,
              color: LoveGirlTheme.planned.withAlpha(200),
            ),
            const SizedBox(width: 4),
            Text(
              '倒计时 $diff 天',
              style: TextStyle(
                fontSize: 12,
                color: LoveGirlTheme.planned.withAlpha(200),
              ),
            ),
          ],
        );
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'visited':
        return LoveGirlTheme.visited;
      case 'wish':
        return LoveGirlTheme.wish;
      case 'planned':
        return LoveGirlTheme.planned;
      default:
        return LoveGirlTheme.textMuted;
    }
  }

  IconData _spotIcon(String status) {
    switch (status) {
      case 'visited':
        return Icons.flag_rounded;
      case 'wish':
        return Icons.favorite_rounded;
      case 'planned':
        return Icons.calendar_month_rounded;
      default:
        return Icons.location_on_rounded;
    }
  }
}

// ==================== 手绘圆形剪切器 ====================

/// 生成略微不规则的圆形路径，模拟手绘质感
class _OrganicCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(cx, cy) - 1.5;
    final rand = Random(42);
    const steps = 16;

    for (int i = 0; i < steps; i++) {
      final angle = (2 * pi * i) / steps;
      final nextAngle = (2 * pi * (i + 1)) / steps;
      // 半径微抖动 6%
      final jitter = 1.0 + (rand.nextDouble() - 0.5) * 0.06;
      final x = cx + r * jitter * cos(angle);
      final y = cy + r * jitter * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final cpx = cx +
            r * jitter * 1.15 * cos(angle + (nextAngle - angle) * 0.3);
        final cpy = cy +
            r * jitter * 1.15 * sin(angle + (nextAngle - angle) * 0.3);
        path.quadraticBezierTo(cpx, cpy, x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

// ==================== 有机 FAB 形状 ====================

/// 有机形态的浮动按钮剪裁路径
class _OrganicFabClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return OrganicPaths.randomBlob(
      Rect.fromLTWH(0, 0, size.width, size.height),
      points: 10,
      variance: 0.25,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

// ==================== 简易Blob绘制（空状态装饰用） ====================

class _BlobPainterSimple extends CustomPainter {
  final Color color;

  _BlobPainterSimple({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    final path = OrganicPaths.randomBlob(
      Rect.fromLTWH(0, 0, size.width, size.height),
      points: 8,
      variance: 0.35,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobPainterSimple old) => old.color != color;
}
