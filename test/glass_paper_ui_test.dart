import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/features/travel/journey.dart';
import 'package:lovegirl_flutter/features/travel/journey_controller.dart';
import 'package:lovegirl_flutter/features/travel/journey_panel.dart';
import 'package:lovegirl_flutter/models/travel.dart';
import 'package:lovegirl_flutter/features/creations/creation_canvas.dart';
import 'package:lovegirl_flutter/features/creations/creation_document.dart';
import 'package:lovegirl_flutter/features/creations/creation_editor.dart';
import 'package:lovegirl_flutter/features/creations/creation_gallery.dart';
import 'package:lovegirl_flutter/features/creations/creation_material.dart';
import 'package:lovegirl_flutter/features/creations/creation_drafts.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/rebuild_controls.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/services/api_service.dart';

class _Drafts extends CreationDrafts {
  CreationDraft? saved;
  _Drafts() : super(71);
  @override
  Future<void> save(CreationDraft draft) async => saved = draft;
  @override
  Future<List<CreationDraft>> list({String? kind}) async => [];
}

class _Auth extends AuthProvider {
  @override
  int get userId => 71;
}

class _GalleryApi implements ApiService {
  final String kind;
  _GalleryApi(this.kind);
  @override
  Future<Response> getPhotos() async =>
      Response(requestOptions: RequestOptions(), data: {'data': []});
  @override
  Future<Response> getCreations({int? tripId}) async =>
      Response(requestOptions: RequestOptions(), data: {
        'data': [
          for (var id = 1; id < 3; id++)
            {
              'id': id,
              'clientId': 'qa-$id',
              'ownerId': 71,
              'revision': 1,
              'previewUrl': '/uploads/qa-unavailable.png',
              'sourceUrls': ['/uploads/qa-source-$id.png'],
              'document': CreationDocument(
                      kind: kind,
                      templateId: kind == 'ticket' ? 'landscape' : 'classic',
                      title: '一段足够长的回忆标题，用来验证窄屏',
                      note: '背面的故事',
                      date: '2026-10-24')
                  .toJson(),
              'updatedAt': '2026-10-27T10:00:00Z',
            }
        ]
      });
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '.dart_tool/ui-test-cache');
  });
  testWidgets(
      'glass button keeps its touch target, disabled state and reduced motion',
      (tester) async {
    var taps = 0;
    Future<void> show(bool enabled) => tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
                body: Center(
                    child: RebuildGlassButton(
                        label: '翻到背面',
                        icon: Icons.flip,
                        onPressed: enabled ? () => taps++ : null))))));
    await show(true);
    final button = find.byType(RebuildGlassButton);
    expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    await show(false);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final kind in ['polaroid', 'ticket']) {
      testWidgets(
          '$kind controls stay usable at 360px in ${dark ? 'dark' : 'light'} mode',
          (tester) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = _Drafts();
        final draft = CreationDraft(
            id: 'ui-$kind-$dark',
            ownerId: 71,
            document: CreationDocument(
                kind: kind,
                templateId: kind == 'ticket' ? 'landscape' : 'classic'),
            sourcePaths: const [],
            updatedAt: DateTime(2026, 10, 27));
        await tester.pumpWidget(MaterialApp(
            theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
            home: CreationEditor(draft: draft, store: store)));
        await tester.pumpAndSettle();
        if (kind == 'ticket') {
          await tester.tap(find.text('配色'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('更换票根配色').at(1));
          await tester.pumpAndSettle();
          final accent = store.saved!.document.accent;
          await tester.tap(find.text('背景'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('更换票面底色').at(1));
          await tester.pumpAndSettle();
          expect(store.saved!.document.accent, accent);
          expect(store.saved!.document.background, const Color(0xffdce5ed));
          await tester.tap(find.text('文字'));
          await tester.pumpAndSettle();
          expect(find.text('给这段旅途起个名字').hitTestable(), findsOneWidget);
          await tester.tap(find.text('照片'));
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.text('全部相纸 20'));
          await tester.pumpAndSettle();
          expect(find.text('相纸收藏').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          Navigator.of(tester.element(find.text('相纸收藏'))).pop();
          await tester.pumpAndSettle();
        }
        for (final label in ['成像', '涂鸦', '更多']) {
          if (kind == 'ticket' && find.text(label).evaluate().isEmpty) {
            await tester.tap(find.text('照片'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$kind $label');
        }
        expect(find.byType(CreationArtwork), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final kind in ['polaroid', 'ticket']) {
    testWidgets(
        '$kind collection keeps navigation and flip accessible with long text at 360px',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              theme: LoveGirlTheme.lightTheme,
              home: CreationGallery(
                  kind: kind, api: _GalleryApi(kind), drafts: _Drafts()))));
      // The image loader is deliberately pending: actions must remain usable.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text(kind == 'ticket' ? '制作票根' : '制作拍立得').hitTestable(),
          findsOneWidget);
      final flip = find.byTooltip('翻到背面').first;
      expect(flip.hitTestable(), findsOneWidget);
      await tester.tap(flip);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byTooltip('翻到正面').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(PageView), const Offset(-335, 0));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
          tester
              .widget<CreationBackdrop>(find.byType(CreationBackdrop))
              .imageUrl,
          endsWith('qa-source-2.png'));
      await tester.tap(find.text('草稿 0'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('收藏 2'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
          tester
              .widget<CreationBackdrop>(find.byType(CreationBackdrop))
              .imageUrl,
          endsWith('qa-source-1.png'));
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
  for (final scale in [1.15, 1.4]) {
    testWidgets(
        'Chinese look controls leave bottom clearance at $scale text scale',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: LoveGirlTheme.lightTheme,
          locale: const Locale('zh'),
          supportedLocales: const [Locale('zh')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 24)),
              child: child!),
          home: CreationEditor(
              store: _Drafts(),
              draft: CreationDraft(
                  id: 'native-bottom-clearance',
                  ownerId: 71,
                  sourcePaths: const [],
                  document: const CreationDocument(),
                  updatedAt: DateTime(2026, 10, 27)))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('成像'));
      await tester.pumpAndSettle();
      expect(
          tester.getBottomLeft(find.byType(Slider)).dy, lessThanOrEqualTo(752));
      expect(tester.getBottomLeft(find.text('强度')).dy, lessThanOrEqualTo(752));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('journey thumbnail uses an existing photo when cover is empty',
      (tester) async {
    final controller = JourneyController(71, api: _GalleryApi('polaroid'))
      ..select(Journey(id: 1, title: 'UI QA', stops: [
        JourneyStop(
            key: 'qa-photo',
            spotId: 1,
            day: 0,
            place: TravelSpot(
                id: 1,
                name: '有照片的地点',
                coverImage: '',
                photos: ['/uploads/qa-first.png']))
      ]));
    final scroll = ScrollController();
    final cards = ScrollController();
    await tester.pumpWidget(MaterialApp(
        theme: LoveGirlTheme.lightTheme,
        home: Scaffold(
            body: JourneyPanel(
                controller: controller,
                scrollController: scroll,
                cardsController: cards,
                expanded: true,
                onSelect: (_) {},
                onAdd: () {},
                onStory: (_) {}))));
    await tester.pump();
    expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .imageUrl,
        endsWith('/uploads/qa-first.png'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    scroll.dispose();
    cards.dispose();
  });
}
