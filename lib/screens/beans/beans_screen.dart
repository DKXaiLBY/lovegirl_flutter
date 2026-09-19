import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/motion.dart';
import '../../widgets/lovegirl_ui.dart';

/// 爱心豆页：余额 + 每日签到（描边勾选/豆子爆散动效）+ 流水
class BeansScreen extends StatefulWidget {
  const BeansScreen({super.key});

  @override
  State<BeansScreen> createState() => _BeansScreenState();
}

class _BeansScreenState extends State<BeansScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  int _balance = 0;
  int _streak = 0;
  int _nextBonusIn = 7;
  bool _checkedIn = false;
  bool _checking = false;
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  String? _error;

  late final AnimationController _checkCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getBeanBalance(),
        _api.getBeanCheckInStatus(),
        _api.getBeanTransactions(),
      ]);
      if (!mounted) return;
      final balanceData = results[0].data?['data'];
      final statusData = results[1].data?['data'];
      final txData = results[2].data?['data'];
      setState(() {
        _balance = (balanceData is Map
                ? (balanceData['balance'] as num?)
                : null)
            ?.toInt() ??
            0;
        if (statusData is Map) {
          _checkedIn = statusData['checkedIn'] == true;
          _streak = (statusData['streak'] as num?)?.toInt() ?? 0;
          _nextBonusIn = (statusData['nextBonusIn'] as num?)?.toInt() ?? 7;
        }
        _transactions = txData is List
            ? txData.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '爱心豆加载失败，下拉重试';
      });
    }
  }

  Future<void> _checkIn() async {
    if (_checkedIn || _checking) return;
    setState(() => _checking = true);
    try {
      final res = await _api.dailyBeanCheckIn();
      final data = res.data?['data'];
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _balance = (data['balance'] as num?)?.toInt() ?? _balance + 5;
          _streak = (data['streak'] as num?)?.toInt() ?? _streak + 1;
          _checkedIn = true;
        });
      } else {
        setState(() => _checkedIn = true);
      }
      HapticFeedback.mediumImpact();
      _checkCtrl.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('签到成功，爱心豆 +5'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('签到失败，再试一次'),
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        foregroundColor: context.lgTextPrimary,
        elevation: 0,
        title: const Text('爱心豆',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      _buildBalanceCard(),
                      SizedBox(height: 14),
                      _buildCheckInCard(),
                      SizedBox(height: 14),
                      _buildSectionTitle('豆子流水'),
                      SizedBox(height: 8),
                      ..._transactions.map(_buildTxRow),
                      if (_transactions.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: Text('还没有流水，签到赚第一颗豆吧',
                                style: TextStyle(
                                    color: context.lgTextMuted,
                                    fontSize: 13)),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 44, color: context.lgTextMuted),
          SizedBox(height: 10),
          Text(_error ?? '加载失败',
              style: TextStyle(color: context.lgTextMuted)),
          SizedBox(height: 14),
          LovePrimaryButton(text: '重试', onPressed: _loadAll),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return LoveTicketCard(
      color: context.lgPaperWarm,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0D9),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFF1D4B1)),
            ),
            child: const Center(
                child: Icon(Icons.savings_rounded,
                    size: 28, color: Color(0xFFB8860B))),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前余额',
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextMuted)),
                SizedBox(height: 2),
                RollingNumber(
                  value: _balance,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('连续签到',
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted)),
              SizedBox(height: 2),
              Text('$_streak 天',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: context.lgInk)),
              SizedBox(height: 2),
              Text('再签 $_nextBonusIn 天有奖励',
                  style: TextStyle(
                      fontSize: 10, color: context.lgTextMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInCard() {
    return LoveTicketCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            // 签到状态圈：未签到显示豆子图标；签到中播放描边+勾动画；完成显示常亮勾
            SizedBox(
              width: 46,
              height: 46,
              child: AnimatedBuilder(
                animation: _checkCtrl,
                builder: (context, _) {
                  final done = _checkedIn && !_checkCtrl.isAnimating;
                  return CustomPaint(
                    painter: _CheckDrawPainter(
                      progress: _checkedIn
                          ? (done ? 1.0 : _checkCtrl.value)
                          : 0.0,
                      color: LoveGirlTheme.secondary,
                    ),
                    child: Center(
                      child: _checkedIn
                          ? (done
                              ? const Icon(Icons.check_rounded,
                                  size: 24,
                                  color: LoveGirlTheme.secondary)
                              : const SizedBox.shrink())
                          : const Icon(Icons.savings_outlined,
                              size: 22, color: Color(0xFFB8860B)),
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _checkedIn ? '今天已签到' : '每日签到',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.lgTextPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _checkedIn ? '明天再来，爱你 ♥' : '签到得 5 颗爱心豆',
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextMuted),
                  ),
                ],
              ),
            ),
            _CheckInButton(
              enabled: !_checkedIn && !_checking,
              label: _checkedIn ? '已签到' : '签到 +5',
              burst: _checkCtrl,
              onTap: _checkIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.lgTextPrimary)),
    );
  }

  Widget _buildTxRow(Map<String, dynamic> tx) {
    final amount = (tx['amount'] as num?)?.toInt() ?? 0;
    final positive = amount >= 0;
    final createdAt = (tx['created_at'] ?? '').toString();
    final dateText = createdAt.length >= 16
        ? createdAt.substring(0, 16)
        : createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.lgPaper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.lgSeparator.withAlpha(90)),
        ),
        child: Row(
          children: [
            Icon(
              positive
                  ? Icons.savings_rounded
                  : Icons.shopping_bag_outlined,
              size: 20,
              color: positive ? const Color(0xFFB8860B) : context.lgTextMuted,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (tx['title'] ?? tx['description'] ?? '爱心豆变动').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.lgTextPrimary),
                  ),
                  SizedBox(height: 2),
                  Text(dateText,
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextMuted)),
                ],
              ),
            ),
            Text(
              positive ? '+$amount' : '$amount',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: positive ? LoveGirlTheme.secondary : LoveGirlTheme.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 勾选描边动画：圆环先画完，对勾再切入（DRAW）
class _CheckDrawPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckDrawPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;

    final ringProgress = (progress / 0.6).clamp(0.0, 1.0);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * ringProgress,
        false,
        ringPaint);

    if (progress > 0.6) {
      final checkProgress = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
      final p1 = Offset(center.dx - radius * 0.45, center.dy + radius * 0.05);
      final p2 = Offset(center.dx - radius * 0.1, center.dy + radius * 0.4);
      final p3 = Offset(center.dx + radius * 0.5, center.dy - radius * 0.35);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);
      final metrics = path.computeMetrics().toList();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = color;
      var drawn = 0.0;
      for (final metric in metrics) {
        final target = metric.length * checkProgress;
        if (target <= drawn) break;
        canvas.drawPath(
            metric.extractPath(0, (target - drawn).clamp(0.0, metric.length)),
            paint);
        drawn += metric.length;
      }
    }
  }

  @override
  bool shouldRepaint(_CheckDrawPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// 签到按钮 + 金色豆子爆散（BURST）
class _CheckInButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final AnimationController burst;
  final VoidCallback onTap;

  const _CheckInButton({
    required this.enabled,
    required this.label,
    required this.burst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: enabled
                  ? context.lgInk
                  : context.lgSeparator,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: enabled
                    ? Colors.white
                    : context.lgTextMuted,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        // 豆子爆散粒子层
        AnimatedBuilder(
          animation: burst,
          builder: (context, _) {
            if (burst.value <= 0 || burst.value >= 1) {
              return const SizedBox.shrink();
            }
            return IgnorePointer(
              child: CustomPaint(
                size: const Size(120, 90),
                painter: _BeanBurstPainter(progress: burst.value),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BeanBurstPainter extends CustomPainter {
  final double progress;

  _BeanBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = const Offset(30, 45);
    final paint = Paint();
    final rng = Random(23);
    for (var i = 0; i < 14; i++) {
      final angle = -pi / 2 + (i - 6.5) * 0.28;
      final speed = 26.0 + rng.nextDouble() * 26;
      final t = Curves.easeOutCubic.transform(progress);
      final pos = origin +
          Offset(cos(angle) * speed * t * 1.6,
              sin(angle) * speed * t + 42 * t * t);
      paint.color = const Color(0xFFE7A25D)
          .withAlpha(((1 - t) * 255).toInt().clamp(0, 255));
      canvas.drawCircle(pos, 3.4 * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_BeanBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
