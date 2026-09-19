import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../utils/lovegirl_dates.dart';

class HomeProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool isLoading = false;
  String? error;
  Map<String, dynamic>? today;
  Map<String, dynamic>? memory;
  bool checkedIn = false;
  List<Map<String, dynamic>> recentAchievements = [];

  int get beanBalance {
    final value = today?['beanBalance'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get loveDays {
    final value = today?['loveDays'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  Future<void> refresh() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final month = _currentMonthKey();
      final results = await Future.wait([
        _safeRequest(() => _api.getHomeToday()),
        _safeRequest(() => _api.getHomeMemory()),
        _safeRequest(() => _api.getBeanCheckInStatus()),
        _safeRequest(() => _api.getKitchenOrders()),
        _safeRequest(() => _api.getTodos()),
        _safeRequest(() => _api.getTravelTrips()),
        _safeRequest(() => _api.getTravelRoutes()),
        _safeRequest(() => _api.getTravelSpots()),
        _safeRequest(() => _api.getFinanceStats(month)),
        _safeRequest(() => _api.getAnniversaries()),
      ]);

      final hadPartialFailure = results.any((item) => item == null);
      final todayRaw = _extractDataMap(results[0]);
      final memoryData = _extractData(results[1]);
      final statusData = _extractDataMap(results[2]);
      final kitchenData = _extractDataMap(results[3]);
      final feedingOrders = [
        ..._extractList(kitchenData['incoming']),
        ..._extractList(kitchenData['outgoing']),
      ];
      final todos = _extractList(results[4]);
      _rawTodos = todos;
      final travelTrips = _extractList(results[5]);
      final travelRoutes = _extractList(results[6]);
      final travelSpots = _extractList(results[7]);
      final financeStats = _extractDataMap(results[8]);
      final anniversaries = _extractList(results[9]);

      today = _buildTodayViewModel(
        todayRaw,
        feedingOrders: feedingOrders,
        todos: todos,
        travelTrips: travelTrips,
        travelRoutes: travelRoutes,
        travelSpots: travelSpots,
        financeStats: financeStats,
        anniversaries: anniversaries,
      );
      memory = memoryData is Map
          ? _buildMemoryViewModel(Map<String, dynamic>.from(memoryData))
          : null;
      checkedIn = statusData['checkedIn'] == true ||
          statusData['checked_in'] == true ||
          statusData['is_checked_in'] == true;

      final achievementsRaw = today?['recentAchievements'];
      if (achievementsRaw is List) {
        recentAchievements = achievementsRaw
            .map((item) => _mapFrom(item))
            .toList(growable: false);
      } else {
        recentAchievements = const [];
      }

      if (hadPartialFailure) {
        error =
            '\u7f51\u7edc\u6709\u70b9\u4e0d\u7a33\u5b9a\uff0c\u521a\u521a\u6709\u4e00\u90e8\u5206\u5185\u5bb9\u6ca1\u52a0\u8f7d\u51fa\u6765';
      }
    } catch (err) {
      error = _friendlyErrorMessage(
        err,
        fallback:
            '\u9996\u9875\u6709\u4e00\u70b9\u52a0\u8f7d\u5931\u8d25\uff0c\u5148\u5237\u65b0\u4e00\u6b21\u8bd5\u8bd5',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkIn() async {
    try {
      await _api.dailyBeanCheckIn();
      checkedIn = true;
      await refresh();
    } catch (err) {
      error = _friendlyErrorMessage(
        err,
        fallback:
            '\u7b7e\u5230\u5931\u8d25\u4e86\uff0c\u7a0d\u540e\u518d\u8bd5\u8bd5',
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<dynamic> _safeRequest(Future<dynamic> Function() loader) async {
    try {
      return await loader().timeout(const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildTodayViewModel(
    Map<String, dynamic> raw, {
    required List<Map<String, dynamic>> feedingOrders,
    required List<Map<String, dynamic>> todos,
    required List<Map<String, dynamic>> travelTrips,
    required List<Map<String, dynamic>> travelRoutes,
    required List<Map<String, dynamic>> travelSpots,
    required Map<String, dynamic> financeStats,
    required List<Map<String, dynamic>> anniversaries,
  }) {
    final todoSummary = _mapFrom(raw['todo']);
    final courseSummary = _mapFrom(raw['course']);
    final nextCourse = _mapFrom(courseSummary['next']);
    final financeToday = _mapFrom(raw['financeToday']);

    final preciseLoveDays = resolveLoveDays(
      explicitDate: raw['loveStartDate']?.toString(),
      anniversaries: anniversaries,
      fallbackDays: _asInt(raw['loveDays'], fallback: 1),
    );

    return {
      ...raw,
      'loveDays': preciseLoveDays,
      'feed': _buildFeedPreview(feedingOrders),
      'todo': {
        'total': _asInt(todoSummary['total']),
        'active': _asInt(todoSummary['active']),
        'dueToday': _asInt(todoSummary['dueToday']),
        'items': _buildTodoItems(todos),
      },
      'travelPreview': _buildTravelPreview(
        travelTrips: travelTrips,
        travelRoutes: travelRoutes,
        travelSpots: travelSpots,
      ),
      'finance': {
        'totalSpent': _asDouble(
          financeStats['totalExpense'],
          fallback: _asDouble(financeToday['expense']),
        ),
        'remaining': _asDouble(financeStats['balance']),
      },
      'course': {
        'title': _asString(
          nextCourse['courseName'] ?? nextCourse['course_name'],
        ),
        'time': _asString(
          nextCourse['startTime'] ?? nextCourse['start_time'],
        ),
        'location': _asString(nextCourse['classroom']),
        'weekday': _weekdayLabel(
          _asInt(nextCourse['dayOfWeek'] ?? nextCourse['day_of_week']),
        ),
        'total': _asInt(courseSummary['count']),
      },
    };
  }

  Map<String, dynamic> _buildFeedPreview(List<Map<String, dynamic>> orders) {
    // 情侣厨房订单：优先展示进行中的（待接单/烹饪中），否则展示最近一单
    final active = orders.firstWhere(
      (item) => !const ['done', 'cancelled'].contains(
        _asString(item['status']).toLowerCase(),
      ),
      orElse: () => orders.isNotEmpty ? orders.first : <String, dynamic>{},
    );
    final status = _asString(active['status'], fallback: '');

    String title = '今晚想吃什么';
    final items = active['items'];
    if (items is List && items.isNotEmpty) {
      final first = _mapFrom(items.first);
      final name = _asString(first['name']);
      if (name.isNotEmpty) {
        title = items.length > 1 ? '$name 等 ${items.length} 道菜' : name;
      }
    }

    return {
      'title': title,
      'shop': '情侣厨房',
      'statusLabel': _feedingStatusLabel(status),
      'price': _asDouble(active['total_price'], fallback: 0),
      'operator': '♥',
    };
  }

  List<Map<String, dynamic>> _rawTodos = const [];

  /// 首页待办圆圈直接切换完成状态（乐观更新 + 失败回滚）
  Future<void> toggleTodo(int id, {required bool complete}) async {
    final raw =
        _rawTodos.map((t) => Map<String, dynamic>.from(t)).toList();
    var touched = false;
    for (final t in raw) {
      if ((t['id'] as num?)?.toInt() == id) {
        t['completed'] = complete ? 1 : 0;
        touched = true;
      }
    }
    if (!touched) return;
    _rawTodos = raw;
    final todayMap = today;
    if (todayMap != null) {
      final todoNode = _mapFrom(todayMap['todo']);
      if (todoNode.isNotEmpty) {
        final active =
            _rawTodos.where((t) => t['completed'] != true && t['completed'] != 1).length;
        todoNode['active'] = active;
        todayMap['todo'] = {...todoNode, 'items': _buildTodoItems(_rawTodos)};
      }
    }
    notifyListeners();
    try {
      await _api.toggleTodo(id);
    } catch (_) {
      final rolled =
          _rawTodos.map((t) => Map<String, dynamic>.from(t)).toList();
      for (final t in rolled) {
        if ((t['id'] as num?)?.toInt() == id) {
          t['completed'] = complete ? 0 : 1;
        }
      }
      _rawTodos = rolled;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _buildTodoItems(List<Map<String, dynamic>> todos) {
    final items = todos
        .where((item) => item['completed'] != true && item['completed'] != 1)
        .take(2)
        .map(
          (item) => {
            'id': _asInt(item['id']),
            'title': _asString(item['title']),
            'dueDate': _asString(item['due_date'] ?? item['dueDate']),
          },
        )
        .where((item) => _asString(item['title']).isNotEmpty)
        .toList(growable: false);

    if (items.isNotEmpty) return items;

    return const [
      {'title': '\u63d0\u9192\u5979\u591a\u559d\u6c34', 'dueDate': ''},
      {'title': '\u7761\u524d\u8bb2\u6545\u4e8b', 'dueDate': '22:00'},
    ];
  }

  Map<String, dynamic> _buildTravelPreview({
    required List<Map<String, dynamic>> travelTrips,
    required List<Map<String, dynamic>> travelRoutes,
    required List<Map<String, dynamic>> travelSpots,
  }) {
    final trip = travelTrips.isNotEmpty ? travelTrips.first : <String, dynamic>{};
    final route =
        travelRoutes.isNotEmpty ? travelRoutes.first : <String, dynamic>{};
    final validSpots = travelSpots
        .where((item) => _asString(item['name']).isNotEmpty)
        .toList(growable: false);
    final visitedCount = validSpots
        .where((item) => _asString(item['status']) == 'visited')
        .length;
    final totalCount = validSpots.length;

    final city = _asString(
      trip['title'] ??
          trip['name'] ??
          route['title'] ??
          route['city'] ??
          (validSpots.isNotEmpty ? validSpots.first['city'] : null),
      fallback: '\u4e0b\u4e00\u6b21\u65c5\u884c',
    );

    final subtitle = _asString(
      trip['description'] ?? route['description'],
      fallback: totalCount > 0
          ? '\u5df2\u7ecf\u6536\u85cf\u4e86 $totalCount \u4e2a\u5730\u70b9\uff0c\u968f\u65f6\u53ef\u4ee5\u5f00\u59cb\u5b89\u6392\u884c\u7a0b'
          : '\u628a\u60f3\u53bb\u7684\u5730\u65b9\u4e32\u6210\u4e00\u5f20\u8def\u7ebf\u7968\u6839',
    );

    final start = _formatTicketDate(
      _asString(trip['startDate'] ?? trip['start_date']),
      fallback: '05.20',
    );
    final end = _formatTicketDate(
      _asString(trip['endDate'] ?? trip['end_date']),
      fallback: '05.24',
    );
    final progress = totalCount > 0
        ? '\u5df2\u89c4\u5212 $visitedCount/$totalCount'
        : '\u8def\u7ebf\u5f85\u5b8c\u5584';

    return {
      'title': '\u65c5\u884c\u8ba1\u5212',
      'city': city,
      'subtitle': subtitle,
      'startDate': start,
      'endDate': end,
      'duration': _buildDurationText(
        _asString(trip['startDate'] ?? trip['start_date']),
        _asString(trip['endDate'] ?? trip['end_date']),
      ),
      'progress': progress,
      'people': 2,
    };
  }

  Map<String, dynamic> _buildMemoryViewModel(Map<String, dynamic> raw) {
    return {
      ...raw,
      'title': _asString(raw['title']),
      'subtitle': _asString(raw['subtitle'] ?? raw['description']),
      'eventDate': _asString(
        raw['eventDate'] ?? raw['event_date'] ?? raw['date'],
      ),
      'location': _asString(raw['location']),
    };
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    final data = _extractData(response);
    if (data is List) {
      return data.map((item) => _mapFrom(item)).toList(growable: false);
    }
    if (data is Map) {
      final list = data['list'];
      if (list is List) {
        return list.map((item) => _mapFrom(item)).toList(growable: false);
      }
    }
    return const [];
  }

  Map<String, dynamic> _extractDataMap(dynamic response) {
    return _mapFrom(_extractData(response));
  }

  dynamic _extractData(dynamic response) {
    try {
      return response?.data?['data'];
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _mapFrom(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, data) => MapEntry(key.toString(), data),
      );
    }
    return const {};
  }

  String _feedingStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return '\u5f85\u63a5\u5355';
      case 'pending':
        return '\u5f85\u63a5\u5355';
      case 'accepted':
        return '\u70f9\u996a\u4e2d';
      case 'preparing':
        return '\u51c6\u5907\u4e2d';
      case 'delivering':
        return '\u914d\u9001\u4e2d';
      case 'done':
      case 'completed':
        return '\u5df2\u5f00\u996d';
      case 'cancelled':
        return '\u5df2\u53d6\u6d88';
      default:
        return '\u8fd8\u6ca1\u70b9\u5355';
    }
  }

  String _weekdayLabel(int weekday) {
    const labels = {
      1: '\u5468\u4e00',
      2: '\u5468\u4e8c',
      3: '\u5468\u4e09',
      4: '\u5468\u56db',
      5: '\u5468\u4e94',
      6: '\u5468\u516d',
      7: '\u5468\u65e5',
    };
    return labels[weekday] ?? '';
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  String _buildDurationText(String start, String end) {
    if (start.length >= 10 && end.length >= 10) {
      final startDate = DateTime.tryParse(start);
      final endDate = DateTime.tryParse(end);
      if (startDate != null && endDate != null && !endDate.isBefore(startDate)) {
        final days = endDate.difference(startDate).inDays + 1;
        final nights = days > 0 ? days - 1 : 0;
        return '$days \u5929 $nights \u665a';
      }
    }
    return '\u5f85\u5b9a';
  }

  String _formatTicketDate(String value, {required String fallback}) {
    if (value.length >= 10) {
      return value.substring(5, 10).replaceAll('-', '.');
    }
    return fallback;
  }

  String _asString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _friendlyErrorMessage(Object err, {required String fallback}) {
    final text = err.toString();
    if (text.contains('DioException') ||
        text.contains('Connection closed before full header was received') ||
        text.contains('connection error') ||
        text.contains('HttpException')) {
      return '\u7f51\u7edc\u6709\u70b9\u4e0d\u7a33\u5b9a\uff0c\u521a\u521a\u6709\u4e00\u90e8\u5206\u5185\u5bb9\u6ca1\u52a0\u8f7d\u51fa\u6765';
    }
    return fallback;
  }
}
