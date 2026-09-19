import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/services/log_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

int? _toIntOrNull(dynamic v) {
  if (v is int) return v;
  if (v == null) return null;
  return int.tryParse(v.toString());
}

enum PeriodStatus { menstrual, safe, ovulation, premenstrual, unknown }

extension PeriodStatusExt on PeriodStatus {
  String get label {
    switch (this) {
      case PeriodStatus.menstrual: return '经期中';
      case PeriodStatus.safe: return '安全期';
      case PeriodStatus.ovulation: return '易孕期';
      case PeriodStatus.premenstrual: return '经前期';
      case PeriodStatus.unknown: return '暂无数据';
    }
  }
  String get subLabel {
    switch (this) {
      case PeriodStatus.menstrual: return '注意保暖，多喝热水';
      case PeriodStatus.safe: return '放松享受每一天';
      case PeriodStatus.ovulation: return '怀孕几率较高';
      case PeriodStatus.premenstrual: return '经期即将到来';
      case PeriodStatus.unknown: return '记录经期开始获取预测';
    }
  }
  IconData get icon {
    switch (this) {
      case PeriodStatus.menstrual: return Icons.water_drop_rounded;
      case PeriodStatus.safe: return Icons.shield_rounded;
      case PeriodStatus.ovulation: return Icons.auto_awesome_rounded;
      case PeriodStatus.premenstrual: return Icons.notifications_rounded;
      case PeriodStatus.unknown: return Icons.help_outline_rounded;
    }
  }
  Color color(BuildContext context) {
    switch (this) {
      case PeriodStatus.menstrual: return context.lgInk;
      case PeriodStatus.safe: return const Color(0xFF4CAF50);
      case PeriodStatus.ovulation: return const Color(0xFFE040FB);
      case PeriodStatus.premenstrual: return const Color(0xFFFF9800);
      case PeriodStatus.unknown: return context.lgTextMuted;
    }
  }
}

class PeriodRecord {
  final int? id;
  final DateTime startDate;
  final DateTime? endDate;
  final int? cycleLength;
  final int? periodLength;
  PeriodRecord({this.id, required this.startDate, this.endDate, this.cycleLength, this.periodLength});
  factory PeriodRecord.fromJson(Map<String, dynamic> json) {
    return PeriodRecord(
      id: json['id'] as int?,
      startDate: DateTime.parse((json['startDate'] ?? json['start_date'] ?? '').toString()),
      endDate: _parseDateOrNull(json['endDate'] ?? json['end_date']),
      cycleLength: (json['cycleDays'] ?? json['cycle_length']) as int?,
      periodLength: (json['durationDays'] ?? json['period_length']) as int?,
    );
  }
  static DateTime? _parseDateOrNull(dynamic val) {
    if (val == null || val.toString().isEmpty) return null;
    return DateTime.tryParse(val.toString());
  }
}

class PeriodAnalysis {
  final double averageCycle;
  final double averagePeriod;
  final int totalPeriods;
  final String regularity;
  final String? lastPeriod;
  PeriodAnalysis({required this.averageCycle, required this.averagePeriod, required this.totalPeriods, required this.regularity, this.lastPeriod});
  factory PeriodAnalysis.fromJson(Map<String, dynamic> json) {
    return PeriodAnalysis(
      averageCycle: (_numVal(json['avgCycle'] ?? json['average_cycle']) ?? 28).toDouble(),
      averagePeriod: (_numVal(json['avgDuration'] ?? json['average_period']) ?? 5).toDouble(),
      totalPeriods: (_numVal(json['cycleCount'] ?? json['total_periods']) ?? 0).toInt(),
      regularity: (json['regularity'] ?? 'unknown').toString(),
      lastPeriod: json['lastPeriod']?.toString(),
    );
  }
  static num? _numVal(dynamic v) {
    if (v is num) return v;
    if (v == null) return null;
    return num.tryParse(v.toString());
  }
  String get regularityLabel {
    switch (regularity) { case 'regular': return '周期规律'; case 'irregular': return '不太规律'; default: return '数据不足'; }
  }
  Color regularityColor(BuildContext context) {
    switch (regularity) { case 'regular': return const Color(0xFF4CAF50); case 'irregular': return const Color(0xFFFF9800); default: return context.lgTextMuted; }
  }
}

class PeriodTracker extends StatefulWidget {
  const PeriodTracker({super.key});
  @override
  State<PeriodTracker> createState() => _PeriodTrackerState();
}

class _PeriodTrackerState extends State<PeriodTracker> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  PeriodStatus _currentStatus = PeriodStatus.unknown;
  List<PeriodRecord> _periods = [];
  PeriodAnalysis? _analysis;
  int? _daysUntilNext;
  int? _cycleDay;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([_api.getPeriodStatus(), _api.getPeriods(), _api.getPeriodAnalysis()]);
      final s = results[0].data?['data'];
      if (s is Map) {
        // 服务器返回 phase.phaseKey 或 status
        final phase = s['phase'] as Map<String, dynamic>?;
        final statusStr = (phase?['phaseKey'] ?? s['status'] ?? 'unknown').toString();
        switch (statusStr) {
          case 'menstrual': _currentStatus = PeriodStatus.menstrual;
          case 'safe': _currentStatus = PeriodStatus.safe;
          case 'ovulation': _currentStatus = PeriodStatus.ovulation;
          case 'premenstrual': _currentStatus = PeriodStatus.premenstrual;
          default: _currentStatus = PeriodStatus.unknown;
        }
        _daysUntilNext = _toIntOrNull(s['daysUntilNext'] ?? s['days_until_next']);
        _cycleDay = _toIntOrNull(phase?['dayInPeriod'] ?? s['cycle_day']);
      }
      final p = results[1].data?['data'];
      _periods = (p is List) ? p.map((e) => PeriodRecord.fromJson(Map<String, dynamic>.from(e))).toList() : [];
      final a = results[2].data?['data'];
      _analysis = a is Map ? PeriodAnalysis.fromJson(Map<String, dynamic>.from(a)) : null;
      LogService().info('Period', '加载完成:状态=${_currentStatus.label},记录=${_periods.length}');
    } catch (e) {
      _error = '加载失败';
      LogService().error('Period', '加载失败: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _togglePeriod() async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);
    try {
      final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_currentStatus == PeriodStatus.menstrual) {
        await _api.savePeriod({'end_date': now});
        LogService().userAction('经期:标记结束');
      } else {
        await _api.savePeriod({'start_date': now});
        LogService().userAction('经期:标记开始');
      }
      await _loadData();
    } catch (e) {
      LogService().error('Period', '操作失败: $e');
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: context.lgInk));
    if (_error != null) return _buildError();
    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.lgInk,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        _buildStatusRing(),
        SizedBox(height: 16),
        _buildActionButton(),
        SizedBox(height: 20),
        if (_analysis != null) _buildAnalysis(),
        SizedBox(height: 20),
        if (_periods.isNotEmpty) _buildHistory(),
      ]),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.cloud_off, size: 48, color: context.lgTextMuted),
    SizedBox(height: 12),
    Text(_error!, style: TextStyle(color: context.lgTextSecondary)),
    SizedBox(height: 16),
    TextButton.icon(
      onPressed: _loadData,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('点击重试'),
      style: TextButton.styleFrom(foregroundColor: context.lgInk),
    ),
  ]));

  Widget _buildStatusRing() {
    final color = _currentStatus.color(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: context.lgCard,
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
        boxShadow: [BoxShadow(color: color.withAlpha(20), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          SizedBox(width: 140, height: 140, child: CircularProgressIndicator(value: _cycleDay != null ? (_cycleDay! / 28).clamp(0.0, 1.0) : 0, strokeWidth: 8, backgroundColor: color.withAlpha(20), valueColor: AlwaysStoppedAnimation(color))),
          Column(children: [
            Icon(_currentStatus.icon, size: 36, color: color),
            SizedBox(height: 4),
            Text(_currentStatus.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ]),
        ]),
        SizedBox(height: 12),
        Text(_currentStatus.subLabel, style: TextStyle(fontSize: 13, color: context.lgTextMuted)),
        if (_cycleDay != null) ...[
          SizedBox(height: 6),
          Text('周期第 $_cycleDay 天${_daysUntilNext != null ? ' · 距下次 $_daysUntilNext 天' : ''}', style: TextStyle(fontSize: 12, color: context.lgTextSecondary)),
        ],
      ]),
    );
  }

  Widget _buildActionButton() {
    final isOnPeriod = _currentStatus == PeriodStatus.menstrual;
    return SizedBox(width: double.infinity, height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _togglePeriod,
        icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isOnPeriod ? Icons.stop_circle_outlined : Icons.play_circle_outline),
        label: Text(isOnPeriod ? '标记经期结束' : '标记经期开始', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(backgroundColor: LoveGirlTheme.pink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.borderRadius))),
      ),
    );
  }

  Widget _buildAnalysis() {
    final a = _analysis!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: context.lgCard, borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.analytics_outlined, size: 18, color: context.lgInk),
          SizedBox(width: 8),
          Text('周期分析', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: a.regularityColor(context).withAlpha(25), borderRadius: BorderRadius.circular(8)), child: Text(a.regularityLabel, style: TextStyle(fontSize: 12, color: a.regularityColor(context), fontWeight: FontWeight.w500))),
        ]),
        SizedBox(height: 16),
        Row(children: [
          _buildDataItem('平均周期', '${a.averageCycle.toStringAsFixed(0)}天', context.lgInk),
          _d(),
          _buildDataItem('平均经期', '${a.averagePeriod.toStringAsFixed(0)}天', context.lgInk),
          _d(),
          _buildDataItem('记录次数', '${a.totalPeriods}次', context.lgInk),
        ]),
      ]),
    );
  }

  Widget _buildDataItem(String label, String value, Color color) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 12, color: context.lgTextSecondary)),
  ]));
  Widget _d() => Container(width: 1, height: 36, color: context.lgTextMuted.withAlpha(30));

  Widget _buildHistory() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.history, size: 18, color: context.lgTextPrimary),
        SizedBox(width: 8),
        Text('近期记录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Spacer(),
        Text('共 ${_periods.length} 次', style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
      ]),
      const SizedBox(height: 12),
      ..._periods.take(5).map((r) => _buildHistoryItem(r)),
    ]);
  }

  Widget _buildHistoryItem(PeriodRecord r) {
    final df = DateFormat('M月d日');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: context.lgCard, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Container(width: 3, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: LinearGradient(colors: [context.lgInk, LoveGirlTheme.pinkLight]))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${df.format(r.startDate)} - ${r.endDate != null ? df.format(r.endDate!) : '进行中'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          if (r.periodLength != null || r.cycleLength != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              if (r.periodLength != null) _tag('经期 ${r.periodLength}天'),
              if (r.periodLength != null && r.cycleLength != null) const SizedBox(width: 6),
              if (r.cycleLength != null) _tag('周期 ${r.cycleLength}天'),
            ]),
          ],
        ])),
        if (r.endDate == null) Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: context.lgInk.withAlpha(25), borderRadius: BorderRadius.circular(14)), child: Text('进行中', style: TextStyle(fontSize: 12, color: context.lgInk, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _tag(String text) => Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: context.lgInk.withAlpha(12), borderRadius: BorderRadius.circular(8)), child: Text(text, style: TextStyle(fontSize: 10, color: context.lgInk)));
}
