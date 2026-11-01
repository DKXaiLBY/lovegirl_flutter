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

class _Api implements ApiService {
  int orderCalls = 0;
  Object? orderFailure;
  bool dishFails = false;
  int statusCalls = 0;
  int uploadCalls = 0;
  bool statusFails = false;
  Map? lastStatusExtra;
  Completer<Response>? pendingStatus;
  List<Map<String, dynamic>> incoming = [];
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
  Future<Response> getKitchenMenu() => response({
        'bound': true,
        'mine': [],
        'partner_dishes': [
          {'id': 1, 'user_id': 2, 'name': '番茄炒蛋', 'price': 0, 'category': '家常菜'}
        ]
      });
  @override
  Future<Response> getKitchenOrders() =>
      response({'incoming': incoming, 'outgoing': []});
  @override
  Future<Response> getKitchenSummary() => response({'bound': true});
  @override
  Future<Response> createKitchenOrder(Map data) {
    orderCalls++;
    if (orderFailure != null) return Future.error(orderFailure!);
    return pending?.future ?? response({'id': 11});
  }

  @override
  Future<Response> createKitchenDish(Map data) =>
      dishFails ? Future.error(rejected()) : response({'id': 12});
  @override
  Future<Response> updateKitchenOrderStatus(int id, String status, {Map? extra}) async {
    statusCalls++;
    lastStatusExtra = extra;
    if (statusFails) throw rejected();
    if (pendingStatus != null) await pendingStatus!.future;
    incoming = incoming.map((order) => order['id'] == id ? {...order, 'status': status} : order).toList();
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

  KitchenProvider provider(_Api api) => KitchenProvider(api: api)..cart[1] = 1;

  KitchenProvider acceptedMeal(_Api api) {
    api.incoming = [{'id': 8, 'cook_id': 1, 'orderer_id': 2, 'status': 'accepted',
      'items': [{'dish_id': 1, 'name': '番茄炒蛋', 'quantity': 1, 'price': 0}]}];
    return KitchenProvider(api: api)..incoming = api.incoming.map(KitchenOrder.fromJson).toList();
  }

  test('one pending meal status request disables duplicates and keeps expected status', () async {
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

  Future<void> showMeal(WidgetTester tester, KitchenProvider kitchen, {bool large = false}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<KitchenProvider>.value(value: kitchen),
        ChangeNotifierProvider(create: (_) => MapPrefsProvider()),
      ],
      child: MaterialApp(theme: LoveGirlTheme.lightTheme,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(large ? 1.4 : 1)), child: child!),
        home: const KitchenOrdersScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('accepted meal has visible undo and can finish without uploading a photo', (tester) async {
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

  testWidgets('failed meal completion retains the confirmation sheet and can retry', (tester) async {
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

  testWidgets('undo changes the accepted meal back to waiting without a hidden drag timer', (tester) async {
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

  Future<void> show(WidgetTester tester, KitchenProvider kitchen,
      {int tab = 0}) async {
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
            home: KitchenScreen(initialTab: tab))));
    await tester.pumpAndSettle();
  }

  testWidgets('rejected checkout keeps its note and confirmation sheet open',
      (tester) async {
    final api = _Api();
    api.orderFailure = api.rejected();
    final kitchen = provider(api);
    await show(tester, kitchen);
    await tester.tap(find.text('去下单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'QA note');
    await tester.tap(find.text('下单 · 等主厨开火'));
    await tester.pumpAndSettle();
    expect(find.text('确认订单'), findsOneWidget);
    expect(find.text('QA note'), findsOneWidget);
    expect(kitchen.cart, {1: 1});
  });

  testWidgets('a dish without a photograph renders its default card',
      (tester) async {
    await show(tester, provider(_Api()));
    expect(find.text('番茄炒蛋'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected new dish keeps the edited title in the form',
      (tester) async {
    final api = _Api()..dishFails = true;
    await show(tester, provider(api), tab: 1);
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
