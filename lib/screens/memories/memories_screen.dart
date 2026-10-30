import 'package:flutter/material.dart';

import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../features/creations/creation_gallery.dart';
import '../cooking/cooking_log_screen.dart';
import '../mood/mood_screen.dart';
import '../photo/photo_screen.dart';
import '../report/annual_report_screen.dart';
import '../report/monthly_report_screen.dart';
import '../timeline/timeline_screen.dart';

class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String, Widget)>[
      (Icons.photo_library_outlined, '相册', '照片与拍立得', const PhotoScreen()),
      (Icons.confirmation_number_outlined, '票根', '制作与收藏旅行纪念', const CreationGallery(kind: 'ticket')),
      (Icons.history_rounded, '时光轴', '一起经历的事', TimelineScreen()),
      (Icons.mood_rounded, '心情', '记录与回看每天的感受', const MoodScreen()),
      (Icons.restaurant_rounded, '美食手账', '两个人的餐桌照片', const CookingLogScreen()),
    ];
    return Scaffold(
      backgroundColor: context.lgBg,
      body: LovePage(
        child: ListView(
          children: [
            const LoveSectionTitle(title: '回忆'),
            const SizedBox(height: 16),
            LovePaper(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final entry in entries) ...[
                    LoveMenuRow(
                      icon: entry.$1,
                      title: entry.$2,
                      value: entry.$3,
                      color: context.lgInk,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => entry.$4),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  LoveMenuRow(
                    icon: Icons.auto_stories_outlined,
                    title: '回忆报告',
                    value: '按月或按年回看',
                    color: context.lgInk,
                    onTap: () => _openReports(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReports(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in <(String, Widget)>[
              ('月度小报', const MonthlyReportScreen()),
              ('年度报告', const AnnualReportScreen()),
            ])
              ListTile(
                title: Text(entry.$1),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => entry.$2),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
