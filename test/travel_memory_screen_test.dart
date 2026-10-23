import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/travel_memory_screen.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final client = _Client();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUpAll(() async {
    for (final font in {
      'MemoryQa': Platform.environment['LOVEGIRL_QA_FONT'],
      'MaterialIcons': Platform.environment['LOVEGIRL_QA_ICON_FONT'],
    }.entries) {
      if (font.value != null) {
        final loader = FontLoader(font.key)
          ..addFont(File(font.value!).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  for (final dark in [false, true]) {
    testWidgets('故事页在深浅色和大字体下保留正文及可读操作：dark=$dark', (tester) async {
      client.fail = false;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(MaterialApp(
          theme: (dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme)
              .copyWith(
            textTheme:
                (dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme)
                    .textTheme
                    .apply(fontFamily: 'MemoryQa'),
            appBarTheme: AppBarTheme(
              backgroundColor: dark ? LoveGirlTheme.cardDark : Colors.white,
              foregroundColor:
                  dark ? LoveGirlTheme.textPrimaryDark : LoveGirlTheme.primary,
              titleTextStyle: TextStyle(
                  fontFamily: 'MemoryQa',
                  fontSize: 20,
                  color: dark
                      ? LoveGirlTheme.textPrimaryDark
                      : LoveGirlTheme.primary),
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: TravelMemoryScreen(
              spot: TravelSpot(
            id: 7,
            name: '西湖傍晚散步',
            city: '杭州',
            status: 'visited',
            visitedDate: '2026-10-18',
            mood: '开心',
            weather: '晴天',
            diary: '沿着湖慢慢走，记下了普通又值得留住的一天。',
          )),
        ));
        await tester.pumpAndSettle();
        expect(find.text('编辑故事'), findsOneWidget);
        expect(find.text('生成票根'), findsOneWidget);
        expect(find.text('关联相册照片'), findsOneWidget);
        expect(find.textContaining('这次回忆还没有照片'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['LOVEGIRL_QA_OUTPUT'];
        if (output != null) {
          final name = dark ? 'dark' : 'light';
          await expectLater(find.byType(Scaffold).first,
              matchesGoldenFile(Uri.file('$output/story-$name.png')));
        }
      }, createHttpClient: (_) => client);
    });
  }

  testWidgets('照片失败显示重试，重试成功后展示真实空态', (tester) async {
    client.fail = true;
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(MaterialApp(
          home: TravelMemoryScreen(
        spot:
            TravelSpot(id: 7, name: '故事仍然保留', status: 'visited', diary: '原有手记'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('原有手记'), findsOneWidget);
      client.fail = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('重试'), findsNothing);
      expect(find.textContaining('这次回忆还没有照片'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  for (final creating in [true, false]) {
    test('保存失败向表单传播，不能当成成功：creating=$creating', () async {
      client.fail = true;
      await HttpOverrides.runZoned(() async {
        final provider = TravelProvider();
        final request = creating
            ? provider.createSpot({'name': '保留输入'})
            : provider.updateSpot(7, {'name': '保留输入'});
        await expectLater(request, throwsA(isA<DioException>()));
        expect(provider.hasError, isTrue);
        provider.dispose();
      }, createHttpClient: (_) => client);
    });
  }
}

class _Client implements HttpClient {
  bool fail = false;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(this);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  final _Client client;
  _Request(this.client);
  @override
  final HttpHeaders headers = _Headers();
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> close() async => _Response(client.fail);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final bool fail;
  _Response(this.fail);
  @override
  int get statusCode => fail ? 503 : 200;
  @override
  String get reasonPhrase => fail ? 'Service Unavailable' : 'OK';
  List<int> get body => utf8.encode(
      jsonEncode(fail ? {'message': '照片暂不可用'} : {'code': 200, 'data': []}));
  @override
  int get contentLength => body.length;
  @override
  HttpHeaders get headers => _Headers();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => [];
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(body).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  void forEach(void Function(String, List<String>) action) =>
      action('content-type', ['application/json; charset=utf-8']);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
