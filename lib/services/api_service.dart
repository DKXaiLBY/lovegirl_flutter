import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 统一修复 UTF-8 双重编码（服务端将 UTF-8 字节误按 cp1252 再次编码）
/// MySQL 的 latin1 实际是 Windows-1252，0x80-0x9F 范围字符会映射到
/// U+20AC/U+201A/U+2039/U+203A 等多字节码点，Dart 的 latin1(ISO 8859-1)
/// 无法处理这些字符，需手动映射回原始字节。
String fixUtf8Encoding(Object? value, {String fallback = ''}) {
  final text = value?.toString() ?? fallback;
  if (text.isEmpty) return fallback;
  try {
    final looksBroken = text.codeUnits.any((c) => c > 127);
    if (!looksBroken) return text;
    final bytes = _toCp1252Bytes(text);
    if (bytes != null) {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      if (decoded.isNotEmpty && decoded != text) return decoded;
    }
  } catch (_) {}
  return text;
}

/// cp1252 → 原始字节（兼容 MySQL latin1 即 Windows-1252 行为）
List<int>? _toCp1252Bytes(String text) {
  final bytes = <int>[];
  for (final codeUnit in text.codeUnits) {
    if (codeUnit <= 0x7F) {
      bytes.add(codeUnit);
    } else if (codeUnit <= 0xFF) {
      bytes.add(codeUnit);
    } else {
      final b = _cp1252CodeToByte(codeUnit);
      if (b == null) return null;
      bytes.add(b);
    }
  }
  return bytes;
}

int? _cp1252CodeToByte(int codeUnit) {
  const map = <int, int>{
    0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84,
    0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88,
    0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C,
    0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
    0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
    0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
    0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
  };
  return map[codeUnit];
}

dynamic _deepFixEncoding(dynamic data) {
  if (data is String) return fixUtf8Encoding(data);
  if (data is Map) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      result[entry.key.toString()] = _deepFixEncoding(entry.value);
    }
    return result;
  }
  if (data is List) {
    return data.map((e) => _deepFixEncoding(e)).toList();
  }
  return data;
}

/// 深度递归将 Map(dynamic, dynamic) 转为 Map(String, dynamic)
/// 不依赖 _deepFixEncoding，纯类型转换，不会抛异常
Map<String, dynamic> _castToTypedMap(dynamic data) {
  final result = <String, dynamic>{};
  if (data is Map) {
    for (final entry in data.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is Map) {
        result[key] = _castToTypedMap(value);
      } else if (value is List) {
        result[key] = value.map((e) => e is Map ? _castToTypedMap(e) : e).toList();
      } else if (value is String) {
        result[key] = fixUtf8Encoding(value);
      } else {
        result[key] = value;
      }
    }
  }
  return result;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      contentType: 'application/json',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        LogService().info('API', '${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        // 统一深度转换：先修 UTF-8 编码，再确保类型正确
        if (response.data is Map) {
          try {
            response.data = _deepFixEncoding(response.data);
          } catch (e) {
            debugPrint('[ApiService] _deepFixEncoding failed: $e');
          }
          // 🔴 核心修复：强制深度转换为 Map<String, dynamic>
          response.data = _castToTypedMap(response.data);
        } else if (response.data is List) {
          try {
            response.data = _deepFixEncoding(response.data);
          } catch (e) {
            debugPrint('[ApiService] _deepFixEncoding failed: $e');
          }
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        LogService().error('API',
            '${error.requestOptions.method} ${error.requestOptions.path}: ${error.response?.statusCode} ${error.message}');
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: AppConstants.tokenKey);
        }
        handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<Response> upload(String path, String filePath,
      {String fieldName = 'file'}) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    return _dio.post(path, data: formData);
  }

  // ========== 认证 ==========
  Future login(String username, String password) => post('/api/auth/login',
      data: json.encode({'username': username, 'password': password}));

  Future register(String username, String password, String nickname,
          {String gender = 'female'}) =>
      post('/api/auth/register', data: {
        'username': username,
        'password': password,
        'nickname': nickname,
        'gender': gender,
      });

  // ========== 用户 ==========
  Future getProfile() => get('/api/user/profile');
  Future updateProfile(Map data) => put('/api/user/profile', data: data);

  // ========== 首页 ==========
  Future getHomeToday() => get('/api/home/today');
  Future getHomeMemory() => get('/api/home/memory');

  // ========== 旅行 ==========
  Future getTravelSpots({String? status, String? city}) =>
      get('/api/travel/spots', query: {'status': status, 'city': city});
  Future getTravelSpot(int id) => get('/api/travel/spots/$id');
  Future createTravelSpot(Map data) => post('/api/travel/spots', data: data);
  Future updateTravelSpot(int id, Map data) =>
      put('/api/travel/spots/$id', data: data);
  Future deleteTravelSpot(int id) => delete('/api/travel/spots/$id');
  Future getTravelStats() => get('/api/travel/stats');
  Future getTravelRoutes() => get('/api/travel/routes');
  Future createTravelRoute(Map data) => post('/api/travel/routes', data: data);
  Future getTravelTrips() => get('/api/travel/trips');
  Future getTravelTrip(int id) => get('/api/travel/trips/$id');
  Future createTravelTrip(Map data) => post('/api/travel/trips', data: data);
  Future updateTravelTrip(int id, Map data) =>
      put('/api/travel/trips/$id', data: data);
  Future updateTravelTripSpots(int id, List<int> spotIds) =>
      put('/api/travel/trips/$id/spots', data: {'spotIds': spotIds});
  Future deleteTravelTrip(int id) => delete('/api/travel/trips/$id');
  Future searchAmapPoi(String keywords, {String? city}) =>
      get('/api/travel/amap/poi', query: {
        'keywords': keywords,
        if (city != null && city.isNotEmpty) 'city': city,
      });
  Future geocodeAmap(String address, {String? city}) =>
      get('/api/travel/amap/geocode', query: {
        'address': address,
        if (city != null && city.isNotEmpty) 'city': city,
      });
  Future regeoAmap(double lat, double lng) =>
      get('/api/travel/amap/regeo', query: {'lat': lat, 'lng': lng});
  Future getAmapWeather(String city) =>
      get('/api/travel/amap/weather', query: {'city': city});
  Future getAmapDirection({
    required String origin,
    required String destination,
    String mode = 'driving',
    String? city,
    String? waypoints,
  }) =>
      get('/api/travel/amap/direction', query: {
        'origin': origin,
        'destination': destination,
        'mode': mode,
        if (city != null && city.isNotEmpty) 'city': city,
        if (waypoints != null && waypoints.isNotEmpty) 'waypoints': waypoints,
      });

  // 旅行照片
  Future uploadTravelPhoto(int spotId, String filePath) =>
      upload('/api/travel/spots/$spotId/photos', filePath, fieldName: 'photo');
  Future getTravelPhotos(int spotId) => get('/api/travel/spots/$spotId/photos');
  Future deleteTravelPhoto(int spotId, int photoId) =>
      delete('/api/travel/spots/$spotId/photos/$photoId');

  // ========== 姨妈 ==========
  Future getPeriods() => get('/api/period');
  Future savePeriod(Map data) => post('/api/period', data: data);
  Future getPeriodAnalysis() => get('/api/period/analysis');
  Future getPeriodStatus() => get('/api/period/status');

  // ========== 待办 ==========
  Future getTodos() => get('/api/todo');
  Future createTodo(Map data) => post('/api/todo', data: data);
  Future updateTodo(int id, Map data) => put('/api/todo/$id', data: data);
  Future deleteTodo(int id) => delete('/api/todo/$id');
  Future toggleTodo(int id) => put('/api/todo/$id/toggle');

  // ========== 记账 ==========
  Future getFinanceRecords(String month, {String? source}) =>
      get('/api/finance', query: {
        'month': month,
        if (source != null && source.isNotEmpty) 'source': source,
      });
  Future addFinanceRecord(Map data) => post('/api/finance', data: data);
  Future deleteFinanceRecord(int id) => delete('/api/finance/$id');
  Future getFinanceStats(String month, {String? source}) =>
      get('/api/finance/stats', query: {
        'month': month,
        if (source != null && source.isNotEmpty) 'source': source,
      });

  // ========== 课程表 ==========
  Future getCourses(String term) => get('/api/course', query: {'term': term});
  Future createCourse(Map data) => post('/api/course', data: data);
  Future updateCourse(int id, Map data) => put('/api/course/$id', data: data);
  Future deleteCourse(int id) => delete('/api/course/$id');

  // ========== 相册 ==========
  Future getPhotos() => get('/api/photo');
  Future deletePhoto(int id) => delete('/api/photo/$id');

  // ========== 心情 ==========
  Future getMoods(String month) => get('/api/mood', query: {'month': month});
  Future recordMood(Map data) => post('/api/mood', data: data);
  Future getMoodStats(String month) =>
      get('/api/mood/stats', query: {'month': month});

  // ========== 聊天 ==========
  Future getMessages({int page = 1, int size = 20}) =>
      get('/api/chat', query: {'page': page, 'size': size});
  Future sendMessage(Map data) => post('/api/chat', data: data);
  Future getUnreadCount() => get('/api/chat/unread');

  // ========== 时光轴 ==========
  Future getTimeline() => get('/api/timeline');
  Future createTimeline(Map data) => post('/api/timeline', data: data);
  Future deleteTimeline(int id) => delete('/api/timeline/$id');

  // ========== 投喂站 ==========
  Future getFeedingShops() => get('/api/feeding/shops');
  Future getFeedingShopProducts(int shopId) =>
      get('/api/feeding/shops/$shopId/products');
  Future getFeedingCategories() => get('/api/feeding/categories');
  Future getFeedingProducts(int categoryId) =>
      get('/api/feeding/products', query: {'shop_id': categoryId});
  Future createFeedingOrder(Map data) =>
      post('/api/feeding/orders', data: data);
  Future getFeedingOrders() => get('/api/feeding/orders');
  Future getFeedingStats() => get('/api/feeding/stats');
  Future updateFeedingOrderStatus(int id, String status, {Map? extra}) =>
      put('/api/feeding/orders/$id/status',
          data: {'status': status, ...?extra});
  Future urgeFeedingOrder(int id) => post('/api/feeding/orders/$id/urge');
  Future fulfillFeedingOrder(int id, Map data) =>
      post('/api/feeding/orders/$id/fulfill', data: data);
  Future updateFeedingOrderInfo(int id, Map data) =>
      put('/api/feeding/orders/$id', data: data);
  Future updateFeedingOrderDelivery(int id, Map data) =>
      put('/api/feeding/orders/$id/delivery', data: data);

  // ========== 情侣厨房 ==========
  Future getKitchenMenu() => get('/api/kitchen/menu');
  Future createKitchenDish(Map data) => post('/api/kitchen/dishes', data: data);
  Future updateKitchenDish(int id, Map data) =>
      put('/api/kitchen/dishes/$id', data: data);
  Future deleteKitchenDish(int id) => delete('/api/kitchen/dishes/$id');
  Future getKitchenOrders() => get('/api/kitchen/orders');
  Future createKitchenOrder(Map data) => post('/api/kitchen/orders', data: data);
  Future updateKitchenOrderStatus(int id, String status, {Map? extra}) =>
      put('/api/kitchen/orders/$id/status',
          data: {'status': status, ...?extra});
  Future getKitchenSummary() => get('/api/kitchen/summary');
  Future uploadKitchenPhoto(String filePath) =>
      upload('/api/kitchen/upload', filePath, fieldName: 'photo');

  // ========== 通知中心 ==========
  Future getNotifications({int size = 50}) =>
      get('/api/notifications', query: {'size': size});
  Future getUnreadNotificationCount() =>
      get('/api/notifications/unread-count');
  Future markNotificationRead(int id) =>
      put('/api/notifications/$id/read');
  Future markAllNotificationsRead() => put('/api/notifications/read-all');

  // ========== 每日一问 ==========
  Future getDailyToday() => get('/api/daily/today');
  Future answerDailyQuestion(String answer) =>
      post('/api/daily/answer', data: {'answer': answer});
  Future getDailyHistory({int size = 14}) =>
      get('/api/daily/history', query: {'size': size});

  // ========== 爱情树 ==========
  Future getLoveTree() => get('/api/tree');
  Future waterLoveTree() => post('/api/tree/water');

  // ========== 版本 ==========
  Future checkVersion(int versionCode) =>
      get('/api/version/check', query: {'version_code': versionCode});

  // ========== 纪念日 ==========
  Future getAnniversaries() => get('/api/anniversary');
  Future createAnniversary(Map data) => post('/api/anniversary', data: data);
  Future updateAnniversary(int id, Map data) =>
      put('/api/anniversary/$id', data: data);
  Future deleteAnniversary(int id) => delete('/api/anniversary/$id');

  // ========== 隐私 ==========
  Future getPrivacy() => get('/api/privacy');
  Future updatePrivacy(Map data) => put('/api/privacy', data: data);

  // ========== 头像上传 ==========
  Future uploadAvatar(String filePath) => upload('/api/user/avatar', filePath);

  // ========== 伴侣绑定 ==========
  Future getCoupleStatus() => get('/api/couple');
  Future createCoupleInvite() => post('/api/couple/invite');
  Future acceptCoupleInvite(String code) =>
      post('/api/couple/accept', data: {'code': code});
  Future breakCouple() => delete('/api/couple');

  // ========== 爱心豆 ==========
  Future getBeanBalance() => get('/api/beans/balance');
  Future getBeanTransactions({int page = 1, int size = 20}) =>
      get('/api/beans/transactions', query: {'page': page, 'size': size});
  Future getBeanCheckInStatus() => get('/api/beans/checkin/status');
  Future dailyBeanCheckIn() => post('/api/beans/checkin');

  // ========== 成就 ==========
  Future getAchievements() => get('/api/achievements');
  Future checkAchievements({String? category}) =>
      post('/api/achievements/check', data: {
        if (category != null && category.isNotEmpty) 'category': category,
      });

  // ========== 管理后台 ==========
  Future getAdminShops({bool includeInactive = false}) =>
      get('/api/admin/shops', query: {
        if (includeInactive) 'include_inactive': '1',
      });
  Future createAdminShop(Map data) => post('/api/admin/shops', data: data);
  Future updateAdminShop(int id, Map data) =>
      put('/api/admin/shops/$id', data: data);
  Future deleteAdminShop(int id) => delete('/api/admin/shops/$id');
  Future getAdminProducts(int shopId, {bool includeInactive = false}) =>
      get('/api/admin/shops/$shopId/products', query: {
        if (includeInactive) 'include_inactive': '1',
      });
  Future createAdminProduct(int shopId, Map data) =>
      post('/api/admin/shops/$shopId/products', data: data);
  Future updateAdminProduct(int id, Map data) =>
      put('/api/admin/products/$id', data: data);
  Future toggleAdminProduct(int id, {bool? isActive}) =>
      put('/api/admin/products/$id/toggle', data: {
        if (isActive != null) 'is_active': isActive,
      });
  Future deleteAdminProduct(int id) => delete('/api/admin/products/$id');

  Future createFeedingProduct(Map data) =>
      post('/api/feeding/products', data: data);
  Future updateFeedingProduct(int id, Map data) =>
      put('/api/feeding/products/$id', data: data);
  Future deleteFeedingProduct(int id) => delete('/api/feeding/products/$id');
}
