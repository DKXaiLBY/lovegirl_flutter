import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/travel.dart';
import '../../services/api_service.dart';
import 'journey.dart';
import 'travel_workspace.dart';

const journeyModes = {
  'walking': '步行',
  'bicycling': '骑行',
  'driving': '驾车',
  'transit': '公交'
};

class JourneyLeg {
  final String toKey;
  final String mode;
  final double distance;
  final double duration;
  final List<TravelCamera> points;
  final String? error;
  const JourneyLeg(
      this.toKey, this.mode, this.distance, this.duration, this.points,
      {this.error});
  String get estimate =>
      error ??
      '${distance >= 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.round()} m'} · ${(duration / 60).ceil()} 分钟';
  String get summary => error ?? '${journeyModes[mode]} · $estimate';
}

/// Owns an editable snapshot. Failed/conflicting writes never replace that snapshot.
class JourneyController extends ChangeNotifier {
  final ApiService api;
  final int ownerId;
  JourneyController(this.ownerId, {ApiService? api})
      : api = api ?? ApiService();
  List<Journey> library = [];
  List<Journey> localDrafts = [];
  Journey? current;
  int? day = 0;
  bool overview = false;
  String? selectedKey;
  int viewRevision = 0;
  bool dirty = false;
  bool busy = false;
  bool routing = false;
  bool conflict = false;
  String? error;
  List<JourneyLeg> legs = [];
  final Map<String, JourneyLeg> _cache = {};
  final Map<String, Future<JourneyLeg>> _pendingRoutes = {};
  int _generation = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  String get _prefix => 'lovegirl_journey_${ownerId}_';
  String _key(Journey j) => '$_prefix${j.id ?? j.clientId}';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    try {
      await _writes.catchError((Object _) {});
      final prefs = await SharedPreferences.getInstance();
      final drafts = <Journey>[];
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        try {
          drafts.add(Journey.fromJson(
              Map<String, dynamic>.from(jsonDecode(prefs.getString(key)!))));
        } catch (_) {
          error = '部分行程草稿读取失败，其他行程仍可使用';
        }
      }
      if (_disposed) return;
      localDrafts = drafts;
      final response = await api.getJourneys();
      if (_disposed) return;
      library = (response.data['data'] as List)
          .map((e) => Journey.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      error = extractServerMessage(e, fallback: '行程加载失败，可以重试');
    }
    _notify();
  }

  void select(Journey? journey, {bool draft = false}) {
    viewRevision++;
    _generation++;
    current = journey;
    day = 0;
    overview = false;
    selectedKey = null;
    dirty = draft;
    conflict = false;
    error = null;
    legs = [];
    _notify();
    unawaited(routes());
  }

  void create(
      {required String title,
      String city = '',
      required int days,
      String? startDate,
      String? endDate}) {
    select(Journey(
        clientId: '${ownerId}_${const Uuid().v4()}',
        title: title,
        city: city,
        days: days,
        startDate: startDate,
        endDate: endDate));
    update(current!);
  }

  Future<void> _persist(Journey value) {
    final operation = _writes.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        ...value.toJson(),
        'id': value.id,
        'ownerId': value.ownerId,
        'stops': value.stops
            .map((s) => {
                  ...s.toJson(),
                  if (s.place != null)
                    'place': {
                      'id': s.place!.id,
                      'name': s.place!.name,
                      'city': s.place!.city,
                      'address': s.place!.address,
                      'lat': s.place!.lat,
                      'lng': s.place!.lng,
                      'status': s.place!.status,
                      'photos': s.place!.photos.take(1).toList(),
                    }
                })
            .toList(),
      };
      if (!await prefs.setString(_key(value), jsonEncode(data))) {
        throw StateError('草稿未能保存');
      }
    });
    _writes = operation;
    return operation;
  }

  void update(Journey value) {
    if (busy) return;
    current = value;
    dirty = true;
    localDrafts.removeWhere((j) => _key(j) == _key(value));
    localDrafts.insert(0, value);
    unawaited(_persist(value).catchError((Object _) {
      error = '行程草稿未能写入，请勿离开，检查存储空间后再保存';
      _notify();
    }));
    _notify();
    unawaited(routes());
  }

  List<JourneyStop> get visible => current == null
      ? []
      : overview
          ? [
              for (var day = 0; day < current!.days; day++)
                ...current!.dayStops(day)
            ]
          : current!.dayStops(day);
  void setDay(int? value, {bool all = false}) {
    viewRevision++;
    day = value;
    overview = all;
    selectedKey = null;
    _notify();
    unawaited(routes());
  }

  void syncPlaces(List<TravelSpot> places) {
    final j = current;
    if (j == null) return;
    final byId = {for (final p in places) p.id: p};
    current = j.copyWith(
        stops: j.stops
            .map((s) => JourneyStop(
                key: s.key,
                spotId: s.spotId,
                day: s.day,
                mode: s.mode,
                note: s.note,
                place: byId[s.spotId]))
            .toList());
    _notify();
    unawaited(routes());
  }

  void add(TravelSpot place) {
    if (current == null) return;
    if (current!.stops.length >= 500) {
      error = '每份行程最多500个地点';
      _notify();
      return;
    }
    final stop = JourneyStop(
        key: const Uuid().v4(),
        spotId: place.id,
        place: place,
        day: overview ? null : day);
    update(current!.copyWith(stops: [...current!.stops, stop]));
    selectedKey = stop.key;
  }

  Future<bool> save() async {
    final snapshot = current;
    if (snapshot == null || busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await _writes;
      final response =
          await api.saveJourney(snapshot.toJson(), id: snapshot.id);
      final saved =
          Journey.fromJson(Map<String, dynamic>.from(response.data['data']));
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(snapshot));
      if (_disposed) return true;
      current = saved;
      dirty = false;
      conflict = false;
      localDrafts.removeWhere((j) => _key(j) == _key(snapshot));
      library.removeWhere((j) => j.id == saved.id);
      library.insert(0, saved);
      return true;
    } catch (e) {
      conflict = e is DioException && e.response?.statusCode == 409;
      error = conflict
          ? '行程已被另一人更新，当前输入已保留为私密草稿。请先查看最新版本，再决定如何整理。'
          : extractServerMessage(e, fallback: '保存失败，当前输入保留在草稿中');
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> reloadLatest() async {
    final old = current;
    if (old == null) return;
    // Keep the unsent snapshot even after viewing the latest shared version.
    if (dirty) await _persist(old);
    try {
      if (old.id == null) {
        await load();
        final matches = library.where((j) => j.clientId == old.clientId);
        if (matches.isEmpty) {
          error = '尚未找到已保存的行程，请稍后重试';
          _notify();
          return;
        }
        select(matches.first);
      } else {
        final r = await api.getJourney(old.id!);
        if (!_disposed) {
          select(Journey.fromJson(Map<String, dynamic>.from(r.data['data'])));
        }
      }
    } catch (e) {
      error = extractServerMessage(e, fallback: '最新行程读取失败，输入没有丢失');
      _notify();
    }
  }

  Future<void> discardDraft(Journey j) async {
    await _writes.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(j));
    localDrafts.removeWhere((v) => _key(j) == _key(v));
    _notify();
  }

  Future<bool> deleteCurrent() async {
    final j = current;
    if (j == null || busy) return false;
    busy = true;
    _notify();
    try {
      if (j.id != null) await api.deleteJourney(j.id!, j.revision);
      await discardDraft(j);
      library.removeWhere((v) => v.id == j.id);
      select(null);
      return true;
    } catch (e) {
      error = extractServerMessage(e, fallback: '删除失败，行程仍然保留');
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> routes({bool retry = false}) async {
    final generation = ++_generation;
    final j = current;
    final stops = visible.toList();
    legs = [];
    routing = j != null && stops.length > 1;
    _notify();
    if (!routing || j == null) return;
    for (var i = 1; i < stops.length; i++) {
      if (_disposed || generation != _generation) return;
      final from = stops[i - 1];
      final to = stops[i];
      if (from.day != to.day || from.day == null) continue;
      final a = from.place;
      final b = to.place;
      JourneyLeg leg;
      if (a == null || b == null || !hasMapPosition(a) || !hasMapPosition(b)) {
        leg = JourneyLeg(to.key, to.mode, 0, 0, const [],
            error: '地点已不可用，无法规划此段路线');
      } else {
        final key =
            '${a.lng},${a.lat}:${b.lng},${b.lat}:${to.mode}:${j.city}:${a.city}';
        final cached = _cache[key];
        if (cached != null && !retry) {
          leg = JourneyLeg(to.key, cached.mode, cached.distance,
              cached.duration, cached.points);
        } else {
          try {
            final route = await _route(
                key, a, b, to.mode, j.city.isNotEmpty ? j.city : a.city);
            leg = JourneyLeg(to.key, route.mode, route.distance, route.duration,
                route.points);
          } catch (e) {
            leg = JourneyLeg(to.key, to.mode, 0, 0, const [],
                error: extractServerMessage(e, fallback: '路线暂不可用，点击切换交通方式或重试'));
          }
        }
      }
      if (_disposed || generation != _generation) return;
      legs = [...legs, leg];
      _notify();
    }
    if (!_disposed && generation == _generation) {
      routing = false;
      _notify();
    }
  }

  JourneyStop? previousStop(JourneyStop stop) {
    if (stop.day == null || current == null) return null;
    final stops = current!.dayStops(stop.day);
    final index = stops.indexWhere((s) => s.key == stop.key);
    return index > 0 ? stops[index - 1] : null;
  }

  Future<JourneyLeg> alternative(JourneyStop stop, String mode) async {
    final j = current;
    final a = previousStop(stop)?.place;
    final b = stop.place;
    if (j == null ||
        a == null ||
        b == null ||
        !hasMapPosition(a) ||
        !hasMapPosition(b)) {
      return JourneyLeg(stop.key, mode, 0, 0, const [], error: '缺少可用的起点或终点');
    }
    final key = '${a.lng},${a.lat}:${b.lng},${b.lat}:$mode:${j.city}:${a.city}';
    try {
      final route = _cache[key] ??
          await _route(key, a, b, mode, j.city.isNotEmpty ? j.city : a.city);
      return JourneyLeg(
          stop.key, mode, route.distance, route.duration, route.points);
    } catch (e) {
      return JourneyLeg(stop.key, mode, 0, 0, const [],
          error: extractServerMessage(e, fallback: '此方式暂不可用'));
    }
  }

  Future<JourneyLeg> _route(
      String key, TravelSpot a, TravelSpot b, String mode, String city) {
    final pending = _pendingRoutes[key];
    if (pending != null) return pending;
    final request = _fetchRoute(key, a, b, mode, city);
    _pendingRoutes[key] = request;
    unawaited(request.then<void>((_) => _pendingRoutes.remove(key),
        onError: (Object _, StackTrace __) {
      _pendingRoutes.remove(key);
    }));
    return request;
  }

  Future<JourneyLeg> _fetchRoute(
      String key, TravelSpot a, TravelSpot b, String mode, String city) async {
    final response = await api.getAmapDirection(
        origin: '${a.lng},${a.lat}',
        destination: '${b.lng},${b.lat}',
        mode: mode,
        city: city);
    final data = response.data['data'] as Map;
    final points = (data['path'] as List)
        .map((p) => TravelCamera(
            (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble(), 0))
        .toList();
    if (points.isEmpty) throw StateError('路线为空');
    final leg = JourneyLeg('', mode, (data['distance'] as num).toDouble(),
        (data['duration'] as num).toDouble(), points);
    _cache[key] = leg;
    if (_cache.length > 80) _cache.remove(_cache.keys.first);
    return leg;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
