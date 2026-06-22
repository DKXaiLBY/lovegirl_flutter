import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/widgets/organic_ui.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'widgets/period_tracker.dart';
import 'widgets/calorie_tracker.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // 仅女友角色可访问，但已在 AppShell 中处理，这里做个安全兜底
    if (!auth.isGirl) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 64, color: LoveGirlTheme.pink),
              SizedBox(height: 16),
              Text('只有她才能查看哦 💕',
                  style: TextStyle(fontSize: 16, color: LoveGirlTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: LoveGirlTheme.bgLight,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 100,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: WavyBackground(
                    colors: [
                      LoveGirlTheme.pink.withAlpha(40),
                      LoveGirlTheme.pinkLight.withAlpha(25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    child: const SizedBox.expand(),
                  ),
                  titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
                  title: const Text(
                    '健康',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OrganicCard(
                      organic: true,
                      padding: EdgeInsets.zero,
                      child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [LoveGirlTheme.pink, LoveGirlTheme.pinkLight],
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: LoveGirlTheme.textSecondary,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      splashFactory: NoSplash.splashFactory,
                      padding: const EdgeInsets.all(4),
                      tabs: const [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.water_drop, size: 18),
                              SizedBox(width: 6),
                              Text('姨妈助手'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.restaurant, size: 18),
                              SizedBox(width: 6),
                              Text('卡路里'),
                            ],
                          ),
                        ),
                      ],
                    ), // TabBar
                  ), // OrganicCard
                ), // Padding
              ), // PreferredSize
            ), // SliverAppBar bottom
          ];
          },
          body: Container(
            margin: const EdgeInsets.only(top: 8),
            child: TabBarView(
              controller: _tabController,
              children: const [
                PeriodTracker(),
                CalorieTracker(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
