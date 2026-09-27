import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import 'widgets/wardrobe_widgets.dart';

/// P10 筛选面板【M1】：温度/类型/场合/风格/颜色/状态（在柜·退役两态）
/// 状态筛选 M1 就有——退役单品靠它可见（对抗审查 P0-1）
class WardrobeFilterSheet extends StatelessWidget {
  const WardrobeFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();
    final f = p.filter;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                Text('筛选',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.lgTextPrimary)),
                const Spacer(),
                if (!f.isDefault)
                  GestureDetector(
                    onTap: () {
                      f.reset();
                      p.applyFilter();
                    },
                    child: Text('重置',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.lgTextSecondary)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _label(context, '状态'),
                  WnChipGroup(
                    options: const ['在柜', '退役'],
                    selected: f.statuses,
                    onToggle: (o) {
                      f.statuses.contains(o)
                          ? f.statuses.remove(o)
                          : f.statuses.add(o);
                      p.applyFilter();
                    },
                  ),
                  _label(context, '温度'),
                  WnChipGroup(
                    options: WardrobeTax.temperatures,
                    selected: {if (f.temperature != null) f.temperature!},
                    onToggle: (o) {
                      f.temperature = f.temperature == o ? null : o;
                      p.applyFilter();
                    },
                  ),
                  _label(context, '类型'),
                  WnChipGroup(
                    options: WardrobeTax.categories,
                    selected: {if (f.category != null) f.category!},
                    onToggle: (o) {
                      f.category = f.category == o ? null : o;
                      p.applyFilter();
                    },
                  ),
                  _label(context, '场合'),
                  WnChipGroup(
                    options: WardrobeTax.occasions,
                    selected: f.occasions,
                    onToggle: (o) {
                      f.occasions.contains(o)
                          ? f.occasions.remove(o)
                          : f.occasions.add(o);
                      p.applyFilter();
                    },
                  ),
                  _label(context, '风格'),
                  WnChipGroup(
                    options: WardrobeTax.styles,
                    selected: f.styles,
                    onToggle: (o) {
                      f.styles.contains(o)
                          ? f.styles.remove(o)
                          : f.styles.add(o);
                      p.applyFilter();
                    },
                  ),
                  _label(context, '主色'),
                  WnChipGroup(
                    options: WardrobeTax.colors,
                    selected: {if (f.color != null) f.color!},
                    onToggle: (o) {
                      f.color = f.color == o ? null : o;
                      p.applyFilter();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: LovePrimaryButton(
                text: '应用（${p.filteredItems.length} 件）',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.lgTextSecondary)),
      );
}
