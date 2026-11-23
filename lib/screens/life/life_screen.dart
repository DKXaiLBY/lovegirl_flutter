import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../features/study/study_screen.dart';
import '../../features/study/study_workspace.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import '../health/health_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../wardrobe/wardrobe_module_screen.dart';
import 'widgets/finance_list.dart';
import 'widgets/schedule_list.dart';
import 'widgets/todo_list.dart';

class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key, this.api});
  final ApiService? api;

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthProvider>();
    final study = context.watch<StudyWorkspace?>();
    final due = study?.due(DateTime.now()).length ?? 0;
    void openStudy() {
      _open(
          context,
          study == null
              ? ChangeNotifierProvider(
                  create: (_) =>
                      StudyWorkspace(account.userId, api: api)..load(),
                  child: const StudyScreen())
              : const StudyScreen());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('生活'),
        actions: [
          TextButton(
            onPressed: () =>
                _open(context, _LifeTools(showHealth: account.isOriginalGirl)),
            child: const Text('全部工具'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          RebuildGlass(
            radius: 20,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.restaurant_outlined),
                title: const Text('去点菜'),
                subtitle: const Text('情侣厨房'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(context, const KitchenScreen()),
              ),
              const Divider(height: 1, indent: 52),
              ListTile(
                leading: const Icon(Icons.checklist_outlined),
                title: const Text('看待办'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                    context,
                    LifeToolScreen(
                        title: '待办', child: TodoListWidget(api: api))),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Text('学习', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          RebuildGlass(
            radius: 20,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('专升本备考'),
                subtitle: Text(due > 0 ? '今天有 $due 个考点待复习' : '政治理论、管理学、基础会计学'),
                trailing: const Icon(Icons.chevron_right),
                onTap: openStudy,
              ),
              const Divider(height: 1, indent: 52),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('课程表'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                    context,
                    const LifeToolScreen(
                        title: '课程表', child: ScheduleListWidget())),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _LifeTools extends StatelessWidget {
  const _LifeTools({required this.showHealth});
  final bool showHealth;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('全部工具')),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              for (final (icon, title, page) in [
                (
                  Icons.receipt_long_outlined,
                  '账本',
                  const LifeToolScreen(title: '账本', child: FinanceListWidget())
                ),
                if (showHealth)
                  (Icons.lock_outline, '经期记录', const HealthScreen()),
                (
                  Icons.checkroom_outlined,
                  '衣橱资料',
                  const LifeToolScreen(
                      title: '衣橱资料', child: WardrobeModuleScreen())
                ),
              ])
                ListTile(
                    leading: Icon(icon),
                    title: Text(title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => page))),
            ]),
      );
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
        flexibleSpace: const RebuildGlassHeader(),
        title: Text(title),
        systemOverlayStyle: context.lgIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}
