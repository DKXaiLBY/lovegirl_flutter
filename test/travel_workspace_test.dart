import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lovegirl_flutter/models/travel.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/features/travel/travel_workspace.dart';
import 'package:lovegirl_flutter/features/travel/travel_screen.dart';
import 'package:lovegirl_flutter/features/travel/travel_map_canvas.dart';
import 'package:lovegirl_flutter/features/travel/place_editor.dart';
import 'package:lovegirl_flutter/features/travel/place_search.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

Response<dynamic> response(dynamic data) => Response(
    data: {'code': 200, 'data': data}, requestOptions: RequestOptions());

Map<String, dynamic> place(int id,
        {String status = 'visited', double lat = 30, double lng = 120}) =>
    {
      'id': id,
      'name': '地点 $id',
      'city': '杭州',
      'lat': lat,
      'lng': lng,
      'status': status
    };

class PlacesApi implements ApiService {
  List<Map<String, dynamic>> rows = [place(1)];
  bool fail = false;
  bool failSave = false;
  bool failDelete = false;
  int reads = 0;
  int writes = 0;
  int deletes = 0;
  Map? saved;
  Completer<Response<dynamic>>? readGate;
  Completer<Response<dynamic>>? writeGate;
  final Map<String, Completer<Response<dynamic>>> searches = {};

  @override
  Future<Response<dynamic>> getTravelSpots(
      {String? status, String? city}) async {
    reads++;
    if (readGate != null) return readGate!.future;
    if (fail) throw StateError('offline');
    return response({'list': rows});
  }

  @override
  Future<Response<dynamic>> updateTravelSpot(int id, Map data) async {
    writes++;
    saved = data;
    if (writeGate != null) return writeGate!.future;
    if (failSave) throw StateError('offline');
    return response({});
  }

  @override
  Future<Response<dynamic>> createTravelSpot(Map data) async {
    writes++;
    saved = data;
    if (writeGate != null) return writeGate!.future;
    if (failSave) throw StateError('offline');
    return response({'id': 7});
  }

  @override
  Future<Response<dynamic>> deleteTravelSpot(int id) async {
    deletes++;
    if (failDelete) throw StateError('offline');
    return response({});
  }

  @override
  Future<Response<dynamic>> searchAmapPoi(String query, {String? city}) =>
      (searches[query] ??= Completer<Response<dynamic>>()).future;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('concurrent loads share one request and loaded data is reused',
      () async {
    final api = PlacesApi()..readGate = Completer();
    final workspace = TravelWorkspace(api: api);
    final one = workspace.load();
    final two = workspace.load();
    expect(api.reads, 1);
    api.readGate!.complete(response({
      'list': [place(1)]
    }));
    await Future.wait([one, two]);
    await workspace.load();
    expect(api.reads, 1);
    expect(workspace.places.single.id, 1);
    expect(workspace.loading, false);
    workspace.dispose();
  });

  test('refresh failure preserves data, selection and camera; retry recovers',
      () async {
    final api = PlacesApi();
    final workspace = TravelWorkspace(api: api);
    await workspace.load();
    workspace.select(workspace.places.single);
    workspace.camera = const TravelCamera(30, 120, 14);
    api.fail = true;
    await workspace.load(refresh: true);
    expect(workspace.places.single.id, 1);
    expect(workspace.selectedId, 1);
    expect(workspace.camera!.zoom, 14);
    expect(workspace.error, isNotNull);
    expect(workspace.loading, false);
    api.fail = false;
    await workspace.load(refresh: true);
    expect(workspace.error, isNull);
    workspace.dispose();
  });

  test('a delayed response from a previous account never restores its records',
      () async {
    final api = PlacesApi()..readGate = Completer();
    final workspace = TravelWorkspace(api: api)..setAccount(1);
    final request = workspace.load();
    workspace.setAccount(2);
    api.readGate!.complete(response({
      'list': [place(1)]
    }));
    await request;
    expect(workspace.places, isEmpty);
    expect(workspace.loaded, false);
    expect(workspace.camera, isNull);
    workspace.dispose();
  });

  test('status filters share one data set; external selection becomes visible',
      () async {
    final api = PlacesApi()..rows = [place(1), place(2, status: 'wish')];
    final workspace = TravelWorkspace(api: api);
    await workspace.load();
    workspace.setStatus('wish');
    expect(workspace.visiblePlaces.map((p) => p.id), [2]);
    workspace.select(workspace.places.first);
    expect(workspace.status, '');
    expect(workspace.selectedId, 1);
    expect(api.reads, 1);
    workspace.dispose();
  });

  test('failed deletion does not remove a row; confirmed success does',
      () async {
    final api = PlacesApi()..failDelete = true;
    final workspace = TravelWorkspace(api: api);
    await workspace.load();
    final original = workspace.places.single;
    await expectLater(workspace.delete(original), throwsStateError);
    expect(workspace.places, isNotEmpty);
    api.failDelete = false;
    await workspace.delete(original);
    expect(workspace.places, isEmpty);
    workspace.dispose();
  });

  test('a refresh started before a write cannot overwrite the saved record',
      () async {
    final api = PlacesApi();
    final workspace = TravelWorkspace(api: api);
    await workspace.load();
    api.readGate = Completer();
    final refresh = workspace.load(refresh: true);
    workspace.upsert(TravelSpot(id: 1, name: '刚保存的名称'));
    api.readGate!.complete(response({
      'list': [place(1)]
    }));
    await refresh;
    expect(workspace.places.single.name, '刚保存的名称');
    expect(workspace.loading, false);
    workspace.dispose();
  });

  test('500 dense places cluster without losing IDs and split on close zoom',
      () {
    final places = List.generate(
        500,
        (i) => TravelSpot(
            id: i,
            name: '点 $i',
            lat: 23.10 + (i % 25) * .001,
            lng: 113.20 + (i ~/ 25) * .001));
    final wide = clusterPlaces(places, 6);
    final close = clusterPlaces(places, 18);
    expect(wide.length, lessThan(10));
    expect(close.length, greaterThan(wide.length));
    expect(
        wide.expand((c) => c.places).map((p) => p.id).toSet(), hasLength(500));
    expect(
        clusterPlaces([...places, TravelSpot(id: 999, name: '无坐标')], 6)
            .expand((c) => c.places),
        hasLength(500));
  });

  testWidgets('search debounce and stale success do not replace a newer result',
      (tester) async {
    final api = PlacesApi();
    final search = PlaceSearchController(api: api);
    search.search('旧');
    await tester.pump(const Duration(milliseconds: 400));
    search.search('新');
    await tester.pump(const Duration(milliseconds: 400));
    api.searches['新']!.complete(response({
      'list': [place(2)]
    }));
    await tester.pump();
    api.searches['旧']!.complete(response({
      'list': [place(1)]
    }));
    await tester.pump();
    expect(search.results.single.name, '地点 2');
    expect(search.loading, false);
    search.dispose();
  });

  testWidgets(
      'stale search errors and clearing a query cannot resurrect old results',
      (tester) async {
    final api = PlacesApi();
    final search = PlaceSearchController(api: api);
    search.search('旧');
    await tester.pump(const Duration(milliseconds: 400));
    search.search('');
    api.searches['旧']!.completeError(StateError('offline'));
    await tester.pump();
    expect(search.error, isNull);
    expect(search.results, isEmpty);
    expect(search.loading, false);
    search.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets(
        'empty account keeps map surface and operations; sheet does not recreate canvas: dark=$dark',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final api = PlacesApi()..rows = [];
      final workspace = TravelWorkspace(api: api);
      await workspace.load();
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: workspace,
          child: MaterialApp(
              theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
              home: const TravelScreen())));
      await tester.pumpAndSettle();
      final before = tester.state(find.byType(TravelMapCanvas));
      expect(find.text('记地点'), findsOneWidget);
      expect(find.byTooltip('足迹总览'), findsOneWidget);
      expect(find.text('先放一个想去的地方进来'), findsNothing);
      await tester.tap(find.text('想去'));
      await tester.pumpAndSettle();
      expect(
          identical(before, tester.state(find.byType(TravelMapCanvas))), true);
      await tester.drag(find.text('我的地点'), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(
          identical(before, tester.state(find.byType(TravelMapCanvas))), true);
      expect(api.reads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      workspace.dispose();
    });
  }

  final original = TravelSpot(
      id: 7,
      name: '原地点',
      city: '杭州',
      lat: 30,
      lng: 120,
      status: 'visited',
      visitedDate: '2026-01-01',
      plannedDate: '2026-02-02',
      weather: '晴天',
      mood: '开心',
      note: '保留备注',
      tags: ['散步'],
      budget: 100,
      noteMine: '我的备注',
      noteHer: '伴侣备注',
      businessHours: '全天');

  for (final dark in [false, true]) {
    testWidgets('editor actions keep readable contrast: dark=$dark',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: dark ? LoveGirlTheme.darkTheme : LoveGirlTheme.lightTheme,
          home: TravelPlaceEditor(spot: original, api: PlacesApi())));
      final style =
          tester.widget<FilledButton>(find.byType(FilledButton)).style!;
      final foreground = style.foregroundColor!.resolve({})!.computeLuminance();
      final background = style.backgroundColor!.resolve({})!.computeLuminance();
      final contrast = (foreground > background)
          ? (foreground + .05) / (background + .05)
          : (background + .05) / (foreground + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      final position = tester.widget<OutlinedButton>(
          find.byWidgetPredicate((widget) => widget is OutlinedButton));
      expect(position.style!.foregroundColor!.resolve({}),
          dark ? LoveGirlTheme.textPrimaryDark : LoveGirlTheme.primary);
    });
  }

  testWidgets(
      'failed save keeps input and original fields instead of reporting success',
      (tester) async {
    final api = PlacesApi()..failSave = true;
    await tester.pumpWidget(
        MaterialApp(home: TravelPlaceEditor(spot: original, api: api)));
    await tester.enterText(find.byType(TextFormField).first, '修改的名称');
    await tester.tap(find.text('保存地点'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，输入已经保留，请重试'), findsOneWidget);
    expect(find.text('修改的名称'), findsOneWidget);
    expect(api.saved!['ownerNote'], '我的备注');
    expect(api.saved!['partnerNote'], '伴侣备注');
    expect(api.saved!['weather'], '晴天');
    expect(api.saved!['mood'], '开心');
    expect(api.saved!['tags'], ['散步']);
    expect(api.saved!['budget'], 100);
  });

  testWidgets(
      'save is locked during an active request and is available again after failure',
      (tester) async {
    final api = PlacesApi()..writeGate = Completer();
    await tester.pumpWidget(
        MaterialApp(home: TravelPlaceEditor(spot: original, api: api)));
    await tester.tap(find.text('保存地点'));
    await tester.pump();
    await tester.tap(find.text('正在保存…'));
    await tester.pump();
    expect(api.writes, 1);
    api.writeGate!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('保存地点'), findsOneWidget);
    expect(find.textContaining('保存失败'), findsOneWidget);
  });

  testWidgets('switching status retains separate visited and planned dates',
      (tester) async {
    final api = PlacesApi()..failSave = true;
    await tester.pumpWidget(
        MaterialApp(home: TravelPlaceEditor(spot: original, api: api)));
    await tester.tap(find.text('计划中'));
    await tester.pumpAndSettle();
    expect(find.text('2026-02-02'), findsOneWidget);
    await tester.tap(find.text('已去'));
    await tester.pumpAndSettle();
    expect(find.text('2026-01-01'), findsOneWidget);
    await tester.tap(find.text('保存地点'));
    await tester.pumpAndSettle();
    expect(api.saved!['visitedDate'], '2026-01-01');
    expect(api.saved!['plannedDate'], '2026-02-02');
  });

  testWidgets('editing a date then switching status preserves the edited date',
      (tester) async {
    final api = PlacesApi()..failSave = true;
    await tester.pumpWidget(
        MaterialApp(home: TravelPlaceEditor(spot: original, api: api)));
    await tester.tap(find.text('2026-01-01'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('计划中'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存地点'));
    await tester.pumpAndSettle();
    expect(api.saved!['visitedDate'], '2026-01-02');
    expect(api.saved!['plannedDate'], '2026-02-02');
  });

  testWidgets('successful save returns the saved record to the caller',
      (tester) async {
    final api = PlacesApi();
    TravelSpot? returned;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
          onPressed: () async {
            returned = await Navigator.of(context).push<TravelSpot>(
                MaterialPageRoute(
                    builder: (_) =>
                        TravelPlaceEditor(spot: original, api: api)));
          },
          child: const Text('打开编辑'));
    })));
    await tester.tap(find.text('打开编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '保存后的名称');
    await tester.tap(find.text('保存地点'));
    await tester.pumpAndSettle();
    expect(find.byType(TravelPlaceEditor), findsNothing);
    expect(returned?.name, '保存后的名称');
    expect(returned?.noteMine, '我的备注');
    expect(returned?.plannedDate, '2026-02-02');
  });

  testWidgets('blank new records cannot be submitted', (tester) async {
    final api = PlacesApi();
    await tester.pumpWidget(MaterialApp(home: TravelPlaceEditor(api: api)));
    await tester.tap(find.text('保存地点'));
    await tester.pump();
    expect(find.text('请输入地点名称'), findsOneWidget);
    expect(find.text('请填写城市'), findsOneWidget);
    expect(api.writes, 0);
  });

  testWidgets('a new saved wish does not invent a visited or planned date',
      (tester) async {
    final api = PlacesApi()..failSave = true;
    await tester.pumpWidget(MaterialApp(
        home: TravelPlaceEditor(
            api: api,
            choice: const PlaceChoice(
                name: '新地点', city: '杭州', lat: 30, lng: 120))));
    await tester.tap(find.text('保存地点'));
    await tester.pumpAndSettle();
    expect(api.saved!['status'], 'wish');
    expect(api.saved!['visitedDate'], isNull);
    expect(api.saved!['plannedDate'], isNull);
  });
}
