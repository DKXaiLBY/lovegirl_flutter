import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/tree_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';

/// 爱情树：两人每天各浇一次水，一起看着它长大
class LoveTreeScreen extends StatefulWidget {
  const LoveTreeScreen({super.key});

  @override
  State<LoveTreeScreen> createState() => _LoveTreeScreenState();
}

class _LoveTreeScreenState extends State<LoveTreeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sway =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<TreeProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _sway.dispose();
    super.dispose();
  }

  Future<void> _water(TreeProvider provider) async {
    final err = await provider.water();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TreeProvider>();
    final state = provider.state;

    provider.setOnStageUp((stageName) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('🎉 你们的树进入「$stageName」阶段，双方 +10 爱心豆'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    });

    return Scaffold(
      backgroundColor: context.lgBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Row(
                children: [
                  LoveIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '爱情树',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.loading && state == null
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: LoveGirlTheme.primary))
                  : RefreshIndicator(
                      color: LoveGirlTheme.primary,
                      onRefresh: () => provider.refresh(),
                      child: state == null
                          ? ListView(children: const [
                              SizedBox(height: 120),
                              EmptyState(
                                  icon: Icons.cloud_off_outlined,
                                  title: '加载失败，下拉重试'),
                            ])
                          : _TreeBody(
                              state: state,
                              watering: provider.watering,
                              sway: _sway,
                              onWater: () => _water(provider),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeBody extends StatelessWidget {
  final TreeState state;
  final bool watering;
  final Animation<double> sway;
  final VoidCallback onWater;

  const _TreeBody({
    required this.state,
    required this.watering,
    required this.sway,
    required this.onWater,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        LovePaper(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                state.stageName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.lgTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                state.hasPartner
                    ? '和 ${state.partnerName ?? 'TA'} 一起照顾它'
                    : '绑定伴侣后一起浇灌',
                style: TextStyle(
                  fontSize: 12,
                  color: context.lgTextMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 300,
                height: 300,
                child: AnimatedBuilder(
                  animation: sway,
                  builder: (_, __) => CustomPaint(
                    painter: _LoveTreePainter(
                      stage: state.stage,
                      sway: sway.value,
                      isDark: context.lgIsDark,
                    ),
                    size: const Size(300, 300),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _ProgressRow(state: state),
              const SizedBox(height: 14),
              _WaterRow(
                state: state,
                watering: watering,
                onWater: onWater,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        LoveSectionTitle(title: '成长之路'),
        ...const [
          ('一颗种子', 0, '你们把种子埋进了土里'),
          ('破土发芽', 50, '第一片新叶冒出来了'),
          ('小小树苗', 150, '风吹雨打都不怕'),
          ('亭亭小树', 300, '可以在树下乘凉了'),
          ('开花啦', 500, '满树都是花'),
          ('硕果累累', 800, '爱意结出了果实'),
        ].map((row) => _StageRow(
              name: row.$1,
              points: row.$2,
              desc: row.$3,
              reached: state.growthPoints >= row.$2,
            )),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final TreeState state;

  const _ProgressRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: state.progress,
            minHeight: 8,
            backgroundColor: context.lgSeparator,
            valueColor:
                const AlwaysStoppedAnimation(LoveGirlTheme.secondary),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          state.maxStage
              ? '已满级 · 成长值 ${state.growthPoints}'
              : '成长值 ${state.growthPoints} / ${state.nextStageAt} → ${state.nextStageName}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.lgTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _WaterRow extends StatelessWidget {
  final TreeState state;
  final bool watering;
  final VoidCallback onWater;

  const _WaterRow({
    required this.state,
    required this.watering,
    required this.onWater,
  });

  @override
  Widget build(BuildContext context) {
    final canWater = state.hasPartner && !state.myWateredToday;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _waterChip(context, '我', state.myWateredToday),
            const SizedBox(width: 10),
            _waterChip(context, state.partnerName ?? 'TA',
                state.partnerWateredToday),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: LovePrimaryButton(
            text: watering
                ? '浇灌中…'
                : state.myWateredToday
                    ? '今天浇过啦，明天再来'
                    : '为它浇一次水',
            icon: Icons.water_drop_rounded,
            onPressed: canWater && !watering ? onWater : null,
          ),
        ),
      ],
    );
  }

  Widget _waterChip(BuildContext context, String name, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: done ? LoveGirlTheme.secondarySoft : context.lgBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: done ? LoveGirlTheme.secondary : context.lgSeparator,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.water_drop_rounded : Icons.water_drop_outlined,
            size: 14,
            color: done ? LoveGirlTheme.secondary : context.lgTextMuted,
          ),
          const SizedBox(width: 5),
          Text(
            '$name${done ? ' 已浇' : ' 未浇'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: done ? LoveGirlTheme.secondary : context.lgTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final String name;
  final int points;
  final String desc;
  final bool reached;

  const _StageRow({
    required this.name,
    required this.points,
    required this.desc,
    required this.reached,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgSeparator),
      ),
      child: Row(
        children: [
          Icon(
            reached ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 20,
            color: reached ? LoveGirlTheme.secondary : context.lgTextMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: reached ? FontWeight.w800 : FontWeight.w600,
                    color: context.lgTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.lgTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$points',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: reached
                  ? LoveGirlTheme.secondary
                  : context.lgTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 树的绘制：6 个阶段，无 RNG（完全确定性），浅色/深色自适应
class _LoveTreePainter extends CustomPainter {
  final int stage;
  final double sway; // 0..1
  final bool isDark;

  _LoveTreePainter({required this.stage, required this.sway, required this.isDark});

  static const _leafColor = Color(0xFF7A9E7E);
  static const _leafLightColor = Color(0xFF9DBE9E);
  static const _trunk = Color(0xFF8D6E63);
  static const _soil = Color(0xFFD7C4B8);
  static const _blossom = Color(0xFFF2B8C6);
  static const _fruit = Color(0xFFE95B4E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundY = h * 0.82;
    final tilt = (sway - 0.5) * 0.045; // ±~2.6° 的轻摆

    // 地面
    final soil = Paint()..color = isDark ? _soil.withAlpha(120) : _soil;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w / 2, groundY + 14), width: w * 0.72, height: 46),
        soil);

    canvas.save();
    canvas.translate(w / 2, groundY);
    canvas.rotate(tilt);
    canvas.translate(-w / 2, -groundY);

    switch (stage) {
      case 0:
        _seed(canvas, w, groundY);
        break;
      case 1:
        _sprout(canvas, w, groundY);
        break;
      case 2:
        _sapling(canvas, w, groundY);
        break;
      case 3:
        _tree(canvas, w, groundY, scale: 0.8, blossoms: 0, fruits: 0);
        break;
      case 4:
        _tree(canvas, w, groundY, scale: 0.92, blossoms: 6, fruits: 0);
        break;
      default:
        _tree(canvas, w, groundY, scale: 1.0, blossoms: 4, fruits: 5);
    }

    canvas.restore();
  }

  void _seed(Canvas canvas, double w, double groundY) {
    final p = Paint()..color = _trunk;
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2, groundY + 2), width: 26, height: 34),
        p);
    final shine = Paint()..color = const Color(0xFFA1887F);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2 - 4, groundY - 6), width: 8, height: 12),
        shine);
  }

  void _leaf(Canvas canvas, Offset center, double rx, double ry, double angle) {
    final p = Paint()..color = _leafColor;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p);
    canvas.restore();
  }

  void _sprout(Canvas canvas, double w, double groundY) {
    final stem = Paint()
      ..color = _trunk
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w / 2, groundY), Offset(w / 2, groundY - 34), stem);
    _leaf(canvas, Offset(w / 2 - 16, groundY - 38), 17, 9, -0.6);
    _leaf(canvas, Offset(w / 2 + 16, groundY - 30), 17, 9, 0.6);
  }

  void _sapling(Canvas canvas, double w, double groundY) {
    final stem = Paint()
      ..color = _trunk
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w / 2, groundY), Offset(w / 2, groundY - 70), stem);
    _leaf(canvas, Offset(w / 2 - 24, groundY - 46), 22, 11, -0.7);
    _leaf(canvas, Offset(w / 2 + 24, groundY - 40), 22, 11, 0.7);
    _leaf(canvas, Offset(w / 2 - 16, groundY - 72), 19, 10, -0.5);
    _leaf(canvas, Offset(w / 2 + 18, groundY - 66), 19, 10, 0.5);
    final top = Paint()..color = _leafLightColor;
    canvas.drawCircle(Offset(w / 2, groundY - 84), 14, top);
  }

  void _tree(Canvas canvas, double w, double groundY,
      {required double scale, required int blossoms, required int fruits}) {
    final trunkH = 110 * scale;
    final trunkW = 16 * scale;

    // 树干（梯形）
    final trunkPath = Path()
      ..moveTo(w / 2 - trunkW, groundY)
      ..lineTo(w / 2 - trunkW * 0.55, groundY - trunkH)
      ..lineTo(w / 2 + trunkW * 0.55, groundY - trunkH)
      ..lineTo(w / 2 + trunkW, groundY)
      ..close();
    canvas.drawPath(trunkPath, Paint()..color = _trunk);

    // 树冠（两色圆簇）
    final cy = groundY - trunkH - 34 * scale;
    final r1 = 52 * scale;
    final r2 = 38 * scale;
    final dark = Paint()..color = _leafColor;
    final light = Paint()..color = _leafLightColor;
    canvas.drawCircle(Offset(w / 2 - r2 * 0.9, cy + 14 * scale), r2, dark);
    canvas.drawCircle(Offset(w / 2 + r2 * 0.9, cy + 14 * scale), r2, dark);
    canvas.drawCircle(Offset(w / 2, cy - 6 * scale), r1 * 0.92, dark);
    canvas.drawCircle(Offset(w / 2 - r2 * 0.5, cy - 2 * scale), r2 * 0.8, light);
    canvas.drawCircle(Offset(w / 2 + r2 * 0.45, cy + 2 * scale), r2 * 0.72, light);

    // 花
    if (blossoms > 0) {
      final bp = Paint()..color = _blossom;
      const spots = [
        Offset(-0.55, -0.35), Offset(0.5, -0.42), Offset(0.0, 0.18),
        Offset(-0.32, 0.3), Offset(0.34, 0.28), Offset(0.08, -0.66),
      ];
      for (var i = 0; i < blossoms && i < spots.length; i++) {
        canvas.drawCircle(
            Offset(w / 2 + spots[i].dx * r1, cy + spots[i].dy * r1), 6.5 * scale, bp);
      }
    }

    // 果子
    if (fruits > 0) {
      final fp = Paint()..color = _fruit;
      const spots = [
        Offset(-0.42, -0.1), Offset(0.38, -0.05), Offset(0.05, -0.35),
        Offset(-0.15, 0.32), Offset(0.45, 0.3),
      ];
      for (var i = 0; i < fruits && i < spots.length; i++) {
        canvas.drawCircle(
            Offset(w / 2 + spots[i].dx * r1, cy + spots[i].dy * r1), 7 * scale, fp);
      }
    }
  }

  @override
  bool shouldRepaint(_LoveTreePainter old) =>
      old.stage != stage ||
      old.sway != sway ||
      old.isDark != isDark;
}
