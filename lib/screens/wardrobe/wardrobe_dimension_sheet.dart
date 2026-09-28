import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';

/// P14 三层钻取（M2b，源自阿Fi不在案例）：维度 → 标签 → 预填现有筛选
/// 第一层=主页四维度圆片；第二层=本面板（维度下的标签列表+计数）；
/// 第三层=点标签预填 filter 后回 P1 即时过滤（不加新查询）
class WardrobeDimensionSheet extends StatelessWidget {
  final String dimension; // temperature / category / occasions / styles

  const WardrobeDimensionSheet({super.key, required this.dimension});

  static const _meta = {
    'temperature': ('适合温度', WardrobeTax.temperatures),
    'category': ('类型', WardrobeTax.categories),
    'occasions': ('场合', WardrobeTax.occasions),
    'styles': ('风格', WardrobeTax.styles),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();
    final (label, options) = _meta[dimension]!;

    int countOf(String tag) => p.items.where((it) {
          if (!p.filter.statuses.contains(it.status)) return false;
          switch (dimension) {
            case 'temperature':
              return it.temperature == tag;
            case 'category':
              return it.category == tag;
            case 'occasions':
              return it.occasions.contains(tag);
            case 'styles':
              return it.styles.contains(tag);
          }
          return false;
        }).length;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.lgCard,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.lgTextPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded,
                      size: 20, color: context.lgTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final tag in options)
                    _tagRow(context, p, tag, countOf(tag)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagRow(
      BuildContext context, WardrobeProvider p, String tag, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LovePaper(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        radius: 14,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tag,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: context.lgTextPrimary)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count 件',
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: context.lgTextMuted),
            ],
          ),
          onTap: () {
            // 预填现有筛选（重置其他维度，单选语义）
            p.filter.reset();
            switch (dimension) {
              case 'temperature':
                p.filter.temperature = tag;
              case 'category':
                p.filter.category = tag;
              case 'occasions':
                p.filter.occasions.add(tag);
              case 'styles':
                p.filter.styles.add(tag);
            }
            p.applyFilter();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

/// P1 主页四个维度圆片入口（第一层）
class WardrobeDimensionRow extends StatelessWidget {
  const WardrobeDimensionRow({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = const [
      (Icons.thermostat_rounded, '温度', 'temperature'),
      (Icons.checkroom_rounded, '类型', 'category'),
      (Icons.event_available_rounded, '场合', 'occasions'),
      (Icons.style_rounded, '风格', 'styles'),
    ];
    return Row(
      children: [
        for (final (icon, label, dim) in entries)
          Expanded(
            child: GestureDetector(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) =>
                    WardrobeDimensionSheet(dimension: dim),
              ),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: context.lgPrimarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 21, color: context.lgTextSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: context.lgTextSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
