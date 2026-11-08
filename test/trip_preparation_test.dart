import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/screens/travel/trip_preparation_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:provider/provider.dart';

class _Auth extends AuthProvider {
  int account = 7;
  @override
  int get userId => account;

  void switchAccount() {
    account++;
    notifyListeners();
  }
}

Map<String, dynamic> _item(String label, {int? assignee}) => {
      'key': 'packing-key-$label',
      'label': label,
      'category': 'other',
      'packed': false,
      'assigneeId': assignee,
    };

Map<String, dynamic> _list({
  int revision = 0,
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> outfits = const [],
}) =>
    {'revision': revision, 'items': items, 'outfits': outfits};

class _Api implements ApiService {
  Map<String, dynamic> mine = _list();
  Map<String, dynamic>? shared = _list();
  String? relationship = '9:1';
  String? cover;
  bool archived = false;
  void Function()? conflict;
  Completer<Response>? initial;
  Completer<Response>? pendingSave;
  final writes = <({String path, Map<String, dynamic> body})>[];

  Response<dynamic> response(Object? value) => Response(
      requestOptions: RequestOptions(), data: {'code': 200, 'data': value});

  Response<dynamic> get preparation => response({
        'trip': {
          'id': 24,
          'title': '海边三天',
          'startDate': '2026-12-01',
          'days': 3,
          if (cover != null) 'coverUrl': cover,
        },
        'archived': archived,
        'relationshipKey': relationship,
        'people': [
          {'id': 7, 'nickname': '自己'},
          {'id': 17, 'nickname': '搭档'}
        ],
        'mine': mine,
        'shared': shared,
      });

  @override
  Future<Response> get(String path, {Map<String, dynamic>? query}) async {
    expect(path, '/api/travel-preparation/24');
    final pending = initial;
    initial = null;
    return pending?.future ?? preparation;
  }

  @override
  Future<Response> put(String path, {dynamic data}) async {
    final body = data as Map<String, dynamic>;
    writes.add((path: path, body: body));
    final onConflict = conflict;
    if (onConflict != null) {
      conflict = null;
      onConflict();
      throw DioException(
          requestOptions: RequestOptions(),
          response: Response(
              requestOptions: RequestOptions(),
              statusCode: 409,
              data: {'message': '请读取最新版本'}));
    }
    if (pendingSave != null) return pendingSave!.future;
    final outfits = (body['outfits'] as List).cast<Map<String, dynamic>>();
    final result = _list(
      revision: (body['revision'] as int) + 1,
      items: (body['items'] as List).cast<Map<String, dynamic>>(),
      outfits: [
        for (final outfit in outfits)
          {
            ...outfit,
            'label': '自选衣物',
            'available': true,
            'items': [
              {'label': '蓝 外套', 'imageUrl': null, 'available': true}
            ],
          },
      ],
    );
    if (path.endsWith('/shared')) {
      shared = result;
    } else {
      mine = result;
    }
    return response(result);
  }

  @override
  Future<Response> getWardrobeItems() async => response([
        {'id': 55, 'category': '外套', 'color': '蓝', 'status': '在柜'},
        {'id': 59, 'category': '退役外套', 'status': '退役'},
      ]);

  @override
  Future<Response> getWardrobeOutfits() async => response([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (_) async => null);
  });

  Future<void> show(WidgetTester tester, _Api api, _Auth auth,
      {double scale = 1.15, bool dark = false}) async {
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
        home: TripPreparationScreen(tripId: 24, api: api),
      ),
    ));
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('scope, assignment and progress change only after saved response',
      (tester) async {
    final api = _Api()
      ..mine = _list(items: [_item('自己的衣物')])
      ..shared = _list(items: [_item('相机', assignee: 17)]);
    await show(tester, api, _Auth());
    await tap(tester, '共同物品');
    expect(find.text('自己的衣物'), findsNothing);
    expect(find.text('搭档 携带'), findsOneWidget);
    api.pendingSave = Completer<Response>();
    await tester.tap(find.text('相机'));
    await tester.pump();
    final write = api.writes.single;
    expect(write.path, '/api/travel-preparation/24/shared');
    expect(write.body['relationshipKey'], '9:1');
    expect((write.body['items'] as List).single['assigneeId'], 17);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        false);
    api.pendingSave!.complete(api.response({
      ...write.body,
      'revision': 1,
    }));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        true);
    expect(find.text('已装好 1 / 2'), findsOneWidget);
    await tap(tester, '个人行李');
    expect(find.text('相机'), findsNothing);
    expect(find.text('自己的衣物'), findsOneWidget);
  });

  testWidgets(
      'a conflicting save preserves the draft and uses the new revision',
      (tester) async {
    final api = _Api()..conflict = () {};
    api.conflict =
        () => api.mine = _list(revision: 8, items: [_item('刚同步的物品')]);
    await show(tester, api, _Auth());
    await tap(tester, '添加物品');
    await tester.enterText(find.byType(TextFormField), '留在表单的输入');
    await tap(tester, '保存');
    expect(find.text('留在表单的输入'), findsOneWidget);
    expect(find.text('清单已刷新，请核对后再保存'), findsOneWidget);
    await tap(tester, '保存');
    expect(api.writes[0].body['revision'], 0);
    expect(api.writes[1].body['revision'], 8);
    expect((api.writes[1].body['items'] as List).map((item) => item['label']),
        ['刚同步的物品', '留在表单的输入']);
    expect((api.writes[0].body['items'] as List).single['key'],
        (api.writes[1].body['items'] as List).last['key']);
  });

  testWidgets('rebind conflict cannot put an old shared draft in a new scope',
      (tester) async {
    final api = _Api();
    api.conflict = () => api.relationship = '9:2';
    await show(tester, api, _Auth());
    await tap(tester, '共同物品');
    await tap(tester, '添加物品');
    await tester.enterText(find.byType(TextFormField), '上一轮物品');
    await tap(tester, '保存');
    expect(find.text('上一轮物品'), findsOneWidget);
    expect(find.text('绑定关系已变化，请关闭后重新打开共同清单'), findsOneWidget);
    await tap(tester, '保存');
    expect(api.writes.length, 1);
  });

  testWidgets('picker writes wardrobe references for the selected day only',
      (tester) async {
    final api = _Api();
    await show(tester, api, _Auth());
    await tap(tester, '第 2 天');
    await tap(tester, '从衣橱选择');
    expect(find.text('退役外套'), findsNothing);
    await tap(tester, '蓝 外套');
    await tap(tester, '保存搭配');
    final write = api.writes.single;
    expect(write.path, '/api/travel-preparation/24/private');
    expect((write.body['outfits'] as List).single, {
      'day': 1,
      'outfitId': null,
      'itemIds': [55]
    });
    expect(find.text('自选衣物'), findsOneWidget);
  });

  testWidgets('a newly uploaded journey photo leads the cover', (tester) async {
    const cover = 'https://example.invalid/qa-new-journey-photo.png';
    final api = _Api()..cover = cover;
    await show(tester, api, _Auth());
    expect(
        tester
            .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .imageUrl,
        cover);
    expect(find.text('12月1日 – 12月3日 · 3 天'), findsOneWidget);
    expect(find.text('已装好 0 / 0'), findsOneWidget);
  });

  testWidgets('archived content remains readable at 1.6x in dark mode',
      (tester) async {
    final api = _Api()
      ..archived = true
      ..mine = _list(items: [_item('以前的长物品名称仍然可以阅读')]);
    await show(tester, api, _Auth(), scale: 1.6, dark: true);
    expect(find.textContaining('已归档 · 只读'), findsOneWidget);
    expect(find.text('从衣橱选择'), findsNothing);
    expect(find.text('添加物品'), findsNothing);
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, -600));
    await tester.pumpAndSettle();
    final checkbox =
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a delayed previous account response cannot replace the new one',
      (tester) async {
    final previous = Completer<Response>();
    final api = _Api()
      ..mine = _list(items: [_item('旧账号资料')])
      ..initial = previous;
    final privateResponse = api.preparation;
    final auth = _Auth();
    await show(tester, api, auth);
    api.mine = _list(items: [_item('新账号资料')]);
    auth.switchAccount();
    await tester.pumpAndSettle();
    previous.complete(privateResponse);
    await tester.pumpAndSettle();
    expect(find.text('旧账号资料'), findsNothing);
    expect(find.text('新账号资料'), findsOneWidget);
  });
}
