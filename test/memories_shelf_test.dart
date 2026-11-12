import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/features/creations/creation_gallery.dart';
import 'package:lovegirl_flutter/screens/memories/memories_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/widgets/polaroid_frame.dart';

Response<dynamic> result(dynamic value) => Response(
    requestOptions: RequestOptions(), data: {'code': 200, 'data': value});

class ShelfApi implements ApiService {
  List<Map<String, dynamic>> photos = [];
  List<Map<String, dynamic>> works = [];
  bool fail = false;
  int reads = 0;
  Completer<Response<dynamic>>? first;
  @override
  Future<Response<dynamic>> getPhotos() async {
    reads++;
    if (reads == 1 && first != null) return first!.future;
    if (fail) throw StateError('offline');
    return result(photos);
  }

  @override
  Future<Response<dynamic>> getCreations() async {
    if (fail) throw StateError('offline');
    return result(works);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class ShelfAuth extends AuthProvider {
  int account = 7;
  @override
  int get userId => account;
  void change() {
    account++;
    notifyListeners();
  }
}

void main() {
  testWidgets('portrait photos fill the square paper window', (tester) async {
    const image = ValueKey('portrait-photo');
    await tester.pumpWidget(const MaterialApp(
        home: Center(
            child: SizedBox(
                width: 280,
                height: 400,
                child: PolaroidFrame(
                    photo: AspectRatio(
                        key: image,
                        aspectRatio: .8,
                        child: ColoredBox(color: Colors.blue)))))));
    final size = tester.getSize(find.byKey(image));
    expect(size.width, closeTo(size.height, .1));
  });
  Future<void> show(WidgetTester tester, ShelfApi api, ShelfAuth auth,
      {double scale = 1.0}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scale)),
                child: child!),
            home: MemoriesScreen(api: api))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('touching the exposed paper changes page and keeps flip state',
      (tester) async {
    final api = ShelfApi()
      ..photos = [
        for (var i = 1; i <= 3; i++)
          {
            'id': i,
            'url': '/uploads/paper_$i.jpg',
            'frame_note': '相纸 $i',
            'description': '背面故事 $i',
          },
      ];
    await show(tester, api, ShelfAuth(), scale: 1.6);
    final page = find.byType(PageView);
    final bounds = tester.getRect(page);
    await tester.tapAt(Offset(bounds.right - 10, bounds.top + 120));
    await tester.pumpAndSettle();
    expect(find.textContaining('2/3'), findsOneWidget);
    await tester.tapAt(tester.getCenter(page));
    await tester.pumpAndSettle();
    expect(find.textContaining('背面故事 2'), findsOneWidget);
    await tester.tapAt(Offset(bounds.left + 10, bounds.top + 120));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('the landscape ticket spans most of the shelf with its own ratio',
      (tester) async {
    final api = ShelfApi()
      ..works = [
        {
          'id': 9,
          'clientId': 'qa_ticket',
          'ownerId': 7,
          'revision': 1,
          'previewUrl': '/uploads/ticket.png',
          'sourceUrls': ['/uploads/coast.jpg'],
          'updatedAt': '2026-10-24',
          'document': {
            'kind': 'ticket',
            'templateId': 'landscape',
            'title': '海边散步',
            'date': '2026-10-24',
          },
        },
      ];
    await show(tester, api, ShelfAuth(), scale: 1.6);
    final ticket = find.byType(CreationFlip);
    await tester.ensureVisible(ticket);
    final size = tester.getSize(ticket);
    expect(size.width, greaterThanOrEqualTo(300));
    expect(size.width / size.height, closeTo(2.35, .005));
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
      'legacy saved ink and reverse story remain present on the real paper renderer',
      (tester) async {
    final api = ShelfApi()
      ..photos = [
        {
          'id': 1,
          'url': '/uploads/qa.jpg',
          'frame_note': '海边',
          'description': '背面的故事',
          'back_message': '给你的留言',
          'photo_date': '2026-10-24',
          'ink_strokes': jsonEncode([
            {
              'w': 2.2,
              'c': 0xff202126,
              'p': ['100,200', '400,500']
            }
          ])
        }
      ];
    await show(tester, api, ShelfAuth());
    final frame = find.byType(PolaroidFrame);
    final paper = find.descendant(
        of: frame,
        matching: find.byWidgetPredicate((w) =>
            w is SizedBox &&
            w.width != null &&
            w.height != null &&
            w.width! > 100 &&
            (w.height! / w.width! - 107 / 88).abs() < .005));
    expect(tester.getSize(paper).width, greaterThanOrEqualTo(260));
    expect(tester.widget<PolaroidFrame>(frame).inkStrokes.length, 1);
    await tester.tapAt(tester.getCenter(frame));
    await tester.pump();
    expect(find.textContaining('背面的故事'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets(
      'selecting a month filters actual records rather than inserting sample paper',
      (tester) async {
    final api = ShelfApi()
      ..photos = [
        {
          'id': 1,
          'url': '/uploads/one.jpg',
          'frame_note': '十月照片',
          'photo_date': '2026-10-24'
        },
        {
          'id': 2,
          'url': '/uploads/two.jpg',
          'frame_note': '去年的照片',
          'photo_date': '2025-11-10'
        },
      ];
    await show(tester, api, ShelfAuth());
    await tester.tap(find.text('全部月份 ▾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025年11月'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1/1'), findsOneWidget);
    expect(find.text('去年的照片'), findsOneWidget);
    expect(find.text('十月照片'), findsNothing);
    await finish(tester);
  });

  testWidgets(
      'a pending original-photo response cannot carry into another account',
      (tester) async {
    final api = ShelfApi()..first = Completer<Response<dynamic>>();
    final auth = ShelfAuth();
    await show(tester, api, auth);
    auth.change();
    await tester.pump();
    await tester.pump();
    api.first!.complete(result([
      {'id': 1, 'url': '/uploads/private.jpg', 'frame_note': '上一账号'}
    ]));
    await tester.pump();
    expect(find.text('上一账号'), findsNothing);
    expect(find.byType(PolaroidFrame), findsNothing);
    await finish(tester);
  });
}
