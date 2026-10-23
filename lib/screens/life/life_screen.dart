import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../health/health_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../wardrobe/wardrobe_module_screen.dart';
import 'widgets/finance_list.dart';
import 'widgets/schedule_list.dart';
import 'widgets/todo_list.dart';

class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String, Widget)>[
      (
        Icons.checklist_rounded,
        '待办',
        '一起安排要做的事',
        const LifeToolScreen(title: '待办', child: TodoListWidget())
      ),
      (
        Icons.account_balance_wallet_outlined,
        '记账',
        '日常收支与旅行花费',
        const LifeToolScreen(title: '记账', child: FinanceListWidget())
      ),
      (
        Icons.calendar_month_outlined,
        '课程',
        '查看和管理课程表',
        const LifeToolScreen(title: '课程', child: ScheduleListWidget())
      ),
      (
        Icons.checkroom_outlined,
        '衣橱',
        '衣服、搭配与穿搭记录',
        const LifeToolScreen(title: '衣橱', child: WardrobeModuleScreen())
      ),
      (Icons.restaurant_outlined, '情侣厨房', '点菜、做饭与开饭记录', const KitchenScreen()),
      if (context.watch<AuthProvider>().isOriginalGirl)
        (
          Icons.health_and_safety_outlined,
          '经期记录',
          '仅自己可见',
          const HealthScreen()
        ),
    ];
    return Scaffold(
      backgroundColor: context.lgBg,
      body: LovePage(
        child: ListView(
          children: [
            const LoveSectionTitle(title: '生活'),
            const SizedBox(height: 16),
            LovePaper(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    LoveMenuRow(
                      icon: entries[i].$1,
                      title: entries[i].$2,
                      value: entries[i].$3,
                      color: context.lgInk,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => entries[i].$4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LifeToolScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const LifeToolScreen({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        title: Text(title),
        systemOverlayStyle: context.lgIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}
