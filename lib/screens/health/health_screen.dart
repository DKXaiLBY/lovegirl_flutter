import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'widgets/period_tracker.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // 用原始角色拦截：开发者模式切到"她的视角"也不加载她的私密数据，
    // 避免拿对方身份请求经期接口报"加载失败"
    if (!auth.isOriginalGirl) {
      return Scaffold(
        backgroundColor: context.lgBg,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: LovePaper(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded,
                      size: 52, color: context.lgInk),
                  SizedBox(height: 14),
                  Text(
                    '健康页只给她看',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '这里会保护她的私密记录',
                    style:
                        TextStyle(fontSize: 13, color: context.lgTextMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.lgBg,
      body: LovePage(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: LoveTicketCard(
                color: context.lgPaperWarm,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    LoveStickerIcon(
                      icon: Icons.health_and_safety_rounded,
                      color: context.lgInk,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '健康',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: context.lgTextPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '柔和一点，也清楚一点',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.lgTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LovePill(
                      text: '私密',
                      icon: Icons.lock_rounded,
                      color: context.lgInk,
                    ),
                  ],
                ),
              ),
            ),
            const Expanded(child: PeriodTracker()),
          ],
        ),
      ),
    );
  }
}
