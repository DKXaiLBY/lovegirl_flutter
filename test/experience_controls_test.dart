import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lovegirl_flutter/features/creations/creation_document.dart';
import 'package:lovegirl_flutter/features/travel/journey.dart';
import 'package:lovegirl_flutter/models/travel.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/screens/memories/memory_search_screen.dart';
import 'package:lovegirl_flutter/screens/memories/memories_screen.dart';
import 'package:lovegirl_flutter/screens/travel/journey_recap_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/app_haptics.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/glass_routes.dart';

class _Records implements ApiService {
  @override
  Future getJourneys() async => _response([
        {'id': 2, 'city': '厦门', 'title': '周末散步'}
      ]);

  @override
  Future getTravelSpots({String? status, String? city}) async => _response({
        'list': [
          {
            'id': 11,
            'city': '厦门',
            'name': '白城沙滩',
            'photos': ['/uploads/qa-coast.jpg']
          }
        ]
      });

  @override
  Future getTravelPhotos(int spotId) async => _response([
        {'url': '/uploads/qa-coast.jpg'}
      ]);

  @override
  Future getCreations() async => _response([_ticket]);

  @override
  Future getPhotos() async => _response([]);

  Response _response(Object value) => Response(
      requestOptions: RequestOptions(), data: {'code': 200, 'data': value});

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _ticket = {
  'id': 4,
  'ownerId': 7,
  'tripId': 2,
  'revision': 1,
  'previewUrl': '/uploads/qa-ticket.png',
  'sourceUrls': <String>[],
  'document':
      const CreationDocument(kind: 'ticket', title: '车站票根', date: '2026-11-15')
          .toJson(),
  'updatedAt': '2026-11-15T12:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dark dialog actions and highlighted dates keep sufficient contrast',
      () {
    final theme = glassNavigationTheme(LoveGirlTheme.darkTheme);
    final scheme = theme.colorScheme;
    double contrast(Color light, Color dark) =>
        (light.computeLuminance() + .05) / (dark.computeLuminance() + .05);
    expect(contrast(scheme.primary, theme.dialogTheme.backgroundColor!),
        greaterThan(7));
    expect(contrast(scheme.primary, scheme.onPrimary), greaterThan(7));
  });

  testWidgets('memory month and its picker use solid surfaces at large text',
      (tester) async {
    tester.view.physicalSize = const Size(640, 1440);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = glassNavigationTheme(LoveGirlTheme.darkTheme);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.45),
            ),
            child: child!),
        home: MemoriesScreen(api: _Records()),
      ),
    ));
    await tester.pump();
    final filter = find.widgetWithText(FilledButton, '全部月份 ▾');
    expect(
        tester.widget<FilledButton>(filter).style!.backgroundColor!.resolve({}),
        LoveGirlTheme.cardDark);
    await tester.tap(filter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor!.a, 1);
    await tester.tap(find.text('2026年11月'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('2026年11月 ▾'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'haptics are skipped while off and the preference survives a new instance',
      () async {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final events = <String>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') events.add(call.method);
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final setting = AppHaptics();
    await setting.load();
    await setting.selectionClick();
    await setting.setEnabled(false);
    await setting.lightImpact();
    await setting.mediumImpact();
    await setting.heavyImpact();
    final restored = AppHaptics();
    await restored.load();
    expect(restored.enabled, isFalse);
    await restored.selectionClick();
    expect(events.length, 1);
    await restored.setEnabled(true);
    await restored.selectionClick();
    expect(events.length, 2);
    setting.dispose();
    restored.dispose();
  });

  testWidgets(
      'location matches saved travel photos and tickets, and filters can be cleared',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MemorySearchScreen(
      works: [CreationWork.fromJson(_ticket)],
      api: _Records(),
      photos: const [
        {'id': 2, 'url': '/uploads/qa-coast.jpg', 'description': '海岸照片'},
        {'id': 3, 'url': '/uploads/qa-home.jpg', 'description': '日常照片'},
      ],
    )));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '厦门');
    await tester.pump();
    expect(find.text('海岸照片'), findsOneWidget);
    expect(find.text('车站票根'), findsOneWidget);
    expect(find.text('日常照片'), findsNothing);
    await tester.tap(find.text('票根'));
    await tester.pump();
    expect(find.text('车站票根'), findsOneWidget);
    expect(find.text('海岸照片'), findsNothing);
    await tester.tap(find.text('清除条件'));
    await tester.pump();
    expect(find.text('日常照片'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'recap prefills real sources and reopening preserves removed entries',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final journey = Journey(id: 2, title: '周末散步', stops: [
      JourneyStop(
          key: 'beach',
          spotId: 11,
          day: 0,
          place: TravelSpot(
              id: 11,
              name: '白城沙滩',
              status: 'visited',
              lat: 24.46,
              lng: 118.10)),
    ]);
    Widget page() => MaterialApp(
        home:
            JourneyRecapScreen(journey: journey, api: _Records(), account: 7));
    await tester.pumpWidget(page());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('第 1 天 · 已去'), findsOneWidget);
    expect(find.text('旅行照片'), findsOneWidget);
    expect(find.text('车站票根'), findsOneWidget);
    final ticketTile =
        find.ancestor(of: find.text('车站票根'), matching: find.byType(ListTile));
    final remove =
        find.descendant(of: ticketTile, matching: find.byTooltip('从回顾中移除'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(page());
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('车站票根'), findsNothing);
    expect(find.text('旅行照片'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
