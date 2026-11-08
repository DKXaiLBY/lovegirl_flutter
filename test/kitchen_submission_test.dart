import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/providers/kitchen_provider.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/screens/kitchen/kitchen_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';

class _Api implements ApiService {
  int orderCalls = 0;
  final checkouts = <Map<String, dynamic>>[];
  Map<String, dynamic>? adjusted;
  Map<String, dynamic>? orderDetail;
  bool adjustmentFails = false;
  int peer = 2;
  Object? orderFailure;
  bool dishFails = false;
  int statusCalls = 0;
  int uploadCalls = 0;
  bool statusFails = false;
  Map? lastStatusExtra;
  Completer<Response>? pendingStatus;
  List<Map<String, dynamic>> incoming = [];
  bool menuBound = true;
  bool menuFails = false;
  List<Map<String, dynamic>> mine = [];
  List<Map<String, dynamic>> dishes = [
    {'id': 1, 'user_id': 2, 'name': '番茄炒蛋', 'price': 0, 'category': '家常菜'}
  ];
  Completer<Response>? pending;
  Future<Response> response(dynamic value) async => Response(
      requestOptions: RequestOptions(), data: {'code': 200, 'data': value});
  DioException rejected() => DioException(
      requestOptions: RequestOptions(),
      response: Response(
          requestOptions: RequestOptions(),
          statusCode: 409,
          data: {'message': '测试：暂时不能保存'}));
  @override
  Future<Response> getKitchenMenu() => menuFails
      ? Future.error(rejected())
      : response({
          'bound': menuBound,
          'partner': menuBound ? {'id': peer, 'nickname': 'QA partner'} : null,
          'mine': mine,
          'partner_dishes': dishes,
        });
  @override
  Future<Response> getKitchenOrders() =>
      response({'incoming': incoming, 'outgoing': []});
  @override
  Future<Response> getKitchenSummary() => response({'bound': menuBound});
  @override
  Future<Response> createKitchenOrder(Map data) {
    orderCalls++;
    checkouts.add(Map<String, dynamic>.from(data));
    if (orderFailure != null) return Future.error(orderFailure!);
    return pending?.future ?? response({'id': 11});
  }

  @override
  Future<Response> getKitchenOrder(int id) => response(orderDetail);

  @override
  Future<Response> updateKitchenOrder(int id, Map data) {
    adjusted = Map<String, dynamic>.from(data);
    if (adjustmentFails) return Future.error(rejected());
    return response({'id': id});
  }

  @override
  Future<Response> createKitchenDish(Map data) =>
      dishFails ? Future.error(rejected()) : response({'id': 12});
  @override
  Future<Response> updateKitchenOrderStatus(int id, String status,
      {Map? extra}) async {
    statusCalls++;
    lastStatusExtra = extra;
    if (statusFails) throw rejected();
    if (pendingStatus != null) await pendingStatus!.future;
    incoming = incoming
        .map(
            (order) => order['id'] == id ? {...order, 'status': status} : order)
        .toList();
    return response({'id': id, 'status': status});
  }

  @override
  Future<Response> uploadKitchenPhoto(String filePath) {
    uploadCalls++;
    return response({'url': '/uploads/qa.jpg'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => response([]);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  KitchenProvider provider(_Api api) => KitchenProvider(api: api)
    ..setAccount(1)
    ..bound = true
    ..partnerId = 2
    ..menuLoaded = true
    ..cart[1] = 1;

  KitchenProvider acceptedMeal(_Api api) {
    api.incoming = [
      {
        'id': 8,
        'cook_id': 1,
        'orderer_id': 2,
        'status': 'accepted',
        'items': [
          {'dish_id': 1, 'name': '番茄炒蛋', 'quantity': 1, 'price': 0}
        ]
      }
    ];
    return KitchenProvider(api: api)
      ..setAccount(1)
      ..incoming = api.incoming.map(KitchenOrder.fromJson).toList();
  }

  test(
      'one pending meal status request disables duplicates and keeps expected status',
      () async {
    final api = _Api()..pendingStatus = Completer<Response>();
    final kitchen = acceptedMeal(api);
    final first = kitchen.updateOrderStatus(8, 'done');
    expect(kitchen.isOrderBusy(8), isTrue);
    expect(await kitchen.updateOrderStatus(8, 'done'), '正在处理这一餐，请稍候');
    expect(api.statusCalls, 1);
    expect(api.lastStatusExtra?['expected_status'], 'accepted');
    api.pendingStatus!.complete(await api.response({}));
    expect(await first, isNull);
    expect(kitchen.isOrderBusy(8), isFalse);
    expect(kitchen.incoming.single.status, 'done');
  });

  Future<void> showMeal(WidgetTester tester, KitchenProvider kitchen,
      {bool large = false}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<KitchenProvider>.value(value: kitchen),
        ChangeNotifierProvider(create: (_) => MapPrefsProvider()),
      ],
      child: MaterialApp(
          theme: LoveGirlTheme.lightTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(large ? 1.4 : 1)),
              child: child!),
          home: const KitchenOrdersScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'accepted meal has visible undo and can finish without uploading a photo',
      (tester) async {
    final api = _Api();
    final kitchen = acceptedMeal(api);
    await showMeal(tester, kitchen, large: true);
    expect(find.text('撤销接单'), findsOneWidget);
    await tester.tap(find.text('开饭了'));
    await tester.pumpAndSettle();
    expect(find.text('确认开饭'), findsOneWidget);
    await tester.tap(find.text('确认开饭'));
    await tester.pumpAndSettle();
    expect(api.statusCalls, 1);
    expect(api.uploadCalls, 0);
    expect(kitchen.incoming.single.status, 'done');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed meal completion retains the confirmation sheet and can retry',
      (tester) async {
    final api = _Api()..statusFails = true;
    final kitchen = acceptedMeal(api);
    await showMeal(tester, kitchen);
    await tester.tap(find.text('开饭了'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认开饭'));
    await tester.pumpAndSettle();
    expect(find.text('开饭了，留下这一餐'), findsOneWidget);
    expect(kitchen.incoming.single.status, 'accepted');
    expect(kitchen.isOrderBusy(8), isFalse);
    api.statusFails = false;
    await tester.tap(find.text('确认开饭'));
    await tester.pumpAndSettle();
    expect(api.statusCalls, 2);
    expect(kitchen.incoming.single.status, 'done');
    expect(find.text('开饭了，留下这一餐'), findsNothing);
  });

  testWidgets(
      'undo changes the accepted meal back to waiting without a hidden drag timer',
      (tester) async {
    final api = _Api();
    final kitchen = acceptedMeal(api);
    await showMeal(tester, kitchen);
    await tester.tap(find.text('撤销接单'));
    await tester.pumpAndSettle();
    expect(kitchen.incoming.single.status, 'placed');
    expect(find.text('接下这一餐'), findsOneWidget);
    expect(api.lastStatusExtra?['expected_status'], 'accepted');
  });

  test(
      'a non-network exception returns a retryable error and preserves selection',
      () async {
    final api = _Api()..orderFailure = StateError('decode failed');
    final kitchen = provider(api);
    expect(await kitchen.placeOrder('少辣'), '下单失败，请稍后再试');
    expect(kitchen.cart, {1: 1});
    expect(api.orderCalls, 1);
  });

  test('one pending checkout produces one request even when tapped twice',
      () async {
    final api = _Api()..pending = Completer<Response>();
    final kitchen = provider(api);
    final first = kitchen.placeOrder('少辣');
    final second = kitchen.placeOrder('少辣');
    api.pending!.complete(await api.response({'id': 11}));
    expect(await first, isNull);
    expect(await second, '正在提交，请稍候');
    expect(api.orderCalls, 1);
    expect(kitchen.cart, isEmpty);
  });

  test('a rejected order keeps the cart and can be submitted again', () async {
    final api = _Api();
    api.orderFailure = api.rejected();
    final kitchen = provider(api);
    expect(await kitchen.placeOrder('少辣'), '测试：暂时不能保存');
    expect(kitchen.cart, {1: 1});
    api.orderFailure = null;
    expect(await kitchen.placeOrder('少辣'), isNull);
    expect(api.orderCalls, 2);
    expect(kitchen.cart, isEmpty);
  });

  test(
      'checkout retries the same intent with one key and uses a new key for a changed plan',
      () async {
    final api = _Api()..orderFailure = StateError('response lost');
    final kitchen = provider(api);
    await kitchen.placeOrder('少辣', mealDate: '2026-11-07', mealSlot: 'dinner');
    await kitchen.placeOrder('少辣', mealDate: '2026-11-07', mealSlot: 'dinner');
    await kitchen.placeOrder('少辣', mealDate: '2026-11-08', mealSlot: 'dinner');
    expect(api.checkouts[0]['request_key'], isNotEmpty);
    expect(api.checkouts[0]['request_key'], api.checkouts[1]['request_key']);
    expect(api.checkouts[2]['request_key'],
        isNot(api.checkouts[1]['request_key']));
    expect(api.checkouts[2]['meal_date'], '2026-11-08');
    expect(kitchen.cart, {1: 1});
    kitchen.dispose();
  });

  test(
      'choosing myself clears the previous menu selection and keeps the partner as a participant',
      () async {
    final api = _Api()..orderFailure = StateError('response lost');
    final kitchen = provider(api);
    kitchen.selectChef(true);
    expect(kitchen.cart, isEmpty);
    kitchen.addToCart(7);
    await kitchen.placeOrder('一起开饭', mealSlot: 'lunch');
    expect(api.checkouts.single['cook_id'], 1);
    expect(api.checkouts.single['partner_id'], 2);
    expect(api.checkouts.single['meal_slot'], 'lunch');
    expect(api.checkouts.single['items'], [
      {'dish_id': 7, 'quantity': 1}
    ]);
    kitchen.dispose();
  });

  test('old checkout response cannot clear a new relationship cart', () async {
    final api = _Api()..pending = Completer<Response>();
    final kitchen = provider(api);
    final previous = kitchen.placeOrder('old note');
    api.peer = 3;
    api.dishes = [
      {'id': 9, 'user_id': 3, 'name': '新菜单'}
    ];
    await kitchen.loadMenu();
    expect(kitchen.cart, isEmpty);
    expect(kitchen.placingOrder, isFalse);
    kitchen.addToCart(9);
    api.pending!.complete(await api.response({'id': 11}));
    expect(await previous, contains('绑定关系已变化'));
    expect(kitchen.cart, {9: 1});
    kitchen.dispose();
  });

  test(
      'detail keeps the viewed version, recipes and the journal link; a rejected adjustment stays retryable',
      () async {
    final api = _Api()
      ..adjustmentFails = true
      ..orderDetail = {
        'id': 8,
        'orderer_id': 1,
        'partner_id': 2,
        'cook_id': 2,
        'revision': '3',
        'meal_date': '2026-11-07',
        'meal_slot': 'lunch',
        'cooking_log_id': 20,
        'items': [
          {
            'dish_id': 1,
            'name': '番茄炒蛋',
            'quantity': 2,
            'ingredients': '番茄、鸡蛋',
            'recipe': '先炒鸡蛋'
          }
        ],
      };
    final kitchen = provider(api);
    final (order, error) = await kitchen.getOrder(8);
    expect(error, isNull);
    expect(order!.items.single.recipe, '先炒鸡蛋');
    expect(order.cookingLogId, 20);
    final draft = {
      'revision': order.revision,
      'note': '少辣',
      'meal_date': order.mealDate,
      'items': order.items.map((item) => item.toMap()).toList()
    };
    expect(await kitchen.updateOrder(8, draft), '测试：暂时不能保存');
    expect(api.adjusted, draft);
    expect(kitchen.isOrderBusy(8), isFalse);
    kitchen.dispose();
  });

  Future<void> show(WidgetTester tester, KitchenProvider kitchen,
      {int tab = 0, bool dark = false, bool large = false}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<KitchenProvider>.value(value: kitchen),
          ChangeNotifierProvider(create: (_) => MapPrefsProvider()),
        ],
        child: MaterialApp(
            theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(large ? 1.4 : 1)),
                child: child!),
            home: KitchenScreen(initialTab: tab))));
    await tester.pumpAndSettle();
  }

  testWidgets('rejected checkout keeps its note and confirmation sheet open',
      (tester) async {
    final api = _Api();
    api.orderFailure = api.rejected();
    final kitchen = provider(api);
    await show(tester, kitchen);
    await tester.tap(find.text('确认这餐'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((w) =>
            w is TextField && w.decoration?.hintText == '给主厨留言，比如：周五晚上想吃～'),
        'QA note');
    await tester.tap(find.text('提交这一餐'));
    await tester.pumpAndSettle();
    expect(find.text('确认这一餐'), findsOneWidget);
    expect(find.text('QA note'), findsOneWidget);
    expect(kitchen.cart, {1: 1});
  });

  testWidgets('a dish without a photograph renders its default card',
      (tester) async {
    await show(tester, provider(_Api()));
    expect(find.text('番茄炒蛋'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'changing chef needs confirmation and checkout carries the new menu and meal plan',
      (tester) async {
    final api = _Api()
      ..mine = [
        {'id': 7, 'user_id': 1, 'name': '我的青菜'}
      ];
    final kitchen = provider(api);
    await show(tester, kitchen);
    Future<void> chooseMine() async {
      await tester.tap(find.widgetWithText(TextButton, 'TA掌勺'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我来掌勺'));
      await tester.pumpAndSettle();
    }

    await chooseMine();
    await tester.tap(find.text('保留选菜'));
    await tester.pumpAndSettle();
    expect(kitchen.cart, {1: 1});
    await chooseMine();
    await tester.tap(find.widgetWithText(FilledButton, '更换主厨'));
    await tester.pumpAndSettle();
    expect(kitchen.cart, isEmpty);
    expect(find.text('我的青菜'), findsOneWidget);
    expect(find.text('番茄炒蛋'), findsNothing);
    await tester.tap(find.byTooltip('增加我的青菜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认这餐'));
    await tester.pumpAndSettle();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await tester.ensureVisible(find.text('选择用餐日期'));
    await tester.tap(find.text('选择用餐日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('时段未定'));
    await tester.tap(find.text('时段未定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('午餐').last);
    await tester.pumpAndSettle();
    api.incoming = [
      {
        'id': 11,
        'orderer_id': 1,
        'partner_id': 2,
        'cook_id': 1,
        'status': 'placed',
        'items': [
          {'dish_id': 7, 'name': '我的青菜', 'quantity': 1}
        ]
      }
    ];
    await tester.ensureVisible(find.text('提交这一餐'));
    await tester.tap(find.text('提交这一餐'));
    await tester.pumpAndSettle();
    expect(api.checkouts.single['cook_id'], 1);
    expect(api.checkouts.single['partner_id'], 2);
    expect(api.checkouts.single['meal_date'], today);
    expect(api.checkouts.single['meal_slot'], 'lunch');
    expect(find.text('接下这一餐'), findsOneWidget);
  });

  testWidgets(
      'a long checkout is scrollable above the keyboard and keeps the failed note',
      (tester) async {
    final api = _Api()
      ..dishes = List.generate(
          12, (i) => {'id': i + 1, 'user_id': 2, 'name': '小菜${i + 1}'});
    api.orderFailure = api.rejected();
    final kitchen = provider(api);
    for (var i = 2; i <= 12; i++) {
      kitchen.cart[i] = 1;
    }
    await show(tester, kitchen, large: true);
    await tester.tap(find.text('确认这餐'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pumpAndSettle();
    final note = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '给主厨留言，比如：周五晚上想吃～');
    await tester.ensureVisible(note);
    await tester.enterText(note, 'keyboard note');
    await tester.ensureVisible(find.text('提交这一餐'));
    await tester.tap(find.text('提交这一餐'));
    await tester.pumpAndSettle();
    expect(find.text('keyboard note'), findsOneWidget);
    expect(api.checkouts.single['note'], 'keyboard note');
    expect(kitchen.cart.length, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rejected meal adjustment keeps the viewed version and the edited fields',
      (tester) async {
    final api = _Api()
      ..adjustmentFails = true
      ..mine = [
        {'id': 1, 'user_id': 1, 'name': '番茄炒蛋'}
      ];
    final kitchen = acceptedMeal(api);
    api.orderDetail = {
      ...api.incoming.single,
      'revision': 3,
      'meal_date': '2026-11-07',
      'meal_slot': 'dinner',
      'note': '旧备注'
    };
    await show(tester, kitchen, tab: 1);
    await tester.tap(find.text('调整餐次'));
    await tester.pumpAndSettle();
    final note = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == '口味与备注');
    await tester.ensureVisible(note);
    await tester.enterText(note, '少辣，晚点开饭');
    await tester.ensureVisible(find.text('保存调整'));
    await tester.tap(find.text('保存调整'));
    await tester.pumpAndSettle();
    expect(find.text('少辣，晚点开饭'), findsOneWidget);
    expect(find.text('读取最新餐次'), findsOneWidget);
    expect(api.adjusted?['revision'], 3);
    expect(api.adjusted?['meal_date'], '2026-11-07');
    expect(api.adjusted?['meal_slot'], 'dinner');
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo menu has two columns and search preserves selected dishes',
      (tester) async {
    final api = _Api()
      ..dishes = [
        {'id': 1, 'name': '番茄炒蛋', 'category': '家常菜'},
        {'id': 2, 'name': '青椒炒肉', 'category': '家常菜'},
        {'id': 3, 'name': '清炒时蔬', 'category': '素菜'},
        {'id': 4, 'name': '紫菜蛋花汤', 'category': '汤羹'},
      ];
    final kitchen = KitchenProvider(api: api);
    await show(tester, kitchen);
    final first = tester.getRect(find.byKey(const ValueKey('kitchen-dish-1')));
    final second = tester.getRect(find.byKey(const ValueKey('kitchen-dish-2')));
    expect(first.top, second.top);
    expect(second.left, greaterThan(first.right));
    await tester.tap(find.byTooltip('增加番茄炒蛋'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == '找一道想吃的菜'),
        '青椒');
    await tester.pumpAndSettle();
    expect(find.text('青椒炒肉'), findsOneWidget);
    expect(find.text('番茄炒蛋'), findsNothing);
    expect(kitchen.cart, {1: 1});
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '汤羹'));
    await tester.pumpAndSettle();
    expect(find.text('紫菜蛋花汤'), findsOneWidget);
    expect(find.text('番茄炒蛋'), findsNothing);
    expect(kitchen.cart, {1: 1});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unbound users can add their own dish without being blocked by binding',
      (tester) async {
    final api = _Api()..menuBound = false;
    await show(tester, KitchenProvider(api: api));
    expect(find.text('去绑定'), findsOneWidget);
    await tester.tap(find.text('+ 添加一道拿手菜'));
    await tester.pumpAndSettle();
    expect(find.text('添加拿手菜'), findsOneWidget);
    expect(find.text('菜名（必填）'), findsOneWidget);
  });

  testWidgets(
      'menu failure is retryable and does not pretend the couple is unbound',
      (tester) async {
    final api = _Api()..menuFails = true;
    await show(tester, KitchenProvider(api: api));
    expect(find.text('去绑定'), findsNothing);
    expect(find.text('重新加载菜单'), findsOneWidget);
    api.menuFails = false;
    await tester.tap(find.text('重新加载菜单'));
    await tester.pumpAndSettle();
    expect(find.text('番茄炒蛋'), findsOneWidget);
    expect(find.text('重新加载菜单'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'photo menu and detail remain usable at 360 wide, large type, dark=$dark',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final api = _Api()
          ..dishes = [
            {
              'id': 1,
              'name': '很长的拿手菜名称也能清楚看见',
              'description': '一段很长的口味推荐语，不应该挤压数量按钮',
              'category': '家常菜'
            },
            {'id': 2, 'name': '紫菜蛋花汤', 'category': '汤羹'},
          ];
        await show(tester, KitchenProvider(api: api), dark: dark, large: true);
        await tester.tap(find.byTooltip('增加很长的拿手菜名称也能清楚看见'));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byTooltip('减少很长的拿手菜名称也能清楚看见')).height,
            greaterThanOrEqualTo(48));
        await tester.tap(find.bySemanticsLabel('查看很长的拿手菜名称也能清楚看见详情'));
        await tester.pumpAndSettle();
        expect(find.text('回到菜单'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
      'current meal tab shows an accepted meal rather than menu management',
      (tester) async {
    final api = _Api();
    await show(tester, acceptedMeal(api), tab: 1);
    expect(find.text('开饭了'), findsOneWidget);
    expect(find.text('撤销接单'), findsOneWidget);
    expect(find.text('+ 添加一道拿手菜'), findsNothing);
  });

  test(
      'cart quantity agrees with the server maximum instead of silently truncating',
      () {
    final kitchen = KitchenProvider(api: _Api());
    for (var i = 0; i < 12; i++) {
      kitchen.addToCart(1);
    }
    expect(kitchen.cart, {1: 9});
    kitchen.dispose();
  });

  testWidgets(
      'a one-dish meal record does not reserve blank vertical separator columns',
      (tester) async {
    final api = _Api();
    final kitchen = acceptedMeal(api);
    api.incoming = api.incoming
        .map((o) => {...o, 'status': 'done', 'done_at': '2026-11-01 13:00:00'})
        .toList();
    await show(tester, kitchen, tab: 2);
    final receipt = find.widgetWithText(LoveTicketCard, '#8');
    expect(tester.getSize(receipt).height, lessThan(250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected new dish keeps the edited title in the form',
      (tester) async {
    final api = _Api()..dishFails = true;
    await show(tester, provider(api));
    await tester.tap(find.byTooltip('管理我的菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ 添加一道拿手菜'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == '菜名（必填）'),
        'QA dish');
    await tester.ensureVisible(find.text('挂上菜单'));
    await tester.tap(find.text('挂上菜单'));
    await tester.pumpAndSettle();
    expect(find.text('添加拿手菜'), findsOneWidget);
    expect(find.text('QA dish'), findsOneWidget);
  });
}
