import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// 爱情树状态（GET /api/tree 的 data）
class TreeState {
  final bool hasPartner;
  final String? partnerName;
  final int growthPoints;
  final int stage;
  final String stageName;
  final int? nextStageAt;
  final String? nextStageName;
  final bool myWateredToday;
  final bool partnerWateredToday;

  const TreeState({
    required this.hasPartner,
    this.partnerName,
    required this.growthPoints,
    required this.stage,
    required this.stageName,
    this.nextStageAt,
    this.nextStageName,
    required this.myWateredToday,
    required this.partnerWateredToday,
  });

  bool get maxStage => nextStageAt == null;

  /// 到下一阶段的进度 0.0 ~ 1.0（满级为 1.0）
  double get progress {
    final next = nextStageAt;
    if (next == null) return 1;
    const stageStarts = <int, int>{0: 0, 1: 50, 2: 150, 3: 300, 4: 500, 5: 800};
    final start = stageStarts[stage] ?? 0;
    return ((growthPoints - start) / (next - start)).clamp(0.0, 1.0);
  }

  factory TreeState.fromJson(Map<String, dynamic> json) => TreeState(
        hasPartner: json['hasPartner'] == true,
        partnerName: json['partnerName']?.toString(),
        growthPoints: (json['growthPoints'] as num?)?.toInt() ?? 0,
        stage: (json['stage'] as num?)?.toInt() ?? 0,
        stageName: (json['stageName'] ?? '').toString(),
        nextStageAt: (json['nextStageAt'] as num?)?.toInt(),
        nextStageName: json['nextStageName']?.toString(),
        myWateredToday: json['myWateredToday'] == true,
        partnerWateredToday: json['partnerWateredToday'] == true,
      );
}

/// 爱情树状态管理
class TreeProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  TreeState? state;
  bool loading = false;
  bool watering = false;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final res = await _api.getLoveTree();
      final data = res.data?['data'];
      if (data is Map) {
        state = TreeState.fromJson(data.cast<String, dynamic>());
      }
    } catch (_) {}
    finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 浇水；成功返回 null，失败返回错误文案。返回值 stageUp 交给 UI 播放
  Future<String?> water() async {
    if (watering) return null;
    watering = true;
    notifyListeners();
    try {
      final res = await _api.waterLoveTree();
      final data = res.data?['data'];
      if (data is Map) {
        final next = TreeState.fromJson(data.cast<String, dynamic>());
        final grew = state == null || next.stage > state!.stage;
        state = next;
        notifyListeners();
        if (grew) _onStageUp?.call(next.stageName);
      }
      return null;
    } catch (e) {
      if (e.toString().contains('409') || e.toString().contains('浇过')) {
        await refresh();
        return '今天已经浇过啦';
      }
      if (e.toString().contains('400') || e.toString().contains('绑定')) {
        return '先绑定伴侣，一起浇灌小树吧';
      }
      return '浇水失败，再试一次';
    } finally {
      watering = false;
      notifyListeners();
    }
  }

  /// 升阶回调（由 UI 注册，播放心跳动效）
  void Function(String stageName)? _onStageUp;
  void setOnStageUp(void Function(String stageName)? cb) => _onStageUp = cb;
}
