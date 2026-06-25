import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class TravelSpot {
  final int id;
  final String name;
  String city;
  String address;
  double lng;
  double lat;
  String emoji;
  String status; // visited / wish / planned
  String? note;
  String? diary;
  String? visitedDate;
  List<String> photos;
  int? rating;
  String? mood;
  List<String> tags;
  String? reason;
  int? desire;
  String? plannedDate;
  String? itinerary;
  double? budget;

  TravelSpot({
    required this.id,
    required this.name,
    this.city = '',
    this.address = '',
    this.lng = 0,
    this.lat = 0,
    this.emoji = '📍',
    this.status = 'wish',
    this.note,
    this.diary,
    this.visitedDate,
    List<String>? photos,
    this.rating,
    this.mood,
    List<String>? tags,
    this.reason,
    this.desire,
    this.plannedDate,
    this.itinerary,
    this.budget,
  }) : photos = photos ?? [],
       tags = tags ?? [];

  factory TravelSpot.fromJson(Map<String, dynamic> json) {
    return TravelSpot(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
      lng: (json['lng'] ?? 0).toDouble(),
      lat: (json['lat'] ?? 0).toDouble(),
      emoji: json['emoji'] ?? '📍',
      status: json['status'] ?? 'wish',
      note: json['note'],
      diary: json['diary'],
      // 兼容驼峰和下划线命名
      visitedDate: json['visitedDate'] ?? json['visited_date'],
      photos: json['photos'] != null ? (json['photos'] is List ? List<String>.from(json['photos']) : []) : [],
      rating: json['rating'],
      mood: json['mood'],
      tags: json['tags'] != null ? (json['tags'] is List ? List<String>.from(json['tags']) : []) : [],
      reason: json['reason'],
      desire: json['desire'],
      // 兼容驼峰和下划线命名
      plannedDate: json['plannedDate'] ?? json['planned_date'],
      itinerary: json['itinerary'],
      budget: json['budget']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name, 'city': city, 'address': address,
    'lng': lng, 'lat': lat, 'emoji': emoji, 'status': status,
    'note': note, 'diary': diary, 'visited_date': visitedDate,
    'photos': photos, 'rating': rating, 'mood': mood, 'tags': tags,
    'reason': reason, 'desire': desire, 'planned_date': plannedDate,
    'itinerary': itinerary, 'budget': budget,
  };
}

class TravelStats {
  final int visited;
  final int wish;
  final int planned;
  final int cities;
  final int distance;
  final List<Map<String, dynamic>> badges;

  TravelStats({
    this.visited = 0, this.wish = 0, this.planned = 0,
    this.cities = 0, this.distance = 0, this.badges = const [],
  });

  factory TravelStats.fromJson(Map<String, dynamic> json) {
    return TravelStats(
      visited: json['visited'] ?? 0,
      wish: json['wish'] ?? 0,
      planned: json['planned'] ?? 0,
      cities: json['cities'] ?? 0,
      distance: json['distance'] ?? 0,
      badges: (json['badges'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [],
    );
  }
}

class TravelProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<TravelSpot> _spots = [];
  TravelStats? _stats;
  bool _loading = false;
  String _activeStatus = '';
  String _activeCity = '';
  List<String> _cityOptions = [];
  int? _highlightedId;

  List<TravelSpot> get spots => _spots;
  TravelStats? get stats => _stats;
  bool get loading => _loading;
  String get activeStatus => _activeStatus;
  String get activeCity => _activeCity;
  List<String> get cityOptions => _cityOptions;
  int? get highlightedId => _highlightedId;

  List<TravelSpot> get filteredSpots {
    var result = _spots;
    if (_activeStatus.isNotEmpty) {
      result = result.where((s) => s.status == _activeStatus).toList();
    }
    if (_activeCity.isNotEmpty) {
      result = result.where((s) => s.city == _activeCity).toList();
    }
    return result;
  }

  Future<void> refreshAll() async {
    await Future.wait([fetchSpots(), fetchStats()]);
  }

  Future<void> fetchSpots() async {
    _loading = true;
    notifyListeners();
    try {
      final statusParam = _activeStatus.isNotEmpty ? _activeStatus : null;
      final cityParam = _activeCity.isNotEmpty ? _activeCity : null;

      final res = await _api.getTravelSpots(status: statusParam, city: cityParam);
      final data = res.data?['data'];

      if (data != null && data is Map) {
        final list = data['list'];
        _spots = (list is List)
            ? list.map((e) => TravelSpot.fromJson(Map<String, dynamic>.from(e))).toList()
            : [];
        final cities = data['cities'];
        _cityOptions = (cities is List) ? cities.cast<String>() : [];
      } else {
        _spots = [];
        _cityOptions = [];
      }
    } catch (e) {
      _spots = [];
      _cityOptions = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchStats() async {
    try {
      final res = await _api.getTravelStats();
      final data = res.data?['data'];
      if (data != null && data is Map) {
        _stats = TravelStats.fromJson(Map<String, dynamic>.from(data));
      }
      notifyListeners();
    } catch (_) {}
  }

  void setStatus(String status) {
    print('[TravelProvider] setStatus: $status');
    _activeStatus = status;
    notifyListeners(); // 立即通知 UI 更新
    fetchSpots();
  }

  void setCity(String city) {
    _activeCity = city;
    fetchSpots();
  }

  void highlightSpot(int? id) {
    _highlightedId = id;
    notifyListeners();
  }

  Future<void> createSpot(Map data) async {
    await _api.createTravelSpot(data);
    await refreshAll();
  }

  Future<void> updateSpot(int id, Map data) async {
    await _api.updateTravelSpot(id, data);
    await refreshAll();
  }

  Future<void> deleteSpot(int id) async {
    await _api.deleteTravelSpot(id);
    await refreshAll();
  }
}
