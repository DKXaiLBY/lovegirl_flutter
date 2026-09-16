import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:lovegirl_flutter/main.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/home_provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/auth/login_screen.dart';
import 'package:lovegirl_flutter/providers/kitchen_provider.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/screens/kitchen/kitchen_screen.dart';
import 'package:lovegirl_flutter/screens/home/home_screen.dart';
import 'package:lovegirl_flutter/screens/profile/profile_screen.dart';
import 'package:lovegirl_flutter/screens/travel/travel_amap_mode_screen.dart';
import 'package:lovegirl_flutter/screens/travel/travel_form_screen.dart';
import 'package:lovegirl_flutter/screens/travel/travel_main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (call) async {
      switch (call.method) {
        case 'checkPermission':
        case 'requestPermission':
          return 1;
        case 'openAppSettings':
          return true;
        default:
          return null;
      }
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);
  });

  testWidgets(
      'app shell shows the ticket-style boot screen while auth restores',
      (tester) async {
    final authProvider = _InitializingAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );

    await tester.pump();

    expect(find.text('LoveGirl'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('login screen shows clean Chinese copy', (tester) async {
    final authProvider = _IdleAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('登录你的账号'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('还没有账号？'), findsOneWidget);
    expect(find.text('立即注册'), findsOneWidget);
  });

  testWidgets('home screen keeps the confirmed ticket layout', (tester) async {
    final homeProvider = _FakeHomeProvider();
    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<HomeProvider>.value(value: homeProvider),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pump();

    expect(find.byKey(const ValueKey('home_header')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_today_care')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_memory_ticket')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home_travel_ticket')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('home_travel_ticket')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_life_summary')), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('home screen still renders on narrow devices', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final homeProvider = _FakeHomeProvider();
    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<HomeProvider>.value(value: homeProvider),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('LoveGirl'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('今天要照顾的事'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('今天要照顾的事'), findsOneWidget);
    expect(find.text('情侣厨房'), findsOneWidget);
    expect(find.text('待办清单'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home_travel_ticket')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('home_travel_ticket')), findsOneWidget);
    expect(find.text('旅行\n票根'), findsOneWidget);
    expect(find.text('查看路线'), findsOneWidget);
    expect(find.text('LOVEGIRL\nTRIP'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('travel map button opens add form first when there are no spots',
      (tester) async {
    final travelProvider = _FakeTravelProvider();
    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<TravelProvider>.value(value: travelProvider),
          ChangeNotifierProvider<MapPrefsProvider>(create: (_) => MapPrefsProvider()),
        ],
        child: const MaterialApp(home: TravelMainScreen()),
      ),
    );

    await tester.pump();
    expect(
        find.byKey(const ValueKey('travel_enter_amap_mode')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('travel_enter_amap_mode')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(TravelFormScreen), findsOneWidget);
  });

  testWidgets('travel amap mode shows ticket fallback when there are no spots',
      (tester) async {
    final travelProvider = _FakeTravelProvider();
    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<TravelProvider>.value(value: travelProvider),
          ChangeNotifierProvider<MapPrefsProvider>(create: (_) => MapPrefsProvider()),
        ],
        child: const MaterialApp(home: TravelAmapModeScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('先放一个想去的地方进来'), findsOneWidget);
    expect(find.text('回到预览'), findsWidgets);
    expect(find.text('新增地点'), findsWidgets);
  });

  testWidgets('travel map filter bar keeps all ticket labels visible',
      (tester) async {
    final travelProvider = _FakeTravelProviderWithSpots();
    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<TravelProvider>.value(value: travelProvider),
          ChangeNotifierProvider<MapPrefsProvider>(create: (_) => MapPrefsProvider()),
        ],
        child: const MaterialApp(home: TravelMainScreen()),
      ),
    );

    await tester.pump();

    final filterLabels = {
      'wish': '想去',
      'planned': '计划中',
      'visited': '已打卡',
      'both': '我们都编辑',
    };

    for (final entry in filterLabels.entries) {
      final filter = find.byKey(ValueKey('travel_map_filter_${entry.key}'));
      expect(filter, findsOneWidget);
      expect(
        find.descendant(of: filter, matching: find.text(entry.value)),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('travel_map_filter_both')));
    await tester.pump();

    expect(travelProvider.activeStatus, 'both');
  });

  test('amap location style passes rotate tracking mode to native map', () {
    final options = MyLocationStyleOptions(
      true,
      trackingMode: MyLocationTrackingMode.locationRotate,
      circleFillColor: const Color(0x331677FF),
      circleStrokeColor: const Color(0xFF1677FF),
      circleStrokeWidth: 1,
    );

    expect(options.toMap()['enabled'], isTrue);
    expect(
      options.toMap()['trackingMode'],
      MyLocationTrackingMode.locationRotate.index,
    );
  });

  testWidgets('travel route ticket uses clean Chinese timeline labels',
      (tester) async {
    final travelProvider = _FakeTravelProviderWithSpots();
    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<TravelProvider>.value(value: travelProvider),
          ChangeNotifierProvider<MapPrefsProvider>(create: (_) => MapPrefsProvider()),
        ],
        child: const MaterialApp(home: TravelMainScreen()),
      ),
    );

    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('travel_itinerary_ticket')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.textContaining('第 1 天'), findsWidgets);
    expect(find.textContaining('Day'), findsNothing);
  });

  test('kitchen order parsing keeps item snapshots and totals', () {
    final order = KitchenOrder.fromJson(const {
      'id': 7,
      'status': 'done',
      'orderer_id': 32,
      'cook_id': 33,
      'total_price': 59,
      'items': [
        {'dish_id': 3, 'name': '红烧肉', 'emoji': '🍖', 'price': 35, 'quantity': 1},
        {'dish_id': 4, 'name': '番茄炒蛋', 'emoji': '🍅', 'price': 12, 'quantity': 2},
      ],
      'photo_url': '/uploads/kitchen/a.jpg',
      'beans_awarded': 1,
    });

    expect(order.items.length, 2);
    expect(order.items.first.name, '红烧肉');
    expect(order.items.last.quantity, 2);
    expect(order.totalPrice, 59);
    expect(order.status, 'done');
    expect(order.isActive, isFalse);
    expect(order.beansAwarded, isTrue);
  });

  testWidgets('kitchen orders screen shows empty states for both tabs',
      (tester) async {
    final kitchen = KitchenProvider()
      ..incoming = const []
      ..outgoing = const [];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<KitchenProvider>.value(value: kitchen),
        ],
        child: const MaterialApp(home: KitchenOrdersScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('还没有收到订单'), findsOneWidget);
  });

  testWidgets('profile screen keeps the archive-style sections',
      (tester) async {
    final authProvider = _FakeAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('关系资料夹'), findsWidgets);
    expect(find.text('关系档案'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('回忆与管理'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('回忆与管理'), findsOneWidget);
    expect(find.text('相册与回忆照片'), findsOneWidget);
    expect(find.text('旅行票根'), findsOneWidget);
  });
}

class _FakeAuthProvider extends AuthProvider {
  @override
  Map<String, dynamic>? get user => const {
        'id': 1,
        'nickname': '小可爱',
        'role': 'boy',
        'loveStartDate': '2022-03-05',
      };

  @override
  int? get userId => 1;

  @override
  int get loveDays => 520;
}

class _InitializingAuthProvider extends AuthProvider {
  @override
  bool get isInitializing => true;

  @override
  bool get isLoggedIn => false;
}

class _IdleAuthProvider extends AuthProvider {
  @override
  bool get isLoading => false;

  @override
  bool get isInitializing => false;

  @override
  bool get isLoggedIn => false;
}

class _FakeHomeProvider extends HomeProvider {
  _FakeHomeProvider() {
    today = {
      'loveDays': 520,
      'beanBalance': 88,
      'feed': {
        'title': '芝芝桃桃',
        'shop': '喜茶',
        'statusLabel': '待接单',
        'price': 25,
        'operator': '大白',
      },
      'todo': {
        'total': 3,
        'active': 1,
        'items': [
          {
            'title': '一起选旅行酒店',
            'dueDate': '今晚',
          },
          {
            'title': '提醒她带伞',
            'dueDate': '明早',
          },
        ],
      },
      'finance': {
        'totalSpent': 1520,
        'remaining': 480,
      },
      'course': {
        'title': '高等数学',
        'time': '14:00',
        'location': '教二楼 302',
        'weekday': '周四',
        'total': 5,
      },
      'travelPreview': {
        'title': '旅行计划',
        'city': '厦门之旅',
        'subtitle': '一起去看海呀~',
        'startDate': '05.20',
        'endDate': '05.24',
        'duration': '4 天 3 晚',
        'progress': '已规划 3/6',
        'people': 2,
      },
    };
    memory = {
      'title': '岳麓山晚风',
      'subtitle': '一起吹着晚风，聊着未来的样子。',
      'eventDate': '2026-04-09',
      'location': '杭州 · 钱塘江边',
    };
    checkedIn = true;
    recentAchievements = const [];
    isLoading = false;
    error = null;
  }

  @override
  Future<void> refresh() async {}
}

class _FakeTravelProvider extends TravelProvider {
  @override
  Future<void> refreshAll() async {}
}

class _FakeTravelProviderWithSpots extends TravelProvider {
  final List<TravelSpot> _fakeSpots = [
    TravelSpot(
      id: 1,
      name: '橘子洲头',
      city: '长沙',
      address: '岳麓区橘子洲头 2 号',
      lat: 28.195,
      lng: 112.962,
      status: 'wish',
      routeDay: 1,
      routeOrder: 1,
    ),
    TravelSpot(
      id: 2,
      name: '湖南省博物馆',
      city: '长沙',
      address: '开福区东风路 50 号',
      lat: 28.214,
      lng: 112.989,
      status: 'planned',
      routeDay: 1,
      routeOrder: 2,
    ),
  ];

  @override
  List<TravelSpot> get spots => _fakeSpots;

  @override
  List<TravelSpot> get filteredSpots => _fakeSpots;

  @override
  List<TravelSpot> get mapSpots => _fakeSpots;

  @override
  List<TravelRoute> get routes => const [];

  @override
  TravelRoute? get activeRoute => null;

  @override
  TravelStats get computedStats => TravelStats(
        wish: 1,
        planned: 1,
        cities: 1,
      );

  @override
  bool get loading => false;

  @override
  bool get routeLoading => false;

  @override
  String? get error => null;

  @override
  String? get routeError => null;

  @override
  Future<void> refreshAll() async {}
}
