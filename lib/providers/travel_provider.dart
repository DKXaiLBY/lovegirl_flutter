import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }
  return const [];
}

bool _hasValidCoordinate(TravelSpot spot) {
  return spot.lat.isFinite &&
      spot.lng.isFinite &&
      spot.lat >= -90 &&
      spot.lat <= 90 &&
      spot.lng >= -180 &&
      spot.lng <= 180 &&
      !(spot.lat == 0 && spot.lng == 0);
}

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
  final String? noteMine;
  final String? noteHer;
  final String? diary;
  final String? visitedDate;
  final List<String> photos;
  final String? coverImage;
  final int? rating;
  final String? mood;
  final String? weather;
  final List<String> tags;
  final String? reason;
  final int? desire;
  final String? plannedDate;
  final String? itinerary;
  final double? budget;
  final int? createdBy;
  final String? creatorNickname;
  final String? creatorAvatar;
  final bool editedByBoth;
  final String? transportation;
  final String? nearby;
  final String? tips;
  final String? businessHours;
  final String? checkedInAt;
  final int? routeId;
  final int? routeDay;
  final int? routeOrder;

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
    this.noteMine,
    this.noteHer,
    this.diary,
    this.visitedDate,
    List<String>? photos,
    this.coverImage,
    this.rating,
    this.mood,
    this.weather,
    List<String>? tags,
    this.reason,
    this.desire,
    this.plannedDate,
    this.itinerary,
    this.budget,
    this.createdBy,
    this.creatorNickname,
    this.creatorAvatar,
    this.editedByBoth = false,
    this.transportation,
    this.nearby,
    this.tips,
    this.businessHours,
    this.checkedInAt,
    this.routeId,
    this.routeDay,
    this.routeOrder,
  })  : photos = photos ?? const [],
        tags = tags ?? const [];

  factory TravelSpot.fromJson(Map<String, dynamic> json) {
    return TravelSpot(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      city: _asString(json['city']),
      address: _asString(json['address']),
      lng: _asDouble(json['lng']),
      lat: _asDouble(json['lat']),
      emoji: _asString(json['emoji'], fallback: '📍'),
      status: _asString(json['status'], fallback: 'wish'),
      note: json['note']?.toString(),
      noteMine: (json['noteMine'] ?? json['note_mine'])?.toString(),
      noteHer: (json['noteHer'] ?? json['note_her'])?.toString(),
      diary: json['diary']?.toString(),
      visitedDate: (json['visitedDate'] ?? json['visited_date'])?.toString(),
      photos: _asStringList(json['photos']),
      coverImage: (json['coverImage'] ?? json['cover_image'])?.toString(),
      rating: _asNullableInt(json['rating']),
      mood: json['mood']?.toString(),
      weather: json['weather']?.toString(),
      tags: _asStringList(json['tags']),
      reason: json['reason']?.toString(),
      desire: _asNullableInt(json['desire']),
      plannedDate: (json['plannedDate'] ?? json['planned_date'])?.toString(),
      itinerary: json['itinerary']?.toString(),
      budget: _asNullableDouble(json['budget']),
      createdBy: _asNullableInt(json['createdBy'] ?? json['created_by']),
      creatorNickname:
          (json['creatorNickname'] ?? json['creator_nickname'])?.toString(),
      creatorAvatar:
          (json['creatorAvatar'] ?? json['creator_avatar'])?.toString(),
      editedByBoth: _asBool(json['editedByBoth'] ?? json['edited_by_both']),
      transportation: json['transportation']?.toString(),
      nearby: json['nearby']?.toString(),
      tips: json['tips']?.toString(),
      businessHours:
          (json['businessHours'] ?? json['business_hours'])?.toString(),
      checkedInAt: (json['checkedInAt'] ?? json['checked_in_at'])?.toString(),
      routeId: _asNullableInt(json['routeId'] ?? json['route_id']),
      routeDay: _asNullableInt(json['routeDay'] ?? json['route_day']),
      routeOrder: _asNullableInt(json['routeOrder'] ?? json['route_order']),
    );
  }
}

class TravelStats {
  final int visited;
  final int wish;
  final int planned;
  final int cities;
  final double totalBudget;

  TravelStats({
    this.visited = 0,
    this.wish = 0,
    this.planned = 0,
    this.cities = 0,
    this.totalBudget = 0,
  });

  factory TravelStats.fromJson(Map<String, dynamic> json) {
    return TravelStats(
      visited: _asInt(json['visited']),
      wish: _asInt(json['wish']),
      planned: _asInt(json['planned']),
      cities: _asInt(json['cities']),
      totalBudget: _asDouble(json['totalBudget'] ?? json['total_budget']),
    );
  }
}

class TravelRoutePoint {
  final double lat;
  final double lng;

  TravelRoutePoint({required this.lat, required this.lng});

  factory TravelRoutePoint.fromJson(Map<String, dynamic> json) {
    return TravelRoutePoint(
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class TravelRoute {
  final int? id;
  final String title;
  final String city;
  final String description;
  final String status;
  final String mode;
  final int? distance;
  final int? duration;
  final String? startDate;
  final String? endDate;
  final int? days;
  final double? estimatedBudget;
  final List<TravelRoutePoint> path;
  final List<TravelSpot> spots;

  TravelRoute({
    this.id,
    required this.title,
    this.city = '',
    this.description = '',
    this.status = 'draft',
    this.mode = 'driving',
    this.distance,
    this.duration,
    this.startDate,
    this.endDate,
    this.days,
    this.estimatedBudget,
    List<TravelRoutePoint>? path,
    List<TravelSpot>? spots,
  })  : path = path ?? const [],
        spots = spots ?? const [];

  factory TravelRoute.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final spots = json['spots'];
    return TravelRoute(
      id: _asNullableInt(json['id']),
      title: _asString(json['title']),
      city: _asString(json['city']),
      description: _asString(json['description']),
      status: _asString(json['status'], fallback: 'draft'),
      mode: _asString(json['mode'], fallback: 'driving'),
      distance: _asNullableInt(json['distance']),
      duration: _asNullableInt(json['duration']),
      startDate: (json['startDate'] ?? json['start_date'])?.toString(),
      endDate: (json['endDate'] ?? json['end_date'])?.toString(),
      days: _asNullableInt(json['days']),
      estimatedBudget: _asNullableDouble(
          json['estimatedBudget'] ?? json['estimated_budget']),
      path: path is List
          ? path
              .map((item) =>
                  TravelRoutePoint.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const [],
      spots: spots is List
          ? spots
              .map((item) =>
                  TravelSpot.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : const [],
    );
  }
}

class TravelProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<TravelSpot> _spots = [];
  List<TravelRoute> _routes = [];
  TravelRoute? _activeRoute;
  TravelStats? _stats;
  bool _loading = false;
  bool _routeLoading = false;
  String? _routeError;
  String? _error;
  String _activeStatus = '';
  String _searchQuery = '';
  String _sortBy = 'default';
  int? _highlightedId;

  List<TravelSpot> get spots => _spots;
  List<TravelRoute> get routes => _routes;
  TravelRoute? get activeRoute => _activeRoute;
  TravelStats? get stats => _stats;
  bool get loading => _loading;
  bool get routeLoading => _routeLoading;
  String? get routeError => _routeError;
  String? get error => _error;
  bool get hasError => _error != null;
  String get activeStatus => _activeStatus;
  String get searchQuery => _searchQuery;
  String get sortBy => _sortBy;
  int? get highlightedId => _highlightedId;

  List<TravelSpot> get filteredSpots {
    var list = _applyStatusAndSearch(_spots, includeTextFields: true);
    switch (_sortBy) {
      case 'name':
        list = List.of(list)..sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'rating':
        list = List.of(list)
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case 'date':
        list = List.of(list)
          ..sort((a, b) => (b.visitedDate ?? b.plannedDate ?? '')
              .compareTo(a.visitedDate ?? a.plannedDate ?? ''));
        break;
      case 'city':
        list = List.of(list)..sort((a, b) => a.city.compareTo(b.city));
        break;
    }
    return list;
  }

  List<TravelSpot> get mapSpots =>
      _applyStatusAndSearch(_spots, includeTextFields: false);

  TravelStats get computedStats {
    final visited = _spots.where((spot) => spot.status == 'visited').length;
    final wish = _spots.where((spot) => spot.status == 'wish').length;
    final planned = _spots.where((spot) => spot.status == 'planned').length;
    final cities = _spots
        .where((spot) => spot.city.isNotEmpty)
        .map((spot) => spot.city)
        .toSet()
        .length;
    final totalBudget = _spots
        .where((spot) => spot.budget != null)
        .fold(0.0, (sum, spot) => sum + spot.budget!);
    return TravelStats(
      visited: visited,
      wish: wish,
      planned: planned,
      cities: cities,
      totalBudget: totalBudget,
    );
  }

  List<TravelSpot> _applyStatusAndSearch(
    List<TravelSpot> source, {
    required bool includeTextFields,
  }) {
    var list = source;
    if (_activeStatus == 'both') {
      list = list.where((spot) => spot.editedByBoth).toList();
    } else if (_activeStatus.isNotEmpty) {
      list = list.where((spot) => spot.status == _activeStatus).toList();
    }
    if (_searchQuery.isEmpty) return list;

    final query = _searchQuery.toLowerCase();
    return list.where((spot) {
      final fields = <String>[
        spot.name,
        spot.city,
        spot.address,
        if (includeTextFields) ...[
          spot.note ?? '',
          spot.noteMine ?? '',
          spot.noteHer ?? '',
          spot.diary ?? '',
          spot.transportation ?? '',
          spot.nearby ?? '',
          spot.tips ?? '',
        ],
      ];
      return fields.any((field) => field.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> refreshAll() async {
    _error = null;
    notifyListeners();
    await Future.wait([fetchSpots(), fetchStats(), fetchRoutes()]);
  }

  Future<void> fetchSpots() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.getTravelSpots();
      final data = response.data?['data'];
      if (data is Map) {
        final list = data['list'];
        _spots = list is List
            ? list
                .map((item) =>
                    TravelSpot.fromJson(Map<String, dynamic>.from(item)))
                .toList(growable: false)
            : [];
      } else if (data is List) {
        _spots = data
            .map((item) => TravelSpot.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      } else {
        _spots = [];
      }
    } catch (_) {
      _error = '旅行地点加载失败，请检查网络后重试';
      _spots = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchStats() async {
    _error = null;
    try {
      final response = await _api.getTravelStats();
      final data = response.data?['data'];
      if (data is Map) {
        _stats = TravelStats.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {
      _error = '旅行统计加载失败，请检查网络后重试';
    }
    notifyListeners();
  }

  Future<void> fetchRoutes() async {
    _error = null;
    try {
      dynamic response;
      try {
        response = await _api.getTravelTrips();
      } catch (_) {
        response = await _api.getTravelRoutes();
      }
      final data = response.data?['data'];
      if (data is Map) {
        final list = data['list'];
        _routes = list is List
            ? list
                .map((item) =>
                    TravelRoute.fromJson(Map<String, dynamic>.from(item)))
                .toList(growable: false)
            : [];
      } else if (data is List) {
        _routes = data
            .map(
                (item) => TravelRoute.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      } else {
        _routes = [];
      }
    } catch (_) {
      _error = '旅行路线加载失败，请检查网络后重试';
    }
    notifyListeners();
  }

  Future<void> previewRoute(List<TravelSpot> selectedSpots, String mode) async {
    final validSpots = selectedSpots.where(_hasValidCoordinate).toList();
    if (validSpots.length < 2) {
      _routeError = '至少需要两个有坐标的地点才能预览路线';
      notifyListeners();
      return;
    }

    _routeLoading = true;
    _routeError = null;
    notifyListeners();

    final title = '${validSpots.first.name} 到 ${validSpots.last.name}';
    try {
      final origin = '${validSpots.first.lng},${validSpots.first.lat}';
      final destination = '${validSpots.last.lng},${validSpots.last.lat}';
      final waypoints = validSpots.length > 2
          ? validSpots
              .sublist(1, validSpots.length - 1)
              .map((spot) => '${spot.lng},${spot.lat}')
              .join(';')
          : null;
      final response = await _api.getAmapDirection(
        origin: origin,
        destination: destination,
        mode: mode,
        city: validSpots.first.city,
        waypoints: mode == 'driving' ? waypoints : null,
      );
      final data = response.data?['data'];
      if (data is! Map) throw Exception('路线结果为空');
      final path = data['path'] is List
          ? (data['path'] as List)
              .map((item) =>
                  TravelRoutePoint.fromJson(Map<String, dynamic>.from(item)))
              .toList(growable: false)
          : <TravelRoutePoint>[];
      _activeRoute = TravelRoute(
        title: title,
        city: validSpots.first.city,
        mode: mode,
        distance: _asNullableInt(data['distance']),
        duration: _asNullableInt(data['duration']),
        path: path,
        spots: validSpots,
      );
    } catch (_) {
      _activeRoute = TravelRoute(
        title: title,
        city: validSpots.first.city,
        mode: mode,
        path: validSpots
            .map((spot) => TravelRoutePoint(lat: spot.lat, lng: spot.lng))
            .toList(growable: false),
        spots: validSpots,
      );
      _routeError = '路线服务暂时不可用，已用直线预览当前顺序';
    }

    _routeLoading = false;
    notifyListeners();
  }

  Future<void> saveActiveRoute() async {
    final route = _activeRoute;
    if (route == null) return;

    final payload = {
      'title': route.title,
      'city': route.city,
      'description': route.description,
      'status': 'draft',
      'mode': route.mode,
      'distance': route.distance,
      'duration': route.duration,
      'path': route.path.map((point) => point.toJson()).toList(),
      'spotIds': route.spots.map((spot) => spot.id).toList(),
    };

    _error = null;
    try {
      await _api.createTravelTrip(payload);
    } catch (_) {
      try {
        await _api.createTravelRoute(payload);
      } catch (_) {
        _error = '路线保存失败，请检查网络后重试';
        notifyListeners();
        return;
      }
    }
    await fetchRoutes();
  }

  void clearActiveRoute() {
    _activeRoute = null;
    _routeError = null;
    notifyListeners();
  }

  void setStatus(String status) {
    _activeStatus = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void highlightSpot(int? id) {
    _highlightedId = id;
    notifyListeners();
  }

  Future<void> createSpot(Map data) async {
    _error = null;
    try {
      await _api.createTravelSpot(data);
      await refreshAll();
    } catch (_) {
      _error = '地点保存失败，请检查网络后重试';
      notifyListeners();
    }
  }

  Future<void> updateSpot(int id, Map data) async {
    _error = null;
    try {
      await _api.updateTravelSpot(id, data);
      await refreshAll();
    } catch (_) {
      _error = '地点保存失败，请检查网络后重试';
      notifyListeners();
    }
  }

  Future<void> deleteSpot(int id) async {
    _error = null;
    try {
      await _api.deleteTravelSpot(id);
      await refreshAll();
    } catch (_) {
      _error = '地点删除失败，请检查网络后重试';
      notifyListeners();
    }
  }
}
