import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/kitchen_provider.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/screens/cooking/cooking_log_screen.dart';
import 'package:lovegirl_flutter/screens/kitchen/kitchen_photo.dart';
import 'package:lovegirl_flutter/screens/kitchen/kitchen_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _SlowImages implements HttpClient {
  final requests = <Completer<HttpClientRequest>>[];
  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    final response = Completer<HttpClientRequest>();
    requests.add(response);
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends AuthProvider {
  @override
  int? get userId => 1;
}

class _Api implements ApiService {
  final mealRequests = <int>[];
  final logRequests = <int>[];
  Future<Response> response(dynamic data) async => Response(
        requestOptions: RequestOptions(),
        data: {'code': 200, 'data': data},
      );
  @override
  Future<Response> getKitchenOrder(int id) {
    mealRequests.add(id);
    return response({
      'id': id,
      'orderer_id': 1,
      'partner_id': 2,
      'cook_id': 2,
      'status': 'done',
      'revision': 3,
      'meal_date': '2026-11-07',
      'meal_slot': 'dinner',
      'cooking_log_id': 20,
      'items': [
        {
          'dish_id': 1,
          'name': '番茄炒蛋',
          'quantity': 1,
          'ingredients': '番茄和鸡蛋',
          'recipe': '先炒鸡蛋'
        }
      ],
    });
  }

  @override
  Future<Response> getCookingLog(int id) {
    logRequests.add(id);
    return response({
      'id': id,
      'chefId': 2,
      'title': '两个人的晚饭',
      'cookedAt': '2026-11-07',
      'kitchenOrderId': 8
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => response({});
}

Widget _app(_Api api, Widget home) => MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
      ChangeNotifierProvider(
          create: (_) => KitchenProvider(api: api)..setAccount(1)),
      ChangeNotifierProvider(create: (_) => MapPrefsProvider()),
    ], child: MaterialApp(theme: LoveGirlTheme.lightTheme, home: home));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  testWidgets(
      'photo loading, network failure, retry and absent photo have distinct states',
      (tester) async {
    final client = _SlowImages();
    debugNetworkImageHttpClientProvider = () => client;
    try {
      Widget photo(String? path) => MaterialApp(
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 160,
                      height: 140,
                      child: KitchenPhoto(path: path)))));
      await tester
          .pumpWidget(photo('http://invalid.test/kitchen-load-test.png'));
      await tester.pump();
      expect(find.text('照片载入中'), findsOneWidget);
      expect(client.requests.length, 1);
      client.requests.single
          .completeError(StateError('controlled image failure'));
      await tester.pumpAndSettle();
      expect(find.text('照片暂未载入'), findsOneWidget);
      expect(find.text('还没有照片'), findsNothing);
      await tester.tap(find.text('重试照片'));
      await tester.pump();
      await tester.pump();
      expect(client.requests.length, 2);
      expect(find.text('照片载入中'), findsOneWidget);
      client.requests.last
          .completeError(StateError('controlled retry failure'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(photo(null));
      await tester.pumpAndSettle();
      expect(find.text('还没有照片'), findsOneWidget);
      expect(find.text('重试照片'), findsNothing);
    } finally {
      debugNetworkImageHttpClientProvider = null;
    }
  });

  testWidgets('a meal opens its specific linked journal record',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(api, const KitchenMealScreen(orderId: 8)));
    await tester.pumpAndSettle();
    expect(api.mealRequests, [8]);
    expect(find.text('先炒鸡蛋'), findsOneWidget);
    await tester.ensureVisible(find.text('查看餐桌回忆'));
    await tester.tap(find.text('查看餐桌回忆'));
    await tester.pumpAndSettle();
    expect(tester.widget<CookingLogScreen>(find.byType(CookingLogScreen)).logId,
        20);
  });

  testWidgets('the journal returns to the original meal and shows its snapshot',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(_app(api, CookingLogScreen(logId: 20, api: api)));
    await tester.pumpAndSettle();
    expect(api.logRequests, [20]);
    await tester.ensureVisible(find.text('查看这一餐'));
    await tester.tap(find.text('查看这一餐'));
    await tester.pumpAndSettle();
    expect(api.mealRequests, [8]);
    expect(find.text('番茄和鸡蛋'), findsOneWidget);
    expect(find.text('先炒鸡蛋'), findsOneWidget);
  });
}
