import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// 每日一问今日状态（GET /api/daily/today 的 data）
class DailyToday {
  final String date;
  final String question;
  final bool hasPartner;
  final String? partnerName;
  final String? myAnswer;
  final String? partnerAnswer;
  final bool bothAnswered;
  final int streakCurrent;
  final int streakLongest;
  final int streakTotal;

  const DailyToday({
    required this.date,
    required this.question,
    required this.hasPartner,
    this.partnerName,
    this.myAnswer,
    this.partnerAnswer,
    required this.bothAnswered,
    required this.streakCurrent,
    required this.streakLongest,
    required this.streakTotal,
  });

  /// 我答了，TA 还没答 → 等待揭晓
  bool get waitingPartner => myAnswer != null && partnerAnswer == null;

  factory DailyToday.fromJson(Map<String, dynamic> json) => DailyToday(
        date: (json['date'] ?? '').toString(),
        question: (json['question'] ?? '').toString(),
        hasPartner: json['hasPartner'] == true,
        partnerName: json['partnerName']?.toString(),
        myAnswer: json['myAnswer']?.toString(),
        partnerAnswer: json['partnerAnswer']?.toString(),
        bothAnswered: json['bothAnswered'] == true,
        streakCurrent:
            (json['streak']?['current'] as num?)?.toInt() ?? 0,
        streakLongest:
            (json['streak']?['longest'] as num?)?.toInt() ?? 0,
        streakTotal: (json['streak']?['total'] as num?)?.toInt() ?? 0,
      );
}

/// 历史条目（双方都作答的日期）
class DailyHistoryEntry {
  final String date;
  final String question;
  final String myAnswer;
  final String partnerAnswer;

  const DailyHistoryEntry({
    required this.date,
    required this.question,
    required this.myAnswer,
    required this.partnerAnswer,
  });

  factory DailyHistoryEntry.fromJson(Map<String, dynamic> json) =>
      DailyHistoryEntry(
        date: (json['date'] ?? '').toString(),
        question: (json['question'] ?? '').toString(),
        myAnswer: (json['myAnswer'] ?? '').toString(),
        partnerAnswer: (json['partnerAnswer'] ?? '').toString(),
      );
}

/// 每日一问状态
class DailyProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  DailyToday? today;
  List<DailyHistoryEntry> history = [];
  bool loading = false;
  String? error;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.getDailyToday();
      final data = res.data?['data'];
      if (data is Map) {
        today = DailyToday.fromJson(data.cast<String, dynamic>());
      }
    } catch (e) {
      error = '加载失败，下拉重试';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    try {
      final res = await _api.getDailyHistory();
      final data = res.data?['data'];
      history = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => DailyHistoryEntry.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [];
      notifyListeners();
    } catch (_) {}
  }

  /// 提交答案；成功返回 null，失败返回错误文案
  Future<String?> submitAnswer(String answer) async {
    final text = answer.trim();
    if (text.isEmpty) return '先写下一句答案吧';
    if (text.length > 500) return '答案太长了（500字以内）';
    try {
      final res = await _api.answerDailyQuestion(text);
      final data = res.data?['data'];
      if (data is Map) {
        today = DailyToday.fromJson(data.cast<String, dynamic>());
        notifyListeners();
      }
      return null;
    } catch (e) {
      final msg = extractServerMessage(e, fallback: '提交失败，再试一次');
      await refresh();
      return msg;
    }
  }
}
