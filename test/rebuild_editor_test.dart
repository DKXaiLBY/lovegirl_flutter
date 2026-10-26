import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/features/creations/creation_editor.dart';
import 'package:lovegirl_flutter/features/creations/creation_canvas.dart';
import 'package:lovegirl_flutter/features/creations/creation_document.dart';
import 'package:lovegirl_flutter/features/creations/creation_drafts.dart';
import 'package:lovegirl_flutter/features/creations/creation_preview.dart';
import 'package:lovegirl_flutter/features/travel/journey.dart';
import 'package:lovegirl_flutter/features/travel/journey_controller.dart';
import 'package:lovegirl_flutter/features/travel/journey_panel.dart';
import 'package:lovegirl_flutter/models/travel.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/services/api_service.dart';

class RoutePreviewApi implements ApiService {
  @override
  Future getAmapDirection(
          {required String origin,
          required String destination,
          String mode = 'driving',
          String? city,
          String? waypoints}) async =>
      Response(requestOptions: RequestOptions(), data: {
        'data': {
          'distance': 1200,
          'duration': 600,
          'path': [
            {'lat': 30, 'lng': 120},
            {'lat': 30.01, 'lng': 120.01}
          ]
        }
      });
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class MemoryDrafts extends CreationDrafts {
  CreationDraft? saved;
  int writes = 0;
  MemoryDrafts() : super(71);
  @override
  Future<void> save(CreationDraft draft) async {
    writes++;
    saved = draft;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
      'dark route comparison keeps selected controls readable and actions visible on Honor viewport',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = JourneyController(71, api: RoutePreviewApi())
      ..select(Journey(id: 9, title: 'Trip', stops: [
        JourneyStop(
            key: 'a',
            spotId: 1,
            day: 0,
            place: TravelSpot(id: 1, name: 'A', lat: 30, lng: 120)),
        JourneyStop(
            key: 'b',
            spotId: 2,
            day: 0,
            place: TravelSpot(id: 2, name: 'B', lat: 30.01, lng: 120.01))
      ]));
    await controller.routes();
    final scroll = ScrollController();
    final cards = ScrollController();
    await tester.pumpWidget(MaterialApp(
        theme: LoveGirlTheme.darkTheme,
        home: Scaffold(
            body: JourneyPanel(
                controller: controller,
                scrollController: scroll,
                cardsController: cards,
                expanded: true,
                onSelect: (_) {},
                onAdd: () {},
                onStory: (_) {}))));
    await tester.pumpAndSettle();
    final route = find.text('驾车 · 1.2 km · 10 分钟');
    final routeButton = tester.widget<TextButton>(find.ancestor(
        of: route, matching: find.byWidgetPredicate((w) => w is TextButton)));
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    expect(
        contrast(routeButton.style!.foregroundColor!.resolve({})!,
            LoveGirlTheme.cardDark),
        greaterThan(7));
    expect(
        contrast(
            routeButton.style!.iconColor!.resolve({})!, LoveGirlTheme.cardDark),
        greaterThan(7));
    await tester.tap(route);
    await tester.pumpAndSettle();
    expect(find.text('采用驾车').hitTestable(), findsOneWidget);
    expect(find.text('在高德地图中查看／导航').hitTestable(), findsOneWidget);
    final radio = tester
        .widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>))
        .first;
    expect(
        contrast(radio.activeColor!, LoveGirlTheme.cardDark), greaterThan(7));
    final filled = tester.widget<FilledButton>(find.ancestor(
        of: find.text('采用驾车'), matching: find.byType(FilledButton)));
    expect(
        contrast(filled.style!.foregroundColor!.resolve({})!,
            filled.style!.backgroundColor!.resolve({})!),
        greaterThan(7));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
    cards.dispose();
    controller.dispose();
  });
  test('external map URI preserves locations, names and all four route modes',
      () {
    for (final entry in const {
      'walking': 'walk',
      'bicycling': 'ride',
      'driving': 'car',
      'transit': 'bus'
    }.entries) {
      final uri = journeyNavigationUri(
          TravelSpot(id: 1, name: '湖边,和你 & 我', lat: 30, lng: 120),
          TravelSpot(id: 2, name: '下一站', lat: 31, lng: 121),
          entry.key);
      expect(uri.scheme, 'https');
      expect(uri.host, 'uri.amap.com');
      expect(uri.queryParameters['from'], '120.0,30.0,湖边，和你 & 我');
      expect(uri.queryParameters['mode'], entry.value);
      expect(uri.queryParameters['callnative'], '1');
    }
  });
  testWidgets('preview flips the whole work and resets zoom on changing sides',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: CreationPreview(
            document: CreationDocument(note: '背面的记录'),
            front: ColoredBox(color: Colors.blue))));
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    viewer.transformationController!.value = Matrix4.identity()..scale(3.0);
    await tester.tap(find.byTooltip('翻到背面'));
    await tester.pumpAndSettle();
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
    expect(find.byTooltip('翻到正面'), findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<CreationPainter>()
        .single;
    expect(painter.back, true);
    await tester.tap(find.byTooltip('翻到正面'));
    await tester.pumpAndSettle();
    expect(find.byType(ColoredBox), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'closing a focused story form keeps its fields alive through the transition',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryDrafts();
    final draft = CreationDraft(
        id: 'regression-editor',
        ownerId: 71,
        document: const CreationDocument(),
        sourcePaths: const [],
        updatedAt: DateTime.now());
    await tester.pumpWidget(MaterialApp(
        theme: LoveGirlTheme.lightTheme,
        home: CreationEditor(draft: draft, store: store)));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('文字／日期'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Title $i');
      await tester.enterText(find.byType(TextFormField).last, 'A story $i');
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
          tester
              .widget<CreationArtwork>(find.byType(CreationArtwork))
              .document
              .note,
          'A story $i');
    }
    expect(store.saved!.document.title, 'Title 2');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'closing focused journey details retains the edited value without disposed controllers',
      (tester) async {
    final controller = JourneyController(71)
      ..select(const Journey(id: 9, title: 'Original'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () =>
                        journeyDetails(context, controller, edit: true),
                    child: const Text('Edit'))))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated');
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.current!.title, 'Updated');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('stop notes survive closing their focused bottom sheet',
      (tester) async {
    final controller = JourneyController(71)
      ..select(Journey(id: 9, title: 'Trip', stops: [
        JourneyStop(
            key: 'a', spotId: 1, day: 0, place: TravelSpot(id: 1, name: 'A'))
      ]));
    final scroll = ScrollController();
    final cards = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: JourneyPanel(
                controller: controller,
                scrollController: scroll,
                cardsController: cards,
                expanded: true,
                onSelect: (_) {},
                onAdd: () {},
                onStory: (_) {}))));
    await tester.tap(find.byTooltip('移动、备注或移除'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Our plan');
    await tester.tap(find.text('保存备注'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.current!.stops.single.note, 'Our plan');
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
    cards.dispose();
    controller.dispose();
  });

  testWidgets('moving a stop also retains the note typed in the same sheet',
      (tester) async {
    final controller = JourneyController(71)
      ..select(Journey(id: 9, title: 'Trip', days: 2, stops: [
        JourneyStop(
            key: 'a', spotId: 1, day: 0, place: TravelSpot(id: 1, name: 'A'))
      ]));
    final scroll = ScrollController();
    final cards = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: JourneyPanel(
                controller: controller,
                scrollController: scroll,
                cardsController: cards,
                expanded: true,
                onSelect: (_) {},
                onAdd: () {},
                onStory: (_) {}))));
    await tester.tap(find.byTooltip('移动、备注或移除'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Keep this new note');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 2 天').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.current!.stops.single.day, 1);
    expect(controller.current!.stops.single.note, 'Keep this new note');
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
    cards.dispose();
    controller.dispose();
  });
  testWidgets('selected stop numbers remain readable in dark mode',
      (tester) async {
    final controller = JourneyController(71)
      ..select(Journey(id: 9, title: 'Trip', stops: [
        JourneyStop(
            key: 'a', spotId: 1, day: 0, place: TravelSpot(id: 1, name: 'A'))
      ]));
    controller.selectedKey = 'a';
    final scroll = ScrollController();
    final cards = ScrollController();
    await tester.pumpWidget(MaterialApp(
        theme: LoveGirlTheme.darkTheme,
        home: Scaffold(
            body: JourneyPanel(
                controller: controller,
                scrollController: scroll,
                cardsController: cards,
                expanded: true,
                onSelect: (_) {},
                onAdd: () {},
                onStory: (_) {}))));
    final badge = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final light = badge.backgroundColor!.computeLuminance();
    final dark = badge.foregroundColor!.computeLuminance();
    expect((light + .05) / (dark + .05), greaterThan(4.5));
    expect((1.05) / (const Color(0xff24798e).computeLuminance() + .05),
        greaterThan(4.5));
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
    cards.dispose();
    controller.dispose();
  });
  testWidgets('dragging the second ticket photo crops only that photo',
      (tester) async {
    final store = MemoryDrafts();
    final draft = CreationDraft(
        id: 'two-photo-crop',
        ownerId: 71,
        updatedAt: DateTime.now(),
        sourcePaths: const [],
        document: const CreationDocument(
            kind: 'ticket',
            templateId: 'couple',
            transforms: [CreationCrop(), CreationCrop()]));
    await tester.pumpWidget(
        MaterialApp(home: CreationEditor(draft: draft, store: store)));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(CreationArtwork));
    await tester.dragFrom(
        rect.topLeft + Offset(rect.width * .75, rect.height * .3),
        const Offset(60, 20));
    await tester.pumpAndSettle();
    final document =
        tester.widget<CreationArtwork>(find.byType(CreationArtwork)).document;
    expect(document.transforms[0].x, 0);
    expect(document.transforms[1].x, greaterThan(0));
    expect(store.saved!.document.transforms[1].x, document.transforms[1].x);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'look intensity previews continuously and persists once on release',
      (tester) async {
    final store = MemoryDrafts();
    final draft = CreationDraft(
        id: 'look-slider-draft',
        ownerId: 71,
        updatedAt: DateTime.now(),
        sourcePaths: const [],
        document: const CreationDocument());
    await tester.pumpWidget(
        MaterialApp(home: CreationEditor(draft: draft, store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('成像'));
    await tester.pumpAndSettle();
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(Slider)));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(store.writes, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(store.writes, 1);
    expect(store.saved!.document.intensity, lessThan(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
