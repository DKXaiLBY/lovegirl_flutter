import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/travel_form_screen.dart';
import 'package:lovegirl_flutter/widgets/travel_map_widget.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

/// 旅行主页 — 包含地图和列表
class TravelMainScreen extends StatefulWidget {
  const TravelMainScreen({super.key});

  @override
  State<TravelMainScreen> createState() => _TravelMainScreenState();
}

class _TravelMainScreenState extends State<TravelMainScreen> {
  final GlobalKey<TravelMapWidgetState> _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TravelProvider>().refreshAll();
    });
  }

  void _openForm({TravelSpot? spot}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TravelFormScreen(spot: spot),
      ),
    );
    // 表单关闭后刷新数据
    if (result == true && mounted) {
      context.read<TravelProvider>().refreshAll();
    }
  }

  void _onMarkerTap(TravelSpot spot) {
    _mapKey.currentState?.animateToSpot(spot);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TravelProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: LoveGirlTheme.bgLight,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshAll(),
              child: CustomScrollView(
                slivers: [
                  // 地图区域
                  SliverToBoxAdapter(child: _buildMapSection(provider)),

                  // 统计卡片
                  SliverToBoxAdapter(child: _buildStats(provider)),

                  // 筛选按钮
                  SliverToBoxAdapter(child: _buildFilter(provider)),

                  // 地点列表
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
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(),
            backgroundColor: LoveGirlTheme.primary,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // 地图区域
  Widget _buildMapSection(TravelProvider provider) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.4;

    return SizedBox(
      height: mapHeight,
      child: TravelMapWidget(
        key: _mapKey,
        spots: provider.spots,
        highlightedId: provider.highlightedId,
        onMarkerTap: _onMarkerTap,
      ),
    );
  }

  // 统计卡片（使用实际spots数据计算，保证一致性）
  Widget _buildStats(TravelProvider provider) {
    final stats = provider.computedStats;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [LoveGirlTheme.primary, LoveGirlTheme.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: LoveGirlTheme.primary.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('去过', '${stats.visited}', Icons.check_circle, 'visited', provider),
          _buildStatItem('想去', '${stats.wish}', Icons.star, 'wish', provider),
          _buildStatItem('规划中', '${stats.planned}', Icons.assignment, 'planned', provider),
          _buildStatItem('城市', '${stats.cities}', Icons.location_city, '', provider),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, String status, TravelProvider provider) {
    final isActive = status.isNotEmpty && provider.activeStatus == status;
    return GestureDetector(
      onTap: status.isNotEmpty ? () {
        // 点击统计卡片切换筛选状态
        provider.setStatus(isActive ? '' : status);
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: isActive ? BoxDecoration(
          color: Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ) : null,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 筛选按钮
  Widget _buildFilter(TravelProvider provider) {
    final filters = [
      {'key': '', 'label': '全部'},
      {'key': 'visited', 'label': '去过'},
      {'key': 'wish', 'label': '想去'},
      {'key': 'planned', 'label': '规划中'},
    ];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final active = provider.activeStatus == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f['label']!),
              selected: active,
              onSelected: (_) => provider.setStatus(f['key']!),
              selectedColor: LoveGirlTheme.primary.withAlpha(30),
              labelStyle: TextStyle(
                color: active ? LoveGirlTheme.primary : LoveGirlTheme.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  // 空状态
  Widget _buildEmpty(TravelProvider provider) {
    String msg;
    if (provider.activeStatus == 'visited') {
      msg = '还没有去过的地方';
    } else if (provider.activeStatus == 'wish') {
      msg = '还没有想去的地方';
    } else if (provider.activeStatus == 'planned') {
      msg = '还没有规划中的地方';
    } else {
      msg = '还没有旅行地点';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: LoveGirlTheme.textMuted.withAlpha(100)),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(fontSize: 16, color: LoveGirlTheme.textMuted)),
          const SizedBox(height: 8),
          Text('点击右下角 + 添加', style: TextStyle(fontSize: 14, color: LoveGirlTheme.textMuted.withAlpha(150))),
        ],
      ),
    );
  }

  // 地点卡片
  Widget _buildSpotCard(TravelSpot spot, TravelProvider provider) {
    final color = _statusColor(spot.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openForm(spot: spot),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 状态图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(spot.status), color: color, size: 24),
              ),
              const SizedBox(width: 12),
              // 信息
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
                    if (spot.city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        spot.city,
                        style: TextStyle(
                          fontSize: 13,
                          color: LoveGirlTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 状态标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(spot.status),
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'visited':
        return const Color(0xFF4CAF50);
      case 'wish':
        return const Color(0xFFFF9800);
      case 'planned':
        return const Color(0xFF9C27B0);
      default:
        return LoveGirlTheme.primary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'visited':
        return Icons.check_circle;
      case 'wish':
        return Icons.star;
      case 'planned':
        return Icons.assignment;
      default:
        return Icons.location_on;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'visited':
        return '已打卡';
      case 'wish':
        return '心愿单';
      case 'planned':
        return '计划中';
      default:
        return status;
    }
  }
}
