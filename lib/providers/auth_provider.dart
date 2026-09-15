import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  static const String _profileCacheKey = 'user_profile_cache';
  static const bool _e2eAutoLogin = bool.fromEnvironment(
    'LOVEGIRL_E2E_AUTO_LOGIN',
    defaultValue: false,
  );

  final ApiService _api = ApiService();
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _isInitializing = true;
  String? _error;
  String? _devOverrideRole;

  Map<String, dynamic>? get user => _user;
  int? get userId => int.tryParse(_user?['id']?.toString() ?? '');
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitializing => _isInitializing;
  String? get error => _error;

  bool get isAdmin =>
      _user?['is_admin'] == true ||
      _user?['isAdmin'] == true ||
      _user?['role'] == 'admin' ||
      _user?['username'] == 'admin';

  Future<void> init() async {
    _isLoading = true;
    _isInitializing = true;
    notifyListeners();

    try {
      final token = await _storage.read(key: AppConstants.tokenKey);
      if (token == null) {
        if (kDebugMode && _e2eAutoLogin) {
          await login('admin', 'admin123');
          return;
        }
        _user = null;
        _isLoggedIn = false;
        await _storage.delete(key: _profileCacheKey);
        return;
      }

      final cachedUser = await _readCachedUser();
      if (cachedUser != null) {
        _user = cachedUser;
      }
      _isLoggedIn = true;
      _error = null;
      notifyListeners();

      try {
        final res = await _api.getProfile().timeout(const Duration(seconds: 6));
        final profileData = res.data['data'];
        _user =
            profileData is Map ? Map<String, dynamic>.from(profileData) : null;
        await _cacheUser(_user);
        _isLoggedIn = true;
        _error = null;
      } catch (e) {
        if (_isUnauthorized(e)) {
          await _storage.delete(key: AppConstants.tokenKey);
          await _storage.delete(key: 'refresh_token');
          await _storage.delete(key: _profileCacheKey);
          _user = null;
          _isLoggedIn = false;
          _error = '登录已过期，请重新登录';
        } else {
          // 非 401 场景保留本地会话，避免冷启动时短暂网络波动把用户踢回登录页。
          _isLoggedIn = true;
          _error = null;
          debugPrint('[AuthProvider] keep cached session after profile fetch error: $e');
        }
      }
    } finally {
      _isLoading = false;
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.login(username, password);
      final data = res.data['data'];
      if (data == null) {
        throw Exception('服务器返回数据异常：缺少 data 字段');
      }

      final tokenRaw = data['accessToken'] ?? data['token'];
      if (tokenRaw == null) {
        throw Exception('服务器返回数据异常：缺少 accessToken');
      }

      final token = tokenRaw as String;
      final refreshToken = data['refreshToken'] as String?;
      await _storage.write(key: AppConstants.tokenKey, value: token);

      if (refreshToken != null) {
        await _storage.write(key: 'refresh_token', value: refreshToken);
      }

      if (data['user'] != null) {
        _user = Map<String, dynamic>.from(data['user']);
      } else {
        final profileRes = await _api.getProfile();
        final profileData = profileRes.data['data'];
        _user =
            profileData is Map ? Map<String, dynamic>.from(profileData) : null;
      }

      await _cacheUser(_user);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('[AuthProvider] login failed: $e');
      debugPrint('[AuthProvider] stack: $stack');
      _error = _friendlyAuthError(
        e,
        fallback: '登录失败了，检查一下账号和密码再试试',
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String username,
    String password,
    String nickname, {
    String gender = 'female',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res =
          await _api.register(username, password, nickname, gender: gender);
      final data = res.data['data'];
      final token = (data['accessToken'] ?? data['token']) as String;
      await _storage.write(key: AppConstants.tokenKey, value: token);
      if (data['user'] != null) {
        _user = Map<String, dynamic>.from(data['user']);
      } else {
        final profileRes = await _api.getProfile();
        final profileData = profileRes.data['data'];
        _user =
            profileData is Map ? Map<String, dynamic>.from(profileData) : null;
      }
      await _cacheUser(_user);
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
      final profileData = res.data['data'];
      _user =
          profileData is Map ? Map<String, dynamic>.from(profileData) : null;
      await _cacheUser(_user);
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: _profileCacheKey);
    _user = null;
    _isLoggedIn = false;
    _devOverrideRole = null;
    notifyListeners();
  }

  bool _isUnauthorized(Object error) {
    return error is DioException && error.response?.statusCode == 401;
  }

  String _friendlyAuthError(Object error, {required String fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '网络有点慢，稍后再试试';
        case DioExceptionType.connectionError:
          return '现在连不上服务器，等一会儿再试试';
        default:
          break;
      }
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> _readCachedUser() async {
    final raw = await _storage.read(key: _profileCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      await _storage.delete(key: _profileCacheKey);
    }
    return null;
  }

  Future<void> _cacheUser(Map<String, dynamic>? user) async {
    if (user == null) return;
    await _storage.write(key: _profileCacheKey, value: jsonEncode(user));
  }

  // ========== 开发者模式：角色切换 ==========

  /// 当前角色（考虑开发者模式覆盖）
  bool get isGirl {
    if (_devOverrideRole != null) return _devOverrideRole == 'girl';
    return _user?['role'] == 'girl';
  }

  /// 原始角色（忽略开发者模式覆盖）
  bool get isOriginalGirl => _user?['role'] == 'girl';

  /// 切换开发者角色（boy <-> girl），仅用于调试
  void toggleDevRole() {
    if (_user == null) return;
    if (_devOverrideRole == null) {
      _devOverrideRole = _user!['role'] == 'girl' ? 'boy' : 'girl';
    } else {
      _devOverrideRole = _devOverrideRole == 'girl' ? 'boy' : 'girl';
    }
    notifyListeners();
  }

  /// 取消开发者角色覆盖
  void resetDevRole() {
    _devOverrideRole = null;
    notifyListeners();
  }

  /// 是否处于开发者角色覆盖状态
  bool get isDevRoleOverridden => _devOverrideRole != null;

  int get loveDays {
    if (_user == null) return 0;
    final dateStr = _user!['loveStartDate'] ?? _user!['created_at'];
    if (dateStr == null) return 0;
    final date = DateTime.tryParse(dateStr.toString());
    if (date == null) return 0;
    return DateTime.now().difference(date).inDays + 1;
  }
}
