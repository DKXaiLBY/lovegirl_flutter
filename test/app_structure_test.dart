import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'package:lovegirl_flutter/main.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/home_provider.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/providers/notification_provider.dart';
import 'package:lovegirl_flutter/providers/theme_provider.dart';
import 'package:lovegirl_flutter/features/travel/travel_workspace.dart';
import 'package:lovegirl_flutter/screens/health/health_screen.dart';
import 'package:lovegirl_flutter/screens/health/widgets/period_tracker.dart';
import 'package:lovegirl_flutter/screens/home/home_screen.dart';
import 'package:lovegirl_flutter/screens/life/life_screen.dart';
import 'package:lovegirl_flutter/screens/life/widgets/todo_list.dart';
import 'package:lovegirl_flutter/screens/memories/memories_screen.dart';
import 'package:lovegirl_flutter/screens/notifications/notification_center_screen.dart';
import 'package:lovegirl_flutter/screens/profile/profile_screen.dart';
import 'package:lovegirl_flutter/screens/settings/settings_screen.dart';
import 'package:lovegirl_flutter/features/travel/travel_screen.dart';
import 'package:lovegirl_flutter/utils/app_section.dart';
import 'package:lovegirl_flutter/utils/lovegirl_dates.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  Widget app(Widget home,
      {bool girl = false,
      bool perspectiveGirl = false,
      HomeProvider? today,
      NotificationProvider? notifications,
      bool dark = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
            create: (_) => _Auth(girl, perspectiveGirl)),
        ChangeNotifierProvider<HomeProvider>(create: (_) => today ?? _Home()),
        ChangeNotifierProvider<NotificationProvider>(
            create: (_) => notifications ?? _Notifications()),
        ChangeNotifierProvider<MapPrefsProvider>(
            create: (_) => MapPrefsProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<TravelWorkspace>(create: (_) => _Travel()),
      ],
      child: MaterialApp(
          theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
          home: home),
    );
  }

  testWidgets(
      'five sections are usable and travel is no longer the memory slot',
      (tester) async {
    await tester.pumpWidget(app(const AppShell()));
    await tester.pump();
    for (final label in ['今天', '回忆', '旅行', '生活', '我们']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('健康'), findsNothing);
    await tester.tap(find.text('回忆'));
    await tester.pump();
    expect(find.byType(MemoriesScreen), findsOneWidget);
    await tester.tap(find.text('旅行'));
    await tester.pump();
    expect(find.byType(TravelScreen), findsOneWidget);
    await tester.tap(find.text('生活'));
    await tester.pump();
    expect(find.byType(LifeScreen), findsOneWidget);
    await tester.tap(find.text('我们'));
    await tester.pump();
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  for (final role in [(false, false), (true, false), (false, true)]) {
    testWidgets('period entry uses original identity: $role', (tester) async {
      await tester.pumpWidget(
          app(LifeScreen(api: _LifeApi()), girl: role.$1, perspectiveGirl: role.$2));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -1100));
      await tester.pumpAndSettle();
      expect(find.text('经期记录'), role.$1 ? findsOneWidget : findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('我的衣橱'), findsOneWidget);
      expect(find.text('情侣厨房'), findsOneWidget);
    });
  }

  testWidgets(
      'direct period route still denies a boy viewing the girl perspective',
      (tester) async {
    await tester.pumpWidget(app(const HealthScreen(), perspectiveGirl: true));
    expect(find.text('健康页只给她看'), findsOneWidget);
    expect(find.byType(PeriodTracker), findsNothing);
  });

  testWidgets('life tools open as pages and back returns to the list',
      (tester) async {
    await tester.pumpWidget(app(LifeScreen(api: _LifeApi())));
    await tester.tap(find.text('待办'));
    await tester.pumpAndSettle();
    expect(find.byType(TodoListWidget), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('本月账本'), findsOneWidget);
    expect(find.byType(TodoListWidget), findsNothing);
  });

  testWidgets('travel notification uses the named travel target',
      (tester) async {
    AppSection? target;
    await tester.pumpWidget(app(
        NotificationCenterScreen(
          onNavigateToTab: (value) => target = value,
        ),
        notifications: _TravelNotifications()));
    await tester.pump();
    await tester.tap(find.text('旅行打卡通知'));
    await tester.pump();
    expect(target, AppSection.travel);
  });

  testWidgets('reports share one entry and preserve month and year choices',
      (tester) async {
    await tester.pumpWidget(app(const MemoriesScreen()));
    await tester.ensureVisible(find.text('回忆报告'));
    await tester.tap(find.text('回忆报告'));
    await tester.pumpAndSettle();
    expect(find.text('月度小报'), findsOneWidget);
    expect(find.text('年度报告'), findsOneWidget);
  });

  testWidgets(
      'zero todos stays empty without sample courses or a fake completed ratio',
      (tester) async {
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump();
    expect(find.text('暂无待办'), findsOneWidget);
    expect(find.text('提醒她多喝水'), findsNothing);
    expect(find.text('睡前讲故事'), findsNothing);
    expect(find.text('0/2 完成'), findsNothing);
    expect(find.text('情侣厨房'), findsNothing);
    expect(find.text('设计心理学'), findsNothing);
    expect(find.text('剩余预算'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets(
      'settings expose working controls without export, reset or unscheduled reminders',
      (tester) async {
    await tester.pumpWidget(app(const SettingsScreen()));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('清除缓存'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('清除缓存'), findsOneWidget);
    expect(find.text('导出数据'), findsNothing);
    expect(find.text('重置所有数据'), findsNothing);
    expect(find.text('姨妈提醒'), findsNothing);
    expect(find.text('纪念日提醒'), findsNothing);
    expect(find.text('待办提醒'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 11));
  });

  for (final dark in [false, true]) {
    testWidgets(
        'hub pages remain readable on a narrow screen with large text: dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      for (final page in [LifeScreen(api: _LifeApi()), const MemoriesScreen()]) {
        await tester.pumpWidget(app(
            MediaQuery(
              data: const MediaQueryData(
                  size: Size(360, 760), textScaler: TextScaler.linear(1.5)),
              child: page,
            ),
            girl: true,
            dark: dark));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  }

  group('upcoming anniversary uses real dates within one week', () {
    final now = DateTime(2026, 10, 23);
    test('empty, past once, distant and lunar dates do not create a reminder',
        () {
      expect(upcomingAnniversary([], now: now), isNull);
      expect(
          upcomingAnniversary([
            {'event_date': '2026-10-22', 'repeat_type': 'once'},
            {'event_date': '2020-12-01'},
            {'event_date': '2020-10-24', 'is_lunar': 1},
          ], now: now),
          isNull);
    });
    test('selects the nearest yearly date including today', () {
      expect(
          upcomingAnniversary([
            {'title': '下周', 'event_date': '2020-10-27'},
            {'title': '今天', 'event_date': '2020-10-23'},
          ], now: now),
          {'title': '今天', 'days': 0});
    });
    test('monthly repeats roll to next month and clamp the last day', () {
      expect(
          upcomingAnniversary([
            {
              'title': '月底',
              'event_date': '2020-01-31',
              'repeat_type': 'monthly'
            },
          ], now: DateTime(2026, 2, 23)),
          {'title': '月底', 'days': 5});
      expect(
          upcomingAnniversary([
            {
              'title': '月初',
              'event_date': '2020-01-02',
              'repeat_type': 'monthly'
            },
          ], now: DateTime(2026, 10, 29)),
          {'title': '月初', 'days': 4});
    });
    test('a future first occurrence is not moved into an earlier year', () {
      expect(
          upcomingAnniversary([
            {'title': '未来', 'event_date': '2027-10-24'},
          ], now: now),
          isNull);
    });
  });

  test(
      'todo counts follow the displayed records even when the home aggregate is stale',
      () async {
    final provider = HomeProvider(
        api: _TodoApi([
      {'id': 1, 'title': '喝水', 'completed': 0},
      {'id': 2, 'title': '散步', 'completed': 1},
    ]));
    await provider.refresh();
    expect(provider.today!['todo']['total'], 2);
    expect(provider.today!['todo']['active'], 1);
    expect(provider.today!['todo']['items'], hasLength(1));
    provider.dispose();
  });

  test('a genuinely empty todo list overrides stale nonzero aggregate counts',
      () async {
    final provider = HomeProvider(api: _TodoApi([]));
    await provider.refresh();
    expect(provider.today!['todo']['total'], 0);
    expect(provider.today!['todo']['active'], 0);
    expect(provider.today!['todo']['items'], isEmpty);
    provider.dispose();
  });
}

class _TodoApi implements ApiService {
  final List<Map<String, dynamic>> todos;
  _TodoApi(this.todos);
  Future<Response<dynamic>> response(dynamic data) async => Response(
      data: {'code': 200, 'data': data}, requestOptions: RequestOptions());
  @override
  Future<Response<dynamic>> getTodos() => response(todos);
  @override
  Future<Response<dynamic>> getHomeToday() => response({
        'todo': {'total': 99, 'active': 99}
      });
  @override
  dynamic noSuchMethod(Invocation invocation) => response([]);
}

class _LifeApi extends _TodoApi {
  _LifeApi() : super([]);
  @override
  Future<Response<dynamic>> getFinanceStats(String month, {String? source}) =>
      response({'expense': 0});
  @override
  Future<Response<dynamic>> getKitchenMenu() =>
      response({'mine': [], 'partner_dishes': []});
}

class _Auth extends AuthProvider {
  final bool originalGirl;
  final bool perspectiveGirl;
  _Auth(this.originalGirl, this.perspectiveGirl);
  @override
  bool get isInitializing => false;
  @override
  bool get isLoggedIn => true;
  @override
  bool get isOriginalGirl => originalGirl;
  @override
  bool get isGirl => originalGirl || perspectiveGirl;
  @override
  Map<String, dynamic> get user =>
      {'id': 1, 'nickname': '我们', 'role': originalGirl ? 'girl' : 'boy'};
  @override
  int get loveDays => 520;
}

class _Home extends HomeProvider {
  _Home() {
    today = {
      'todo': {'total': 0, 'active': 0},
      'feed': {'hasActiveOrder': false}
    };
  }
  @override
  Future<void> refresh() async {}
}

class _Notifications extends NotificationProvider {
  @override
  Future<void> refresh() async {}
  @override
  Future<void> refreshCount() async {}
}

class _TravelNotifications extends _Notifications {
  @override
  List<NotificationItem> get items => [
        NotificationItem(
            id: 9,
            type: 'travel_checkin',
            title: '旅行打卡通知',
            content: '一起去过的地方',
            createdAt: DateTime.now())
      ];
  @override
  Future<void> markRead(NotificationItem item) async {}
}

class _Travel extends TravelWorkspace {
  @override
  Future<void> load({bool refresh = false}) async {}
}
