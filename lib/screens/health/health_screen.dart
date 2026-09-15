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
    // 仅女友角色可访问，但已在 AppShell 中处理，这里做个安全兜底
    if (!auth.isGirl) {
      return const Scaffold(
        backgroundColor: LoveGirlTheme.bgLight,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: LovePaper(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded,
                      size: 52, color: LoveGirlTheme.primary),
                  SizedBox(height: 14),
                  Text(
                    '健康页只给她看',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '这里会保护她的私密记录',
                    style:
                        TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: LovePage(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: LoveTicketCard(
                color: LoveGirlTheme.paperWarm,
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const LoveStickerIcon(
                      icon: Icons.health_and_safety_rounded,
                      color: LoveGirlTheme.primary,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '健康',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: LoveGirlTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '柔和一点，也清楚一点',
                            style: TextStyle(
                              fontSize: 13,
                              color: LoveGirlTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const LovePill(
                      text: '私密',
                      icon: Icons.lock_rounded,
                      color: LoveGirlTheme.primary,
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
