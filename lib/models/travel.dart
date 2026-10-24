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

class TravelSpot {
  final int id;
  final String name;
  final String city;
  final String address;
  final double lng;
  final double lat;
  final String emoji;
  final String status;
  final int pinned; // 置顶（W3 左滑三键）
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
    this.pinned = 0,
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
      pinned: _asInt(json['pinned']),
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
