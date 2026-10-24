import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/travel.dart' show TravelSpot;
import '../../services/api_service.dart';

bool hasMapPosition(TravelSpot spot) =>
    spot.lat.isFinite &&
    spot.lng.isFinite &&
    spot.lat.abs() <= 90 &&
    spot.lng.abs() <= 180 &&
    (spot.lat != 0 || spot.lng != 0);

class TravelCamera {
  final double lat;
  final double lng;
  final double zoom;
  const TravelCamera(this.lat, this.lng, this.zoom);
}

class PlaceChoice {
  final String name;
  final String city;
  final String address;
  final double lat;
  final double lng;
  final TravelSpot? saved;
  const PlaceChoice(
      {required this.name,
      this.city = '',
      this.address = '',
      required this.lat,
      required this.lng,
      this.saved});

  factory PlaceChoice.fromSpot(TravelSpot spot) => PlaceChoice(
      name: spot.name,
      city: spot.city,
      address: spot.address,
      lat: spot.lat,
      lng: spot.lng,
      saved: spot);
}

/// One source for the map, place list and footprint overview.
class TravelWorkspace extends ChangeNotifier {
  final ApiService api;
  TravelWorkspace({ApiService? api}) : api = api ?? ApiService();

  List<TravelSpot> _places = const [];
  List<TravelSpot> get places => _places;
  bool loading = false;
  bool loaded = false;
  String? error;
  String status = '';
  int? selectedId;
  TravelCamera? camera;
  Future<void>? _request;
  int _generation = 0;
  bool _disposed = false;
  int? _accountId;
  bool _accountSet = false;

  void setAccount(int? id) {
    if (_accountSet && _accountId != id) clear();
    _accountSet = true;
    _accountId = id;
  }

  List<TravelSpot> get visiblePlaces => status.isEmpty
      ? _places
      : _places
          .where((place) => place.status == status)
          .toList(growable: false);
  TravelSpot? get selected {
    for (final place in _places) {
      if (place.id == selectedId) return place;
    }
    return null;
  }

  Future<void> load({bool refresh = false}) {
    if (_request != null) return _request!;
    if (loaded && !refresh) return Future.value();
    final request = _load();
    _request = request;
    return request.whenComplete(() {
      if (identical(_request, request)) _request = null;
    });
  }

  Future<void> _load() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await api.getTravelSpots();
      final data = response.data?['data'];
      final rows = data is List
          ? data
          : data is Map
              ? data['list']
              : null;
      if (rows is! List) throw const FormatException('Invalid places response');
      final next = rows
          .map((row) =>
              TravelSpot.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
      if (_disposed || generation != _generation) return;
      _places = List.unmodifiable(next);
      loaded = true;
      if (!_places.any((place) => place.id == selectedId)) selectedId = null;
    } catch (failure) {
      if (_disposed || generation != _generation) return;
      error = extractServerMessage(failure, fallback: '地点暂时加载失败，可以重试');
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setStatus(String value) {
    if (value == status) return;
    status = value;
    if (selected != null && value.isNotEmpty && selected!.status != value) {
      selectedId = null;
    }
    notifyListeners();
  }

  void select(TravelSpot? place) {
    if (place != null && !_places.any((value) => value.id == place.id)) {
      _places = List.unmodifiable([..._places, place]);
    }
    if (place != null && status.isNotEmpty && place.status != status) {
      status = '';
    }
    selectedId = place?.id;
    notifyListeners();
  }

  void upsert(TravelSpot place) {
    _generation++;
    _request = null;
    loading = false;
    _places = List.unmodifiable([
      ..._places.where((item) => item.id != place.id),
      place,
    ]);
    selectedId = place.id;
    notifyListeners();
  }

  Future<void> delete(TravelSpot place) async {
    final account = _accountId;
    await api.deleteTravelSpot(place.id);
    if (_disposed || account != _accountId) return;
    _generation++;
    _request = null;
    loading = false;
    _places = List.unmodifiable(_places.where((item) => item.id != place.id));
    if (selectedId == place.id) selectedId = null;
    notifyListeners();
  }

  /// Explicitly discard data when the account changes.
  void clear() {
    _generation++;
    _request = null;
    _places = const [];
    loaded = false;
    loading = false;
    error = null;
    status = '';
    selectedId = null;
    camera = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

class PlaceCluster {
  final String id;
  final List<TravelSpot> places;
  const PlaceCluster(this.id, this.places);
  double get lat =>
      places.fold<double>(0, (sum, value) => sum + value.lat) / places.length;
  double get lng =>
      places.fold<double>(0, (sum, value) => sum + value.lng) / places.length;
}

/// Group by approximately 64 screen pixels in Mercator space, not by frame.
List<PlaceCluster> clusterPlaces(Iterable<TravelSpot> places, double zoom) {
  final scale = math.pow(2, zoom.floor().clamp(1, 20)).toDouble() * 4;
  final buckets = <String, List<TravelSpot>>{};
  for (final place in places.where(hasMapPosition)) {
    final sinLat = math.sin(place.lat.clamp(-85.0, 85.0) * math.pi / 180);
    final x = (place.lng + 180) / 360 * scale;
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale;
    final key = '${x.floor()}:${y.floor()}';
    (buckets[key] ??= []).add(place);
  }
  return buckets.entries
      .map((entry) => PlaceCluster(entry.key, List.unmodifiable(entry.value)))
      .toList(growable: false);
}

/// PUT currently replaces nullable fields, so always preserve fields outside the compact editor.
Map<String, dynamic> placeWriteData({
  TravelSpot? original,
  required String name,
  required String city,
  required String address,
  required double lat,
  required double lng,
  required String status,
  required String diary,
  String? visitedDate,
  String? plannedDate,
  String? weather,
  String? mood,
}) =>
    {
      'name': name.trim(),
      'city': city.trim(),
      'address': address.trim(),
      'lat': lat,
      'lng': lng,
      'status': status,
      'diary': diary.trim(),
      'visitedDate': visitedDate,
      'plannedDate': plannedDate,
      'weather': weather,
      'mood': mood,
      'emoji': original?.emoji ?? '📍',
      'note': original?.note,
      'rating': original?.rating,
      'tags': original?.tags ?? [],
      'reason': original?.reason,
      'desire': original?.desire,
      'itinerary': original?.itinerary,
      'budget': original?.budget,
      'transportation': original?.transportation,
      'nearby': original?.nearby,
      'tips': original?.tips,
      'openingHours': original?.businessHours,
      'ownerNote': original?.noteMine,
      'partnerNote': original?.noteHer,
    };
