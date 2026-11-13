import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart' show LoveStickerIcon;
import '../../widgets/rebuild_controls.dart';
import 'outfit_capture_screen.dart';
import 'outfit_compose_screen.dart';
import 'outfit_timeline_screen.dart';
import 'wardrobe_avatar_screen.dart';
import 'wardrobe_home_screen.dart';
import 'wardrobe_item_form_screen.dart';
import 'wardrobe_whiteboard_screen.dart';
import 'widgets/wardrobe_widgets.dart';

/// 衣柜模块壳（生活 tab 第 5 页签）：顶部分段「衣橱｜穿搭」+ 右上「+」
/// 决策 Q1/Q2：内嵌形态，不用底部双 Tab（避免与主 App 底栏叠加）
class WardrobeModuleScreen extends StatefulWidget {
  const WardrobeModuleScreen({super.key});

  @override
  State<WardrobeModuleScreen> createState() => _WardrobeModuleScreenState();
}

class _WardrobeModuleScreenState extends State<WardrobeModuleScreen> {
  int _seg = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<WardrobeProvider>();
      if (p.items.isEmpty && p.outfits.isEmpty && !p.loading) {
        p.loadAll();
      }
    });
  }

  @override
  void deactivate() {
    // 退出模块重置筛选（决策 D6）
    try {
      Provider.of<WardrobeProvider>(context, listen: false).resetOnExit();
    } catch (_) {}
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      body: RebuildPageBackground(
          child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(child: _buildSegmented()),
                  const SizedBox(width: 10),
                  _buildAddButton(),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: rebuildReduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: _seg == 0
                    ? const WardrobeHomeScreen(key: ValueKey('closet'))
                    : const OutfitTimelineScreen(key: ValueKey('outfit')),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Widget _buildSegmented() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('衣橱')),
        ButtonSegment(value: 1, label: Text('穿搭')),
      ],
      showSelectedIcon: false,
      selected: {_seg},
      onSelectionChanged: (values) => setState(() => _seg = values.single),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? context.lgPaper
                : context.lgInk),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? context.lgInk
                : context.lgPaper.withAlpha(165)),
        side: WidgetStatePropertyAll(BorderSide(color: context.lgSeparator)),
      ),
    );
  }

  Widget _buildAddButton() {
    return RebuildGlassButton(
      label: _seg == 0 ? '添加衣物或搭配' : '添加穿搭',
      icon: Icons.add,
      onPressed: _onAdd,
    );
  }

  /// 「+」行为随分段（§0 全局约定）；穿搭段加"我的数字形象"（M2a）；
  /// 换装试穿随 bgObject 能力闸显隐（W1，降级链路：无衣服抠图则无白板）
  void _onAdd() {
    final wardrobe = context.read<WardrobeProvider>();
    final options = _seg == 0
        ? [
            (Icons.checkroom_rounded, '添加单品', '/item'),
            (Icons.auto_awesome_mosaic_rounded, '创建搭配', '/compose'),
          ]
        : [
            (Icons.photo_camera_rounded, '实拍记录', '/capture'),
            (Icons.auto_awesome_mosaic_rounded, '创建搭配', '/compose'),
            if (wardrobe.bgObject)
              (Icons.dry_cleaning_rounded, '换装试穿', '/whiteboard'),
            (Icons.person_outline_rounded, '我的数字形象', '/avatar'),
          ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        // v4.0 弹层玻璃化统一口径（radiusXl 28 / 白 72% / blur 24）
        child: WnGlassSheet(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opt in options)
                ListTile(
                  leading: LoveStickerIcon(icon: opt.$1, color: context.lgInk),
                  title: Text(opt.$2,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.lgTextPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    switch (opt.$3) {
                      case '/item':
                        _push(const WardrobeItemFormScreen());
                      case '/compose':
                        _push(const OutfitComposeScreen());
                      case '/capture':
                        _push(const OutfitCaptureScreen());
                      case '/avatar':
                        _push(const WardrobeAvatarScreen());
                      case '/whiteboard':
                        _push(const WardrobeWhiteboardScreen());
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(Widget page) {
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(builder: (_) => page));
  }
}
