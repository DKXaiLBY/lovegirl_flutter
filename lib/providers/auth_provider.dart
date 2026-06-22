import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic>? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get error => _error;
  bool get isGirl => _user?['role'] == 'girl';
  bool get isAdmin => _user?['is_admin'] == true;

  Future<void> init() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token != null) {
      try {
        final res = await _api.getProfile();
        _user = res.data['data'];
        _isLoggedIn = true;
      } catch (_) {
        await _storage.delete(key: AppConstants.tokenKey);
      }
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.login(username, password);
      final data = res.data['data'];
      // 后端返回 accessToken / refreshToken / user
      final token = (data['accessToken'] ?? data['token']) as String;
      final refreshToken = data['refreshToken'] as String?;
      await _storage.write(key: AppConstants.tokenKey, value: token);
      if (refreshToken != null) {
        await _storage.write(key: 'refresh_token', value: refreshToken);
      }
      // 登录响应自带 user，不需要额外请求
      if (data['user'] != null) {
        _user = data['user'];
      } else {
        final profileRes = await _api.getProfile();
        _user = profileRes.data['data'];
      }
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '登录失败，请检查用户名和密码';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String password, String nickname) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.register(username, password, nickname);
      final data = res.data['data'];
      final token = (data['accessToken'] ?? data['token']) as String;
      await _storage.write(key: AppConstants.tokenKey, value: token);
      if (data['user'] != null) {
        _user = data['user'];
      } else {
        final profileRes = await _api.getProfile();
        _user = profileRes.data['data'];
      }
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = '注册失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final res = await _api.updateProfile(data);
      _user = res.data['data'];
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  int get loveDays {
    if (_user == null) return 0;
    final dateStr = _user!['loveStartDate'] ?? _user!['created_at'];
    if (dateStr == null) return 0;
    final date = DateTime.tryParse(dateStr.toString());
    if (date == null) return 0;
    return DateTime.now().difference(date).inDays + 1;
  }
}
