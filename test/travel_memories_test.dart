import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/travel_form_screen.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/travel_memories.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/widgets/memory_controls.dart';

void main() {
  test('同城多地点只算一城，未知城市和未打卡地点不计入', () {
    expect(
        visitedMemoryCityCount([
          TravelSpot(id: 1, name: '西湖', city: '杭州', status: 'visited'),
          TravelSpot(id: 2, name: '法喜寺', city: ' 杭州市 ', status: 'visited'),
          TravelSpot(id: 3, name: '未填', city: '', status: 'visited'),
          TravelSpot(id: 4, name: '想去', city: '上海', status: 'wish'),
        ]),
        1);
  });

  test('日期倒序、同日多记录保留、无日期排后，输入顺序不变', () {
    final spots = [
      TravelSpot(
          id: 1,
          name: '早',
          city: '杭州',
          status: 'visited',
          visitedDate: '2026-01-01'),
      TravelSpot(id: 2, name: '未知', city: '杭州', status: 'visited'),
      TravelSpot(
          id: 3,
          name: '晚',
          city: '杭州市',
          status: 'visited',
          visitedDate: '2026-10-01'),
      TravelSpot(
          id: 4,
          name: '同日',
          city: '杭州',
          status: 'visited',
          visitedDate: '2026-10-01'),
    ];
    expect(groupTravelMemories(spots)['杭州']!.map((s) => s.id), [4, 3, 1, 2]);
    expect(spots.map((s) => s.id), [1, 2, 3, 4]);
  });

  test('城市分组由最近记录排序，未知城市有明确分组', () {
    final groups = groupTravelMemories([
      TravelSpot(
          id: 1,
          name: '旧',
          city: '杭州',
          status: 'visited',
          visitedDate: '2020-01-01'),
      TravelSpot(
          id: 2,
          name: '新',
          city: '上海',
          status: 'visited',
          visitedDate: '2026-01-01'),
      TravelSpot(id: 3, name: '未知', status: 'visited'),
    ]);
    expect(groups.keys, ['上海', '杭州', '未填写城市']);
  });

  testWidgets('主行动按钮深色背景和文字保持高对比度', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => MapPrefsProvider(),
      child: MaterialApp(
          theme: LoveGirlTheme.darkTheme,
          home:
              Scaffold(body: LovePrimaryButton(text: '保存', onPressed: () {}))),
    ));
    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    final background = style.backgroundColor!.resolve({});
    final foreground = style.foregroundColor!.resolve({});
    final high = [
      background!.computeLuminance(),
      foreground!.computeLuminance()
    ]..sort();
    expect((high[1] + 0.05) / (high[0] + 0.05), greaterThan(4.5));
  });

  testWidgets('玻璃操作执行期间阻止重复提交，完成后恢复', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: MemoryAction(
          icon: Icons.add,
          label: '关联照片',
          onPressed: () {
            calls++;
            return completer.future;
          }),
    )));
    await tester.tap(find.text('关联照片'));
    await tester.pump();
    expect(find.text('处理中'), findsOneWidget);
    await tester.tap(find.text('处理中'));
    expect(calls, 1);
    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('关联照片'), findsOneWidget);
  });

  testWidgets('禁用的操作不会触发回调或按压缩放', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: MemoryAction(icon: Icons.add, label: '不可用', onPressed: null),
    )));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('不可用')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
  });

  testWidgets('编辑地点只改名称时仍提交原心情、天气与备注', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = _SavingTravelProvider();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<TravelProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => MapPrefsProvider()),
      ],
      child: MaterialApp(
          home: TravelFormScreen(
              spot: TravelSpot(
        id: 7,
        name: '原名称',
        city: '杭州',
        status: 'wish',
        mood: '开心',
        weather: '晴天',
        note: '保留备注',
        tags: ['散步'],
        visitedDate: '2026-10-18',
        diary: '这一天的故事',
      ))),
    ));
    await tester.enterText(find.byType(TextField).first, '新名称');
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(provider.saved?['name'], '新名称');
    expect(provider.saved?['mood'], '开心');
    expect(provider.saved?['weather'], '晴天');
    expect(provider.saved?['diary'], '这一天的故事');
    expect(provider.saved?['tags'], ['散步']);
    expect(provider.saved?['note'], '保留备注');
    await tester.pumpAndSettle();
  });
}

class _SavingTravelProvider extends TravelProvider {
  Map? saved;
  @override
  Future<void> updateSpot(int id, Map data) async {
    saved = data;
  }
}
