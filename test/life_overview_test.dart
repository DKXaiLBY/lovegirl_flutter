import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/screens/life/life_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:provider/provider.dart';

class _Auth extends AuthProvider {
  @override
  int get userId => 7;
}

class _Api implements ApiService {
  final calls = <Symbol>[];

  Response<dynamic> _response(dynamic value) => Response(
      requestOptions: RequestOptions(), data: {'code': 200, 'data': value});

  @override
  Future<Response> getTodos() async {
    calls.add(#getTodos);
    return _response([
      {'id': 17, 'title': '整理相机', 'completed': 0}
    ]);
  }

  @override
  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    expect(path, '/api/study');
    return _response({
      'revision': 0,
      'document': {'cards': [], 'showOnToday': false}
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    return Future.value(_response([]));
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  Future<void> show(WidgetTester tester, _Api api, {bool dark = false}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(),
      child: MaterialApp(
        theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.4)),
          child: child!,
        ),
        home: LifeScreen(api: api),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('life loads task data only after entering the task page',
      (tester) async {
    final api = _Api();
    await show(tester, api);
    expect(api.calls, isEmpty);
    expect(find.text('去点菜'), findsOneWidget);
    expect(find.text('账本'), findsNothing);
    expect(find.text('衣橱资料'), findsNothing);
    await tester.tap(find.text('看待办'));
    await tester.pumpAndSettle();
    expect(api.calls, contains(#getTodos));
    expect(find.text('整理相机'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('life and all three subjects fit large text, dark=$dark',
        (tester) async {
      await show(tester, _Api(), dark: dark);
      expect(find.byType(BackdropFilter), findsNothing);
      await tester.tap(find.text('专升本备考'));
      await tester.pumpAndSettle();
      for (final subject in ['政治理论', '管理学', '基础会计学']) {
        expect(find.text(subject), findsOneWidget);
      }
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
