import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class TravelSpot {
  final int id;
  final String name;
  final String city;
  final String address;
  final double lng;
  final double lat;
  final String emoji;
  final String status;
  final String? note;
  final String? diary;
  final String? visitedDate;
  final List<String> photos;
  final int? rating;
  final String? mood;
  final List<String> tags;
  final String? reason;
  final int? desire;
  final String? plannedDate;
  final String? itinerary;
  final double? budget;

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
  })  : photos = photos ?? [],
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
      visitedDate: json['visitedDate'] ?? json['visited_date'],
      photos: json['photos'] != null
          ? (json['photos'] is List ? List<String>.from(json['photos']) : [])
          : [],
      rating: json['rating'],
      mood: json['mood'],
      tags: json['tags'] != null
          ? (json['tags'] is List ? List<String>.from(json['tags']) : [])
          : [],
      reason: json['reason'],
      desire: json['desire'],
      plannedDate: json['plannedDate'] ?? json['planned_date'],
      itinerary: json['itinerary'],
      budget: json['budget']?.toDouble(),
    );
  }
}

class TravelStats {
  final int visited;
  final int wish;
  final int planned;
  final int cities;

  TravelStats({
    this.visited = 0,
    this.wish = 0,
    this.planned = 0,
    this.cities = 0,
  });

  factory TravelStats.fromJson(Map<String, dynamic> json) {
    return TravelStats(
      visited: json['visited'] ?? 0,
      wish: json['wish'] ?? 0,
      planned: json['planned'] ?? 0,
      cities: json['cities'] ?? 0,
    );
  }
}

class TravelProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<TravelSpot> _spots = [];
  TravelStats? _stats;
  bool _loading = false;
  String _activeStatus = '';
  int? _highlightedId;

  List<TravelSpot> get spots => _spots;
  TravelStats? get stats => _stats;
  bool get loading => _loading;
  String get activeStatus => _activeStatus;
  int? get highlightedId => _highlightedId;

  // 筛选后的地点列表
  List<TravelSpot> get filteredSpots {
    if (_activeStatus.isEmpty) return _spots;
    return _spots.where((s) => s.status == _activeStatus).toList();
  }

  // 基于实际spots计算的统计数据（保证一致性）
  TravelStats get computedStats {
    final visited = _spots.where((s) => s.status == 'visited').length;
    final wish = _spots.where((s) => s.status == 'wish').length;
    final planned = _spots.where((s) => s.status == 'planned').length;
    final cities = _spots.where((s) => s.city.isNotEmpty).map((s) => s.city).toSet().length;
    return TravelStats(visited: visited, wish: wish, planned: planned, cities: cities);
  }

  // 刷新所有数据
  Future<void> refreshAll() async {
    await Future.wait([fetchSpots(), fetchStats()]);
  }

  // 获取地点列表
  Future<void> fetchSpots() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.getTravelSpots();
      final data = res.data?['data'];
      if (data != null && data is Map) {
        final list = data['list'];
        _spots = (list is List)
            ? list.map((e) => TravelSpot.fromJson(Map<String, dynamic>.from(e))).toList()
            : [];
      } else {
        _spots = [];
      }
    } catch (e) {
      _spots = [];
    }
    _loading = false;
    notifyListeners();
  }

  // 获取统计数据
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

  // 设置筛选状态
  void setStatus(String status) {
    _activeStatus = status;
    notifyListeners();
  }

  // 高亮地点
  void highlightSpot(int? id) {
    _highlightedId = id;
    notifyListeners();
  }

  // 创建地点
  Future<void> createSpot(Map data) async {
    await _api.createTravelSpot(data);
    await refreshAll();
  }

  // 更新地点
  Future<void> updateSpot(int id, Map data) async {
    await _api.updateTravelSpot(id, data);
    await refreshAll();
  }

  // 删除地点
  Future<void> deleteSpot(int id) async {
    await _api.deleteTravelSpot(id);
    await refreshAll();
  }
}
