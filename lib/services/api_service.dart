import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';
import 'log_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
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
        LogService().api(
          response.requestOptions.method,
          response.requestOptions.path,
          statusCode: response.statusCode,
          response: response.data,
        );
        handler.next(response);
      },
      onError: (error, handler) async {
        LogService().error('API', '${error.requestOptions.method} ${error.requestOptions.path}: ${error.response?.statusCode} ${error.message}');
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: AppConstants.tokenKey);
        }
        handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) =>
      _dio.delete(path);

  Future<Response> upload(String path, String filePath, {String fieldName = 'file'}) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    return _dio.post(path, data: formData);
  }

  // ========== 认证 ==========
  Future login(String username, String password) =>
      post('/api/auth/login', data: {'username': username, 'password': password});

  Future register(String username, String password, String nickname) =>
      post('/api/auth/register', data: {'username': username, 'password': password, 'nickname': nickname});

  // ========== 用户 ==========
  Future getProfile() => get('/api/user/profile');
  Future updateProfile(Map data) => put('/api/user/profile', data: data);

  // ========== 旅行 ==========
  Future getTravelSpots({String? status, String? city}) =>
      get('/api/travel/spots', query: {'status': status, 'city': city});
  Future getTravelSpot(int id) => get('/api/travel/spots/$id');
  Future createTravelSpot(Map data) => post('/api/travel/spots', data: data);
  Future updateTravelSpot(int id, Map data) => put('/api/travel/spots/$id', data: data);
  Future deleteTravelSpot(int id) => delete('/api/travel/spots/$id');
  Future getTravelStats() => get('/api/travel/stats');

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

  // ========== 卡路里 ==========
  Future getCalorieRecords(String date) => get('/api/calorie/records', query: {'date': date});
  Future addCalorieRecord(Map data) => post('/api/calorie/records', data: data);
  Future deleteCalorieRecord(int id) => delete('/api/calorie/records/$id');
  Future searchFoods(String keyword) => get('/api/calorie/foods/search', query: {'keyword': keyword});

  // ========== 待办 ==========
  Future getTodos() => get('/api/todo');
  Future createTodo(Map data) => post('/api/todo', data: data);
  Future updateTodo(int id, Map data) => put('/api/todo/$id', data: data);
  Future deleteTodo(int id) => delete('/api/todo/$id');
  Future toggleTodo(int id) => put('/api/todo/$id/toggle');

  // ========== 记账 ==========
  Future getFinanceRecords(String month) => get('/api/finance', query: {'month': month});
  Future addFinanceRecord(Map data) => post('/api/finance', data: data);
  Future deleteFinanceRecord(int id) => delete('/api/finance/$id');
  Future getFinanceStats(String month) => get('/api/finance/stats', query: {'month': month});

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
  Future getMoodStats(String month) => get('/api/mood/stats', query: {'month': month});

  // ========== 聊天 ==========
  Future getMessages({int page = 1, int size = 20}) => get('/api/chat', query: {'page': page, 'size': size});
  Future sendMessage(Map data) => post('/api/chat', data: data);
  Future getUnreadCount() => get('/api/chat/unread');

  // ========== 时光轴 ==========
  Future getTimeline() => get('/api/timeline');
  Future createTimeline(Map data) => post('/api/timeline', data: data);
  Future deleteTimeline(int id) => delete('/api/timeline/$id');

  // ========== 投喂站 ==========
  Future getFeedingCategories() => get('/api/feeding/categories');
  Future getFeedingProducts(int categoryId) => get('/api/feeding/products', query: {'category_id': categoryId});
  Future createFeedingOrder(Map data) => post('/api/feeding/orders', data: data);
  Future getFeedingOrders() => get('/api/feeding/orders');
  Future getFeedingStats() => get('/api/feeding/stats');

  // ========== 版本 ==========
  Future checkVersion(int versionCode) => get('/api/version/check', query: {'version_code': versionCode});

  // ========== 纪念日 ==========
  Future getAnniversaries() => get('/api/anniversary');
  Future createAnniversary(Map data) => post('/api/anniversary', data: data);
  Future updateAnniversary(int id, Map data) => put('/api/anniversary/$id', data: data);
  Future deleteAnniversary(int id) => delete('/api/anniversary/$id');

  // ========== 隐私 ==========
  Future getPrivacy() => get('/api/privacy');
  Future updatePrivacy(Map data) => put('/api/privacy', data: data);

  // ========== 头像上传 ==========
  Future uploadAvatar(String filePath) => upload('/api/user/avatar', filePath);

  // ========== 搜索 ==========
  Future search(String keyword) => get('/api/search', query: {'keyword': keyword});

  // ========== 伴侣绑定 ==========
  Future getCoupleStatus() => get('/api/couple');
  Future createCoupleInvite() => post('/api/couple/invite');
  Future acceptCoupleInvite(String code) => post('/api/couple/accept', data: {'code': code});
  Future breakCouple() => delete('/api/couple');
}
