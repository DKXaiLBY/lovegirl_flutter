import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/screens/profile/profile_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

Response<dynamic> response(dynamic data) => Response(
    requestOptions: RequestOptions(), data: {'code': 200, 'data': data});

class ProfileApi implements ApiService {
  bool fail = false;
  Completer<Response<dynamic>>? pending;
  int reads = 0;
  List<Map<String, dynamic>> dates = [];
  @override
  Future<Response<dynamic>> getCoupleStatus() async {
    reads++;
    if (reads == 1 && pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return response({
      'coupled': true,
      'partner': {'nickname': '伴侣'}
    });
  }

  @override
  Future<Response<dynamic>> getAnniversaries() async => response(dates);
  @override
  Future<Response<dynamic>> getPhotos() async => response([]);
  @override
  Future<Response<dynamic>> getCreations() async => response([]);
  @override
  dynamic noSuchMethod(Invocation call) => throw UnimplementedError();
}

class ProfileAuth extends AuthProvider {
  int id = 7;
  @override
  int get userId => id;
  @override
  Map<String, dynamic> get user => {'id': id, 'nickname': '自己'};
  void change() {
    id++;
    notifyListeners();
  }
}

void main() {
  Future<void> show(WidgetTester tester, ProfileApi api, ProfileAuth auth,
      {bool dark = false, double scale = 1}) async {
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
            home: ProfileScreen(api: api))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
      'missing relationship start date prompts setup instead of inventing a day count',
      (tester) async {
    await show(tester, ProfileApi(), ProfileAuth());
    expect(find.text('设置属于你们的纪念日起点'), findsOneWidget);
    expect(find.textContaining('在一起的第'), findsNothing);
  });
  testWidgets('relationship failure is not displayed as an unbound couple',
      (tester) async {
    await show(tester, ProfileApi()..fail = true, ProfileAuth());
    expect(find.text('尚未绑定伴侣'), findsNothing);
    expect(find.text('关系暂未读取'), findsWidgets);
  });

  testWidgets('a recorded start date produces its real inclusive day count',
      (tester) async {
    final date = DateTime.now().subtract(const Duration(days: 2));
    final api = ProfileApi()
      ..dates = [
        {
          'type': 'love',
          'title': '恋爱纪念日',
          'eventDate':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        }
      ];
    await show(tester, api, ProfileAuth());
    expect(find.text('在一起的第3天'), findsOneWidget);
    expect(find.text('设置属于你们的纪念日起点'), findsNothing);
  });
  testWidgets('old partner response is discarded after account switch',
      (tester) async {
    final api = ProfileApi()..pending = Completer<Response<dynamic>>();
    final auth = ProfileAuth();
    await show(tester, api, auth);
    auth.change();
    await tester.pump();
    await tester.pump();
    api.pending!.complete(response({
      'coupled': true,
      'partner': {'nickname': '上一账号的伴侣'}
    }));
    await tester.pump();
    expect(find.textContaining('上一账号'), findsNothing);
  });
  for (final dark in [false, true]) {
    testWidgets(
        'profile fits large text and preserves working management routes, dark=$dark',
        (tester) async {
      await show(tester, ProfileApi(), ProfileAuth(), dark: dark, scale: 1.4);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('管理纪念日'), findsOneWidget);
      expect(find.text('双方资料'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
