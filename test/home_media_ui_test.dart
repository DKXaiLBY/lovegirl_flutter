import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/home_provider.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/providers/notification_provider.dart';
import 'package:lovegirl_flutter/screens/home/home_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

Response<dynamic> _result(dynamic data) => Response(
    requestOptions: RequestOptions(), data: {'code': 200, 'data': data});

class _Api implements ApiService {
  List<Map<String, dynamic>> photos = [], works = [];
  Map<String, dynamic>? memory;
  bool failMedia = false;
  int photoReads = 0;
  Completer<Response<dynamic>>? firstPhotos;
  Completer<Response<dynamic>>? pendingPhotos;
  @override
  Future<Response<dynamic>> getPhotos() async {
    photoReads++;
    if (pendingPhotos != null) return pendingPhotos!.future;
    if (firstPhotos != null && photoReads == 1) return firstPhotos!.future;
    if (failMedia) throw StateError('offline');
    return _result(photos);
  }

  @override
  Future<Response<dynamic>> getCreations() async {
    if (failMedia) throw StateError('offline');
    return _result(works);
  }

  @override
  Future<Response<dynamic>> getHomeToday() async => _result({'loveDays': 123});
  @override
  Future<Response<dynamic>> getHomeMemory() async => _result(memory);
  @override
  Future<Response<dynamic>> getCoupleStatus() async => _result({
        'coupled': true,
        'partner': {'id': 9, 'nickname': 'QA另一位', 'avatar': ''}
      });
  @override
  Future<Response<dynamic>> getPartnerRecent() async =>
      _result({'hasPartner': true, 'items': []});
  @override
  dynamic noSuchMethod(Invocation call) => Future.value(_result([
        #getTodos,
        #getAnniversaries,
        #getTravelTrips,
        #getTravelRoutes,
        #getTravelSpots
      ].contains(call.memberName)
          ? []
          : {}));
}

class _Auth extends AuthProvider {
  int account = 7;
  @override
  int get userId => account;
  @override
  Map<String, dynamic> get user =>
      {'id': account, 'nickname': 'QA', 'role': 'boy'};
  void switchAccount() {
    account++;
    notifyListeners();
  }
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
  Future<void> show(WidgetTester tester, _Api api, _Auth auth,
      {bool dark = false, double scale = 1.15}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProxyProvider<AuthProvider, HomeProvider>(
              create: (_) => HomeProvider(api: api),
              update: (_, auth, home) => home!..setAccount(auth.userId)),
          ChangeNotifierProvider<MapPrefsProvider>(
              create: (_) => MapPrefsProvider()),
          ChangeNotifierProvider<NotificationProvider>(
              create: (_) => _Notifications()),
        ],
        child: MaterialApp(
            theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: HomeScreen(api: api))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  testWidgets(
      'published polaroid source can lead the hero ahead of older album photos',
      (tester) async {
    final api = _Api()
      ..photos = [
        {
          'id': 1,
          'url': '/uploads/old.jpg',
          'description': '更早的照片',
          'created_at': '2026-10-10'
        }
      ]
      ..works = [
        {
          'id': 4,
          'sourceUrls': ['/uploads/published.jpg'],
          'updatedAt': '2026-10-30',
          'document': {
            'kind': 'polaroid',
            'title': '最近留下的照片',
            'date': '2026-10-24'
          },
          'tripTitle': '厦门散步'
        }
      ];
    await show(tester, api, _Auth());
    expect(find.byKey(const ValueKey('home_photo_hero')), findsOneWidget);
    expect(find.text('最近留下的照片'), findsOneWidget);
    expect(find.text('10月24日 · 厦门散步'), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is CachedNetworkImage &&
            w.imageUrl.endsWith('/uploads/published.jpg')),
        findsOneWidget);
    expect(find.text('更早的照片'), findsNothing);
    expect(find.text('在一起的第123天'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
      'an empty account gets a photo invitation without a made-up photo or memory',
      (tester) async {
    await show(tester, _Api(), _Auth());
    expect(find.text('留下一张两个人的照片'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_photo_hero')), findsNothing);
    expect(find.byKey(const ValueKey('home_memory_ticket')), findsNothing);
    expect(find.text('照片暂时没加载出来'), findsNothing);
    await finish(tester);
  });

  testWidgets(
      'an empty frame note keeps the existing photo description as its caption',
      (tester) async {
    final api = _Api()
      ..photos = [
        {
          'id': 1,
          'url': '/uploads/legacy.jpg',
          'frame_note': '',
          'description': '相片原来的记录',
          'created_at': '2026-10-30'
        }
      ];
    await show(tester, api, _Auth());
    expect(find.text('相片原来的记录'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('media failure is distinct from an empty album and can retry',
      (tester) async {
    final api = _Api()..failMedia = true;
    await show(tester, api, _Auth());
    expect(find.text('照片暂时没加载出来'), findsOneWidget);
    api.failMedia = false;
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('home_photo_empty')),
        matching: find.text('重试')));
    await tester.pump();
    expect(find.text('留下一张两个人的照片'), findsOneWidget);
    expect(find.text('照片暂时没加载出来'), findsNothing);
    expect(api.photoReads, 2);
    await finish(tester);
  });

  testWidgets('an old private photo response cannot populate the next account',
      (tester) async {
    final api = _Api()..firstPhotos = Completer<Response<dynamic>>();
    final auth = _Auth();
    expect(auth.userId, 7);
    await show(tester, api, auth);
    auth.switchAccount();
    expect(auth.userId, 8);
    await tester.pump();
    await tester.pump();
    api.firstPhotos!.complete(_result([
      {'url': '/uploads/private.jpg', 'description': '旧账号的私密照片'}
    ]));
    await tester.pump();
    expect(find.text('旧账号的私密照片'), findsNothing);
    expect(find.byKey(const ValueKey('home_photo_hero')), findsNothing);
    expect(find.text('留下一张两个人的照片'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('photo retry has a pending state and cannot be submitted twice',
      (tester) async {
    final api = _Api()..failMedia = true;
    await show(tester, api, _Auth());
    api.failMedia = false;
    api.pendingPhotos = Completer<Response<dynamic>>();
    final retry = find.descendant(
        of: find.byKey(const ValueKey('home_photo_empty')),
        matching: find.text('重试'));
    await tester.tap(retry);
    await tester.pump();
    final button = tester.widget<TextButton>(
        find.ancestor(of: retry, matching: find.byType(TextButton)));
    expect(button.onPressed, isNull);
    expect(find.text('正在找回你们的照片…'), findsOneWidget);
    expect(api.photoReads, 2);
    api.pendingPhotos!.complete(_result([]));
    await tester.pump();
    expect(find.text('留下一张两个人的照片'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('legacy generated travel titles and dates use concise Chinese',
      (tester) async {
    final api = _Api()
      ..memory = {
        'title': 'Travel check-in: 沙坡尾',
        'eventDate':
            DateTime.now().subtract(const Duration(days: 1)).toIso8601String()
      };
    await show(tester, api, _Auth());
    expect(find.text('沙坡尾'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.textContaining('Travel check-in:'), findsNothing);
    await finish(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('360px photo page remains usable with 1.4 text, dark=$dark',
        (tester) async {
      await show(
          tester,
          _Api()
            ..photos = [
              {
                'url': '/uploads/large-text.jpg',
                'description': '一段很长的照片标题，检查截断与按钮',
                'created_at': '2026-10-30'
              }
            ],
          _Auth(),
          dark: dark,
          scale: 1.4);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('记录今天'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  }
}
