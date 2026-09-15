import '../services/api_service.dart';

/// AMap Web service helper.
///
/// Web service calls are proxied through the backend so the Web key never
/// ships inside the Flutter APK.
class AmapApi {
  static final ApiService _api = ApiService();

  static Future<List<AmapPoi>> searchPoi(String keyword, {String? city}) async {
    final response = await _api.searchAmapPoi(keyword, city: city);
    final list = response.data?['data']?['list'];
    if (list is List) {
      return list
          .map((e) => AmapPoi.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  static Future<AmapRegeo?> regeo(double lat, double lng) async {
    try {
      final response = await _api.regeoAmap(lat, lng);
      final data = response.data?['data'];
      if (data is Map) {
        return AmapRegeo.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }
}

class AmapPoi {
  final String name;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final String type;

  AmapPoi({
    required this.name,
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
    this.type = '',
  });

  factory AmapPoi.fromJson(Map<String, dynamic> json) {
    return AmapPoi(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      city: json['cityname'] ?? json['city'] ?? '',
      lng: _readCoordinate(json, 'lng', 0),
      lat: _readCoordinate(json, 'lat', 1),
      type: json['type'] ?? '',
    );
  }

  static double _readCoordinate(
      Map<String, dynamic> json, String key, int index) {
    if (json[key] != null) {
      return double.tryParse(json[key].toString()) ?? 0;
    }
    final parts = (json['location']?.toString() ?? '0,0').split(',');
    return double.tryParse(parts.length > index ? parts[index] : '0') ?? 0;
  }
}

class AmapRegeo {
  final String address;
  final String city;
  final String district;

  AmapRegeo({
    required this.address,
    required this.city,
    required this.district,
  });

  factory AmapRegeo.fromJson(Map<String, dynamic> json) {
    final addressComponent = json['addressComponent'] ?? {};
    return AmapRegeo(
      address: json['formatted_address'] ?? json['address'] ?? '',
      city: json['city'] ?? addressComponent['city'] ?? '',
      district: json['district'] ?? addressComponent['district'] ?? '',
    );
  }
}
