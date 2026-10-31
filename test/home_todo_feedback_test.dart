import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/providers/notification_provider.dart';
import 'package:lovegirl_flutter/providers/home_provider.dart';
import 'package:lovegirl_flutter/screens/home/home_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';

Response<dynamic> result(dynamic data) => Response(
    requestOptions: RequestOptions(), data: {'code': 200, 'data': data});

class _Api implements ApiService {
  bool fail = false;
  int toggles = 0;
  Completer<Response<dynamic>>? gate;
  Completer<Response<dynamic>>? todosGate;
  @override
  Future<Response<dynamic>> getTodos() async => todosGate != null
      ? todosGate!.future
      : result([
          {'id': 1, 'title': '第一件事', 'completed': 0},
          {'id': 2, 'title': '第二件事', 'completed': 0},
        ]);
  @override
  Future<Response<dynamic>> toggleTodo(int id) async {
    toggles++;
    if (gate != null) return gate!.future;
    if (fail) throw StateError('offline');
    return result({});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(result({}));
}

class _Auth extends AuthProvider {
  @override
  Map<String, dynamic> get user => {'id': 7, 'nickname': 'QA', 'role': 'boy'};
}

class _Notifications extends NotificationProvider {
  @override
  Future<void> refreshCount() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });
  test('failed home completion preserves the visible task and active count',
      () async {
    final api = _Api()..fail = true;
    final home = HomeProvider(api: api);
    await home.refresh();
    await home.toggleTodo(1, complete: true);
    expect(home.today!['todo']['active'], 2);
    expect((home.today!['todo']['items'] as List).map((e) => e['id']), [1, 2]);
    home.dispose();
  });

  test('a pending home completion cannot toggle the server twice', () async {
    final api = _Api()..gate = Completer<Response<dynamic>>();
    final home = HomeProvider(api: api);
    await home.refresh();
    final first = home.toggleTodo(1, complete: true);
    final repeated = home.toggleTodo(1, complete: true);
    api.gate!.complete(result({}));
    await Future.wait([first, repeated]);
    expect(api.toggles, 1);
    expect(home.today!['todo']['active'], 1);
    expect((home.today!['todo']['items'] as List).single['id'], 2);
    home.dispose();
  });

  test('changing accounts discards the old pending private home response',
      () async {
    final api = _Api()..todosGate = Completer<Response<dynamic>>();
    final home = HomeProvider(api: api)..setAccount(7);
    final old = home.refresh();
    home.setAccount(8);
    api.todosGate!.complete(result([
      {'id': 1, 'title': '旧账号的待办', 'completed': 0}
    ]));
    await old;
    expect(home.today, isNull);
    expect(home.memory, isNull);
    expect(home.isLoading, false);
    home.dispose();
  });

  test('a completed write cannot populate a newly selected account', () async {
    final api = _Api()..gate = Completer<Response<dynamic>>();
    final home = HomeProvider(api: api)..setAccount(7);
    await home.refresh();
    final old = home.toggleTodo(1, complete: true);
    home.setAccount(8);
    api.gate!.complete(result({}));
    await old;
    expect(home.today, isNull);
    expect(home.isTodoSaving(1), false);
    home.dispose();
  });

  testWidgets('a failed home row shows feedback and remains actionable',
      (tester) async {
    final api = _Api()..fail = true;
    final home = HomeProvider(api: api);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
      ChangeNotifierProvider<HomeProvider>.value(value: home),
      ChangeNotifierProvider<MapPrefsProvider>(
          create: (_) => MapPrefsProvider()),
      ChangeNotifierProvider<NotificationProvider>(
          create: (_) => _Notifications()),
    ], child: MaterialApp(home: HomeScreen(api: api))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('第一件事'));
    await tester.pump();
    expect(find.text('第一件事'), findsOneWidget);
    expect(find.text('没有修改成功，待办仍然保留，请再试一次'), findsOneWidget);
    expect(home.isTodoSaving(1), false);
    expect(home.today!['todo']['active'], 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 12));
    home.dispose();
  });
}
