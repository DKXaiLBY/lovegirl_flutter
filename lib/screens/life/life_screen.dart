import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'widgets/todo_list.dart';
import 'widgets/finance_list.dart';
import 'widgets/schedule_list.dart';
import '../mood/mood_screen.dart';

class LifeScreen extends StatefulWidget {
  final int initialTab;
  const LifeScreen({super.key, this.initialTab = 0});

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      body: LovePage(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _buildHeader(),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTabBar(),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: const [
                  TodoListWidget(),
                  FinanceListWidget(),
                  ScheduleListWidget(),
                  MoodScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LoveTicketCard(
      color: const Color(0xFFF7FCF4),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const LoveStickerIcon(
            icon: Icons.dashboard_customize_rounded,
            color: LoveGirlTheme.secondary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '生活',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '两个人的小生活面板',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.lgTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          LovePill(
            text: _currentTabLabel,
            icon: _currentTabIcon,
            color: context.lgInk,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return LovePaper(
      padding: const EdgeInsets.all(4),
      radius: 18,
      elevated: false,
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: context.lgInk,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: context.lgTextSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.checklist_rounded, size: 18),
                SizedBox(width: 6),
                Text('待办'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_rounded, size: 18),
                SizedBox(width: 6),
                Text('记账'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_rounded, size: 18),
                SizedBox(width: 6),
                Text('课程'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mood_rounded, size: 18),
                SizedBox(width: 6),
                Text('心情'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _currentTabLabel {
    switch (_tabController.index) {
      case 1:
        return '账本';
      case 2:
        return '课程';
      case 3:
        return '心情';
      default:
        return '清单';
    }
  }

  IconData get _currentTabIcon {
    switch (_tabController.index) {
      case 1:
        return Icons.payments_rounded;
      case 2:
        return Icons.school_rounded;
      case 3:
        return Icons.mood_rounded;
      default:
        return Icons.favorite_border_rounded;
    }
  }
}
