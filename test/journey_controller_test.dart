import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/models/travel.dart';
import 'package:lovegirl_flutter/features/travel/journey.dart';
import 'package:lovegirl_flutter/features/travel/journey_controller.dart';

Response r(dynamic data) =>
    Response(data: {'data': data}, requestOptions: RequestOptions());

class JourneyApi implements ApiService {
  bool conflict = false;
  List<Journey> library = [];
  final requests = <String, Completer<Response>>{};
  int routeReads = 0;
  @override
  Future getJourneys() async =>
      r(library.map((j) => {...j.toJson(), 'id': j.id}).toList());
  @override
  Future saveJourney(Map<String, dynamic> data, {int? id}) async {
    if (conflict) {
      throw DioException(
          requestOptions: RequestOptions(),
          response:
              Response(statusCode: 409, requestOptions: RequestOptions()));
    }
    return r(
        {...data, 'id': id ?? 9, 'revision': (data['revision'] as int) + 1});
  }

  @override
  Future getJourney(int id) async => r({...library.first.toJson(), 'id': id});
  @override
  Future getAmapDirection(
      {required String origin,
      required String destination,
      String mode = 'driving',
      String? city,
      String? waypoints}) {
    routeReads++;
    return (requests['$origin:$destination:$mode'] ??= Completer<Response>())
        .future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Journey plan() => Journey(id: 9, title: '两人的旅途', days: 2, revision: 1, stops: [
      JourneyStop(
          key: 'a',
          spotId: 1,
          day: 0,
          place: TravelSpot(id: 1, name: 'a', lat: 30, lng: 120)),
      JourneyStop(
          key: 'b',
          spotId: 2,
          day: 0,
          place: TravelSpot(id: 2, name: 'b', lat: 30.01, lng: 120.01)),
    ]);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('conflict retains editable input across restart and account partition',
      () async {
    final api = JourneyApi()..conflict = true;
    final c = JourneyController(1, api: api)
      ..select(const Journey(id: 9, title: '原版', revision: 1));
    c.update(c.current!.copyWith(title: '我的未提交输入'));
    expect(await c.save(), false);
    expect(c.conflict, true);
    expect(c.current!.title, '我的未提交输入');
    final reopened = JourneyController(1, api: api);
    await reopened.load();
    expect(reopened.localDrafts.single.title, '我的未提交输入');
    final other = JourneyController(2, api: api);
    await other.load();
    expect(other.localDrafts, isEmpty);
    c.dispose();
    reopened.dispose();
    other.dispose();
  });
  test(
      'successful acknowledgement removes only its draft and advances revision',
      () async {
    final api = JourneyApi();
    final c = JourneyController(1, api: api)
      ..select(const Journey(id: 9, title: '原版', revision: 1));
    c.update(c.current!.copyWith(title: '修改'));
    expect(await c.save(), true);
    expect(c.current!.revision, 2);
    expect(c.dirty, false);
    final reopened = JourneyController(1, api: api);
    await reopened.load();
    expect(reopened.localDrafts, isEmpty);
    c.dispose();
    reopened.dispose();
  });
  test(
      'viewing latest shared version preserves conflicting input as a separate draft',
      () async {
    final api = JourneyApi()
      ..library = [const Journey(id: 9, title: '另一人的新版', revision: 3)];
    final c = JourneyController(1, api: api)
      ..select(const Journey(id: 9, title: '旧版', revision: 1));
    c.update(c.current!.copyWith(title: '未提交'));
    await c.reloadLatest();
    expect(c.current!.title, '另一人的新版');
    final reopened = JourneyController(1, api: api);
    await reopened.load();
    expect(reopened.localDrafts.single.title, '未提交');
    c.dispose();
    reopened.dispose();
  });
  test(
      'inflight routes deduplicate and stale day responses cannot restore a line',
      () async {
    final api = JourneyApi();
    final c = JourneyController(1, api: api)..select(plan());
    final pending = c.routes();
    expect(api.routeReads, 1);
    c.setDay(1);
    api.requests.values.single.complete(r({
      'distance': 1200,
      'duration': 300,
      'path': [
        {'lat': 30, 'lng': 120},
        {'lat': 30.01, 'lng': 120.01}
      ]
    }));
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(c.legs, isEmpty);
    c.setDay(0);
    await c.routes();
    expect(c.legs.single.distance, 1200);
    expect(api.routeReads, 1);
    c.dispose();
  });
  test(
      'overview groups cross-day moves correctly; unavailable places invalidate routes',
      () async {
    final c = JourneyController(1, api: JourneyApi());
    c.select(plan().copyWith(stops: [
      plan().stops[0],
      plan().stops[1].copyWith(day: 1),
      JourneyStop(
          key: 'c',
          spotId: 3,
          day: 0,
          place: TravelSpot(id: 3, name: 'c', lat: 0, lng: 0))
    ]));
    c.setDay(null, all: true);
    expect(c.visible.map((s) => s.key), ['a', 'c', 'b']);
    c.syncPlaces([]);
    await c.routes();
    expect(c.legs.single.error, isNotNull);
    expect(c.legs.single.points, isEmpty);
    c.dispose();
  });
}
