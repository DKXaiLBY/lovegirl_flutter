import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';

/// 拇指之吻：双方同触屏幕同一点，重合瞬间双机震动（特批深色域页面）
class ThumbKissScreen extends StatefulWidget {
  const ThumbKissScreen({super.key});

  @override
  State<ThumbKissScreen> createState() => _ThumbKissScreenState();
}

class _ThumbKissScreenState extends State<ThumbKissScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();

  // 我与 TA 的拇指（归一化坐标 0..1；null = 未触/未上线）
  Offset? _myPos;
  bool _myTouching = false;
  Offset? _partnerPos;
  bool _partnerTouching = false;
  bool _partnerOnline = false;
  bool _hasPartner = true;
  bool _matched = false;
  int _kissCount = 0;

  Timer? _pollTimer;
  Timer? _heartbeatTimer;
  DateTime _lastPost = DateTime.fromMillisecondsSinceEpoch(0);
  bool _posting = false;
  bool _left = false;

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 400), (_) => _poll());
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) => _heartbeat());
    _poll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _heartbeatTimer?.cancel();
    _burst.dispose();
    _exitRoom();
    super.dispose();
  }

  Future<void> _exitRoom() async {
    _left = true;
    try {
      await _api.leaveKissRoom();
    } catch (_) {}
  }

  Future<void> _poll() async {
    if (_left) return;
    try {
      final res = await _api.getKissState();
      final d = res.data?['data'];
      if (d is Map) {
        setState(() {
          _hasPartner = d['hasPartner'] == true;
          _partnerOnline = d['partnerOnline'] == true;
          _partnerTouching = d['partnerTouching'] == true;
          final px = (d['partnerX'] as num?)?.toDouble();
          final py = (d['partnerY'] as num?)?.toDouble();
          _partnerPos = (px != null && py != null) ? Offset(px, py) : null;
          final just = d['justMatched'] == true;
          _matched = d['matched'] == true;
          if (just) _onKiss();
        });
      }
    } catch (_) {}
  }

  void _onKiss() {
    _kissCount++;
    HapticFeedback.heavyImpact();
    _burst.forward(from: 0);
  }

  Future<void> _heartbeat() async {
    if (_left) return;
    // 不触摸也要维持在线，让 TA 看到我在
    try {
      await _api.sendKissPosition(
          _myPos?.dx ?? 0.5, _myPos?.dy ?? 0.5, _myTouching);
    } catch (_) {}
  }

  Future<void> _postPosition(Offset normalized) async {
    if (_left || _posting) return;
    final now = DateTime.now();
    if (now.difference(_lastPost).inMilliseconds < 220) return;
    _lastPost = now;
    _posting = true;
    try {
      await _api.sendKissPosition(normalized.dx, normalized.dy, _myTouching);
    } catch (_) {} finally {
      _posting = false;
    }
  }

  Offset _normalize(Offset local, Size size) => Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _exitRoom();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  setState(() {
                    _myTouching = true;
                    _myPos = _normalize(d.localPosition, size);
                  });
                  _postPosition(_myPos!);
                },
                onPanUpdate: (d) {
                  setState(() => _myPos = _normalize(d.localPosition, size));
                  _postPosition(_myPos!);
                },
                onPanEnd: (_) {
                  setState(() => _myTouching = false);
                  _postPosition(_myPos ?? const Offset(0.5, 0.5));
                },
                child: Stack(
                  children: [
                    // 顶部栏
                    Positioned(
                      top: 8,
                      left: 18,
                      right: 18,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white70),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '拇指之吻',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          if (_kissCount > 0)
                            Row(
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    size: 15, color: Color(0xFFF2B8C6)),
                                const SizedBox(width: 4),
                                Text('$_kissCount',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    )),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // TA 的光点
                    if (_partnerPos != null && _partnerTouching)
                      Positioned(
                        left: _partnerPos!.dx * size.width - 26,
                        top: _partnerPos!.dy * size.height - 26,
                        child: const _GlowDot(
                          color: Color(0xFF6FD9F5),
                          label: 'TA',
                        ),
                      ),
                    // 我的光点
                    if (_myPos != null && _myTouching)
                      Positioned(
                        left: _myPos!.dx * size.width - 26,
                        top: _myPos!.dy * size.height - 26,
                        child: const _GlowDot(
                          color: Color(0xFFE7A25D),
                          label: '我',
                        ),
                      ),
                    // 命中瞬间的心心爆发
                    AnimatedBuilder(
                      animation: _burst,
                      builder: (_, __) {
                        if (_burst.value == 0) return const SizedBox.shrink();
                        return Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Opacity(
                                opacity: (1 - _burst.value).clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 0.6 + _burst.value * 1.4,
                                  child: const Icon(Icons.favorite_rounded,
                                      size: 120, color: Color(0xFFF2B8C6)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // 底部提示
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 40,
                      child: Column(
                        children: [
                          if (!_hasPartner)
                            const _HintText('先绑定伴侣，就能一起玩拇指之吻了')
                          else if (!_partnerOnline)
                            const _HintText('TA 还没进来，等 TA 一起把拇指放上来')
                          else if (_matched)
                            const _HintText('吻到了 💕 再来一次')
                          else
                            const _HintText('把拇指放在屏幕上，慢慢靠近 TA 的光点'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GlowDot extends StatelessWidget {
  final Color color;
  final String label;

  const _GlowDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(60),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(140),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color.withAlpha(230),
        ),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  final String text;

  const _HintText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          height: 1.6,
          color: Colors.white60,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
