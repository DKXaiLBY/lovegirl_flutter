import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/wardrobe_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import 'outfit_capture_screen.dart';
import 'outfit_compose_screen.dart';
import 'outfit_timeline_screen.dart';
import 'wardrobe_home_screen.dart';
import 'wardrobe_item_form_screen.dart';

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
      body: SafeArea(
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
                duration: const Duration(milliseconds: 180),
                child: _seg == 0
                    ? const WardrobeHomeScreen(key: ValueKey('closet'))
                    : const OutfitTimelineScreen(key: ValueKey('outfit')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmented() {
    return LovePaper(
      padding: const EdgeInsets.all(4),
      radius: 16,
      elevated: false,
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _seg = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _seg == i ? context.lgInk : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    i == 0 ? '衣橱' : '穿搭',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _seg == i ? Colors.white : context.lgTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _onAdd,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.lgInk,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  /// 「+」行为随分段（§0 全局约定）
  void _onAdd() {
    final options = _seg == 0
        ? [
            (Icons.checkroom_rounded, '添加单品', '/item'),
            (Icons.auto_awesome_mosaic_rounded, '创建搭配', '/compose'),
          ]
        : [
            (Icons.photo_camera_rounded, '实拍记录', '/capture'),
            (Icons.auto_awesome_mosaic_rounded, '创建搭配', '/compose'),
          ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: LovePaper(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          radius: 20,
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
