import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'widgets/todo_list.dart';
import 'widgets/finance_list.dart';
import 'widgets/schedule_list.dart';

class LifeScreen extends StatefulWidget {
  final int initialTab;
  const LifeScreen({super.key, this.initialTab = 0});

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() { if (mounted) setState(() {}); });
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
      backgroundColor: LoveGirlTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            // 沉浸式标题+TabBar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const Text('生活', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: LoveGirlTheme.textPrimary)),
                  const Spacer(),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: LoveGirlTheme.primary.withAlpha(30), shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: LoveGirlTheme.pink.withAlpha(25), shape: BoxShape.circle)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // TabBar —— 悬浮胶囊风格
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: LoveGirlTheme.cardLight,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: LoveGirlTheme.primary,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: LoveGirlTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.checklist_rounded, size: 18), SizedBox(width: 6), Text('待办')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.account_balance_wallet_rounded, size: 18), SizedBox(width: 6), Text('记账')])),
                  Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_month_rounded, size: 18), SizedBox(width: 6), Text('课程表')])),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // 内容区
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: const [TodoListWidget(), FinanceListWidget(), ScheduleListWidget()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
