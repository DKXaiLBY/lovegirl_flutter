import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/screens/life/life_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _Auth extends AuthProvider {
  int account = 7;
  bool girl = false;
  @override
  int get userId => account;
  @override
  bool get isOriginalGirl => girl;
  void switchAccount() {
    account++;
    notifyListeners();
  }
}

class _Api implements ApiService {
  bool financeFails = false;
  bool toggleFails = false;
  int toggles = 0;
  int todoReads = 0;
  Completer<Response>? firstTodos;
  Completer<void>? saving;
  List<Map<String, dynamic>> todos = [
    {'id': 17, 'title': '整理相机', 'completed': 0}
  ];
  Future<Response> response(dynamic value) async => Response(
      requestOptions: RequestOptions(), data: {'code': 200, 'data': value});
  @override
  Future<Response> getTodos() {
    todoReads++;
    return todoReads == 1 && firstTodos != null
        ? firstTodos!.future
        : response(todos);
  }

  @override
  Future<Response> getFinanceStats(String month, {String? source}) {
    if (financeFails) return Future.error(Exception('offline'));
    return response({'expense': '2360.50'});
  }

  @override
  Future<Response> getKitchenMenu() =>
      response({'mine': [], 'partner_dishes': []});
  @override
  Future<Response> getWardrobeItems() => response([]);
  @override
  Future<Response> toggleTodo(int id) async {
    toggles++;
    if (saving != null) await saving!.future;
    if (toggleFails) throw Exception('offline');
    todos = [
      {'id': id, 'title': '整理相机', 'completed': 1}
    ];
    return response({});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => response([]);
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  Future<void> show(WidgetTester tester, _Api api, _Auth auth,
      {double scale = 1, bool dark = false}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: LifeScreen(api: api))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
      'overview shows real tasks and decimal expense without example records',
      (tester) async {
    final api = _Api();
    await show(tester, api, _Auth());
    expect(find.text('整理相机'), findsOneWidget);
    expect(find.text('还有1件小事'), findsOneWidget);
    expect(find.text('¥2,360.5'), findsOneWidget);
    expect(find.text('买晚餐食材'), findsNothing);
    expect(find.text('晚饭后一起散步'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed finance is distinguished from zero expenditure',
      (tester) async {
    await show(tester, _Api()..financeFails = true, _Auth());
    expect(find.text('暂未读取'), findsOneWidget);
    expect(find.text('账本暂未加载'), findsOneWidget);
    expect(find.text('¥0'), findsNothing);
  });

  testWidgets('failed task toggle preserves the task and allows retry',
      (tester) async {
    final api = _Api()..toggleFails = true;
    await show(tester, api, _Auth());
    await tester.tap(find.text('整理相机'));
    await tester.pump();
    expect(find.text('整理相机'), findsOneWidget);
    expect(find.text('没有修改成功，请再试一次'), findsOneWidget);
    api.toggleFails = false;
    await tester.tap(find.text('整理相机'));
    await tester.pump();
    expect(api.toggles, 2);
    expect(find.text('今天从容一点'), findsOneWidget);
  });

  testWidgets('pending task update cannot be submitted twice', (tester) async {
    final api = _Api()..saving = Completer<void>();
    await show(tester, api, _Auth());
    await tester.tap(find.text('整理相机'));
    await tester.tap(find.text('整理相机'));
    expect(api.toggles, 1);
    api.saving!.complete();
    await tester.pump();
    expect(find.text('今天从容一点'), findsOneWidget);
  });

  testWidgets('account switch discards an old pending private overview',
      (tester) async {
    final api = _Api()..firstTodos = Completer<Response>();
    final auth = _Auth();
    await show(tester, api, auth);
    auth.switchAccount();
    await tester.pump();
    await tester.pump();
    api.firstTodos!.complete(await api.response([
      {'id': 5, 'title': '上个账号的私密事项', 'completed': 0}
    ]));
    await tester.pump();
    expect(find.text('上个账号的私密事项'), findsNothing);
    expect(find.text('整理相机'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
        '360px overview works with larger text in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      await show(tester, _Api(), _Auth(), scale: 1.4, dark: dark);
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('经期记录'), findsNothing);
    });
  }
}
