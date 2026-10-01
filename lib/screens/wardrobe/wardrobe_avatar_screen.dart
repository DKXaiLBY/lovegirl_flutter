import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/wardrobe.dart';
import '../../providers/wardrobe_provider.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/parallax_avatar.dart';
import 'widgets/wardrobe_widgets.dart';

/// P12 我的数字形象（M2a，MIROIR 化双 Tab）：
/// 照片库=原图管理（上传/抠图/设默认/删除）；数字形象=抠图成果（进换装白板）
class WardrobeAvatarScreen extends StatefulWidget {
  const WardrobeAvatarScreen({super.key});

  @override
  State<WardrobeAvatarScreen> createState() => _WardrobeAvatarScreenState();
}

class _WardrobeAvatarScreenState extends State<WardrobeAvatarScreen>
    with SingleTickerProviderStateMixin {
  int? _cutoutingId;
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<WardrobeProvider>();
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('我的数字形象',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LovePaper(
              padding: const EdgeInsets.all(14),
              radius: 16,
              child: Row(
                children: [
                  const LoveStickerIcon(icon: Icons.person_outline_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '上传一张清晰的全身照，抠成透明人形，就能在换装白板给自己"穿衣服"啦。建议纯色背景、露出全身。',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: context.lgTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: LovePaper(
              padding: const EdgeInsets.all(4),
              radius: 14,
              elevated: false,
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: context.lgInk,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: context.lgTextSecondary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                tabs: const [Tab(text: '照片库'), Tab(text: '数字形象')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_photosTab(p), _cutoutsTab(p)],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Tab1 照片库：原图管理 ----------
  Widget _photosTab(WardrobeProvider p) {
    final avatars = p.avatars;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (avatars.isEmpty) ...[
          const SizedBox(height: 60),
          EmptyState(
            icon: Icons.person_add_alt_1_rounded,
            illustration: kWardrobeEmptyIllus,
            title: '还没有数字形象',
            subtitle: '传一张全身照，开始你的电子衣娃',
          ),
          const SizedBox(height: 12),
        ],
        if (avatars.any((e) => e.cutoutUrl != null))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Center(
              child: Text('左右拖动有抠图的形象试试，有立体感',
                  style: TextStyle(
                      fontSize: 11.5, color: context.lgTextMuted)),
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
          ),
          itemCount: avatars.length,
          itemBuilder: (_, i) => _avatarCard(p, avatars[i]),
        ),
        const SizedBox(height: 16),
        LovePrimaryButton(
          text: '上传全身照',
          icon: Icons.add_a_photo_rounded,
          onPressed: _pick,
        ),
      ],
    );
  }

  // ---------- Tab2 数字形象：抠图成果 ----------
  Widget _cutoutsTab(WardrobeProvider p) {
    final withCutout = p.avatars.where((a) => a.cutoutUrl != null).toList();
    if (withCutout.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 32),
        children: [
          EmptyState(
            icon: Icons.auto_fix_high_rounded,
            illustration: kOutfitEmptyIllus,
            title: '还没有抠图形象',
            subtitle: '去「照片库」上传并抠图，这里就会出现透明人形',
          ),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: withCutout.length,
      itemBuilder: (_, i) {
        final a = withCutout[i];
        return LovePaper(
          padding: EdgeInsets.zero,
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: context.lgPrimarySoft,
                  padding: const EdgeInsets.all(8),
                  child: WnThumb(a.cutoutUrl, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  a.isDefault ? '默认形象 · 用于换装白板' : '透明人形 · 可用于换装白板',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 10.5, color: context.lgTextSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- 卡片与动作 ----------
  Widget _avatarCard(WardrobeProvider p, WardrobeAvatar a) {
    final cutouting = _cutoutingId == a.id;
    return LovePaper(
      padding: EdgeInsets.zero,
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 照片库显示原图；已抠图的卡叠加视差（背景层+人像层），无抠图回退单层
                  if (a.cutoutUrl != null)
                    ParallaxAvatar(
                      imageUrl:
                          wnImgUrl(a.imageUrl, baseUrl: AppConstants.baseUrl),
                      cutoutUrl:
                          wnImgUrl(a.cutoutUrl, baseUrl: AppConstants.baseUrl),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    )
                  else
                    WnThumb(a.imageUrl),
                  if (a.cutoutUrl != null)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('已抠图',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ),
                  if (a.isDefault)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.lgInk,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('默认',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: cutouting
                ? const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _op(Icons.photo_camera_rounded, a.cutoutUrl == null ? '抠图' : '重抠',
                          () => _cutout(p, a)),
                      if (!a.isDefault)
                        _op(Icons.star_border_rounded, '设默认',
                            () => _setDefault(p, a)),
                      _op(Icons.delete_outline_rounded, '删除',
                          () => _delete(p, a)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _op(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: context.lgTextSecondary),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: context.lgTextSecondary)),
        ],
      ),
    );
  }

  Future<void> _pick() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (picked == null || !mounted) return;
    final p = context.read<WardrobeProvider>();
    final err = await p.addAvatar(picked.path);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    // 上传成功自动抠图（列表头=最新加入的）
    if (p.avatars.isNotEmpty && p.bgPerson) {
      await _cutout(p, p.avatars.first);
    }
  }

  Future<void> _cutout(WardrobeProvider p, WardrobeAvatar a) async {
    // avatarId 模式：服务器直接分割已上传原图并回写 cutout（免 App 中转）
    setState(() => _cutoutingId = a.id);
    final err = await p.cutoutAvatarFromExisting(a);
    if (!mounted) return;
    setState(() => _cutoutingId = null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _setDefault(WardrobeProvider p, WardrobeAvatar a) async {
    final err = await p.setAvatarDefault(a.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _delete(WardrobeProvider p, WardrobeAvatar a) async {
    final ok = await wnConfirmDialog(context, '删除这个形象？', '删除后不可恢复');
    if (!ok) return;
    final err = await p.deleteAvatar(a.id);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}
