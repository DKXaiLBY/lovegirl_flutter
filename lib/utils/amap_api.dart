import 'package:dio/dio.dart';

/// 高德地图 Web API 工具类
/// 用于 POI 搜索、地理编码等
class AmapApi {
  static const String _apiKey = '470b27171201bf472ba04539a0bb2693';
  static const String _baseUrl = 'https://restapi.amap.com';

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// POI 关键字搜索
  /// 返回 {name, address, lat, lng, city} 列表
  static Future<List<AmapPoi>> searchPoi(String keyword, {String? city}) async {
    try {
      final response = await _dio.get('$_baseUrl/v3/place/text', queryParameters: {
        'key': _apiKey,
        'keywords': keyword,
        'city': city ?? '',
        'citylimit': city != null && city.isNotEmpty ? 'true' : 'false',
        'offset': '20',
        'page': '1',
        'extensions': 'base',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == '1' && data['pois'] != null) {
          return (data['pois'] as List).map((e) => AmapPoi.fromJson(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// 逆地理编码（坐标 → 地址）
  static Future<AmapRegeo?> regeo(double lat, double lng) async {
    try {
      final response = await _dio.get('$_baseUrl/v3/geocode/regeo', queryParameters: {
        'key': _apiKey,
        'location': '$lng,$lat',
        'extensions': 'base',
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['status'] == '1' && data['regeocode'] != null) {
          return AmapRegeo.fromJson(data['regeocode']);
        }
      }
    } catch (_) {}
    return null;
  }
}

/// 高德 POI 数据
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
    final location = json['location']?.toString() ?? '0,0';
    final parts = location.split(',');
    return AmapPoi(
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      city: json['cityname'] ?? json['city'] ?? '',
      lng: double.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0,
      lat: double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
      type: json['type'] ?? '',
    );
  }
}

/// 高德逆地理编码结果
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
      address: json['formatted_address'] ?? '',
      city: addressComponent['city'] ?? '',
      district: addressComponent['district'] ?? '',
    );
  }
}
