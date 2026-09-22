import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';

/// 美食手账：两个人的餐桌相册。
/// 记一道菜（照片/菜名/新做复刻/食谱/故事）→ TA 品尝打分 → 新菜可挂上点单菜单。
class CookingLogScreen extends StatefulWidget {
  const CookingLogScreen({super.key});

  @override
  State<CookingLogScreen> createState() => _CookingLogScreenState();
}

class _CookingLogScreenState extends State<CookingLogScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _gallery = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getCookingList();
      final d = res.data?['data'];
      if (d is Map) {
        _logs = _mapList(d['logs']);
        _gallery = _mapList(d['gallery']);
        _stats = d['stats'] is Map ? (d['stats'] as Map).cast<String, dynamic>() : null;
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic v) =>
      (v as List? ?? []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CreateLogSheet(),
    );
    if (created == true) _load();
  }

  Future<void> _taste(Map<String, dynamic> log) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: LoveGirlTheme.bgLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.separator,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('品尝「${log['title']}」',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('这道菜你打几星？',
                    style: TextStyle(fontSize: 12.5, color: LoveGirlTheme.textMuted)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setSheet(() => rating = i),
                        icon: Icon(
                          i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 38,
                          color: i <= rating ? LoveGirlTheme.orange : LoveGirlTheme.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: '一句话点评（选填）',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: LoveGirlTheme.separator)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: LoveGirlTheme.separator)),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: LovePrimaryButton(
                    text: '交卷',
                    icon: Icons.favorite_rounded,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _api.tasteCookingLog((log['id'] as num).toInt(), rating, commentCtrl.text.trim());
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('评分交卷，TA 会收到通知'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('提交失败，再试一次'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthNew = _stats?['monthNew'] as num? ?? 0;
    final totalNew = _stats?['newTotal'] as num? ?? 0;
    final totalAll = _stats?['total'] as num? ?? 0;

    return Scaffold(
      backgroundColor: context.lgBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: context.lgInk,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
        label: const Text('记一道',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
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
                  const Text(
                    '美食手账',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '两个人的餐桌相册：谁做的、好不好吃、背后的故事',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.lgTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // 图鉴条
            Container(
              margin: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.lgPaperWarm,
                borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
                border: Border.all(color: context.lgSeparator),
              ),
              child: _gallery.isEmpty
                  ? Row(
                      children: [
                        Icon(Icons.emoji_events_outlined,
                            size: 16, color: context.lgEmotion),
                        const SizedBox(width: 6),
                        Text(
                          '新菜图鉴还空着，做第一道新菜点亮它',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.lgTextSecondary,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.emoji_events_outlined,
                                size: 15, color: LoveGirlTheme.orange),
                            const SizedBox(width: 5),
                            Text(
                              '新菜图鉴 · 本月尝新 $monthNew 道 · 累计 $totalNew 道（共下厨 $totalAll 次）',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: LoveGirlTheme.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _gallery.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final g = _gallery[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: LoveGirlTheme.separator),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(g['emoji']?.toString() ?? '🍳',
                                        style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 4),
                                    Text(
                                      g['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: LoveGirlTheme.primary))
                  : RefreshIndicator(
                      color: LoveGirlTheme.primary,
                      onRefresh: _load,
                      child: _logs.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 100),
                              EmptyState(
                                icon: Icons.restaurant_rounded,
                                title: '餐桌相册还空着',
                                subtitle: '记下第一道菜，从今天开始收藏你们的三餐四季',
                                onRetry: _load,
                                retryText: '刷新',
                              ),
                            ])
                          : _buildGroupedList(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    final myId = context.read<AuthProvider>().userId ?? -1;
    // 按月分组
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final log in _logs) {
      final d = log['cookedAt']?.toString() ?? '';
      final key = d.length >= 7 ? d.substring(0, 7) : d;
      groups.putIfAbsent(key, () => []).add(log);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final items = groups[key]!;
        final label = '${key.substring(0, 4)}年${key.substring(5, 7)}月';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 10,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.accent.withAlpha(90),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((log) => _CookingCard(
                  log: log,
                  myId: myId,
                  onTaste: () => _taste(log),
                  onDeleted: _load,
                )),
            const SizedBox(height: 18),
          ],
        );
      },
    );
  }

}

/// 单条记录卡（拍立得风）
class _CookingCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final int myId;
  final VoidCallback onTaste;
  final VoidCallback onDeleted;

  const _CookingCard({
    required this.log,
    required this.myId,
    required this.onTaste,
    required this.onDeleted,
  });

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条记录？', style: TextStyle(fontSize: 16)),
        content: const Text('删除后不可恢复', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('删除',
                  style: TextStyle(color: LoveGirlTheme.red.withAlpha(230)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().deleteCookingLog((log['id'] as num).toInt());
      onDeleted();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final photo = log['photoUrl']?.toString();
    final isNew = log['isNew'] == true;
    final chefRating = (log['chefRating'] as num?)?.toInt() ?? 0;
    final eaterRating = (log['eaterRating'] as num?)?.toInt() ?? 0;
    final eaterComment = log['eaterComment']?.toString();
    final iAmChef = myId > 0 && (log['chefId'] as num?)?.toInt() == myId;
    final needsTaste = eaterRating == 0 && !iAmChef;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgSeparator),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null && photo.isNotEmpty)
              Stack(
                children: [
                  Image.network(
                    photo.startsWith('http')
                        ? photo
                        : '${AppConstants.baseUrl}$photo',
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  if (isNew)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: LoveGirlTheme.brandEmotion.withAlpha(230),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('新菜',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(log['emoji']?.toString() ?? '🍳',
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log['title']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (photo == null || photo.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isNew
                                ? LoveGirlTheme.brandEmotion.withAlpha(30)
                                : context.lgSeparator.withAlpha(120),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isNew ? '新菜' : '复刻',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isNew
                                  ? LoveGirlTheme.brandEmotion
                                  : context.lgTextMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(log['cookedAt']?.toString() ?? '',
                          style: TextStyle(
                              fontSize: 11.5, color: context.lgTextMuted)),
                      const SizedBox(width: 10),
                      if (chefRating > 0) ...[
                        const Icon(Icons.restaurant_rounded,
                            size: 12, color: LoveGirlTheme.textMuted),
                        const SizedBox(width: 2),
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= chefRating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 12,
                                color: LoveGirlTheme.orange,
                              ),
                          ],
                        ),
                      ],
                      if (eaterRating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.favorite_rounded,
                            size: 12, color: LoveGirlTheme.secondary),
                        const SizedBox(width: 2),
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= eaterRating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 12,
                                color: LoveGirlTheme.secondary,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if ((log['story']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      log['story'].toString(),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: context.lgTextSecondary,
                      ),
                    ),
                  ],
                  if ((log['recipe']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.lgBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.lgSeparator),
                      ),
                      child: Text(
                        log['recipe'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: context.lgTextSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (eaterComment != null && eaterComment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.secondarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'TA 说：$eaterComment',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: LoveGirlTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                  if (needsTaste) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: LovePrimaryButton(
                        text: '我尝了，去打分',
                        icon: Icons.favorite_rounded,
                        onPressed: onTaste,
                      ),
                    ),
                  ],
                  if (iAmChef) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _delete(context),
                        child: Text('删除',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: context.lgTextMuted
                                    .withAlpha(180))),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 记一道：30 秒记录流
class _CreateLogSheet extends StatefulWidget {
  const _CreateLogSheet();

  @override
  State<_CreateLogSheet> createState() => _CreateLogSheetState();
}

class _CreateLogSheetState extends State<_CreateLogSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _recipe = TextEditingController();
  final TextEditingController _story = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _emoji = '🍳';
  bool _isNew = true;
  bool _addToMenu = false;
  int _chefRating = 0;
  String? _photoUrl;
  bool _uploading = false;
  bool _sending = false;

  static const _emojiChoices = ['🍳', '🍅', '🥘', '🍰', '🍜', '🥟', '🍱', '🍵'];

  @override
  void dispose() {
    _title.dispose();
    _recipe.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final xFile = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 82);
    if (xFile == null) return;
    setState(() => _uploading = true);
    try {
      final res = await ApiService().uploadKitchenPhoto(xFile.path);
      final url = res.data?['data']?['url']?.toString();
      if (!mounted) return;
      setState(() {
        _uploading = false;
        if (url != null) _photoUrl = url;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('照片上传失败，再试一次'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('这道菜叫什么名字？'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
      return;
    }
    setState(() => _sending = true);
    try {
      final now = DateTime.now();
      final cookedAt =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await ApiService().createCookingLog({
        'title': _title.text.trim(),
        'emoji': _emoji,
        'photoUrl': _photoUrl,
        'recipe': _recipe.text.trim().isEmpty ? null : _recipe.text.trim(),
        'story': _story.text.trim().isEmpty ? null : _story.text.trim(),
        'isNew': _isNew,
        'chefRating': _chefRating > 0 ? _chefRating : null,
        'cookedAt': cookedAt,
        'addToMenu': _addToMenu && _isNew,
      });
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().contains('名字') ? '这道菜叫什么名字？' : '记录失败，再试一次'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: LoveGirlTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.separator,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('记一道',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              // 照片
              GestureDetector(
                onTap: _uploading ? null : _pickPhoto,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _photoUrl != null
                            ? LoveGirlTheme.secondary
                            : LoveGirlTheme.separator),
                  ),
                  child: _uploading
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _photoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.network(
                                _photoUrl!.startsWith('http')
                                    ? _photoUrl!
                                    : '${AppConstants.baseUrl}$_photoUrl',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_rounded,
                                    size: 28, color: LoveGirlTheme.textMuted),
                                SizedBox(height: 6),
                                Text('拍一张成品照（可选）',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: LoveGirlTheme.textMuted)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: '这道菜叫什么？*',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: LoveGirlTheme.separator)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: LoveGirlTheme.separator)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              // 新做/复刻
              Row(
                children: [
                  _seg('新做', _isNew, (v) => setState(() => _isNew = v)),
                  const SizedBox(width: 8),
                  _seg('复刻', !_isNew, (v) => setState(() => _isNew = !v)),
                  const Spacer(),
                  // 掌勺自评
                  for (var i = 1; i <= 5; i++)
                    GestureDetector(
                      onTap: () => setState(() => _chefRating = i),
                      child: Icon(
                        i <= _chefRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 22,
                        color: i <= _chefRating
                            ? LoveGirlTheme.orange
                            : LoveGirlTheme.textMuted,
                      ),
                    ),
                ],
              ),
              if (_isNew) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: LoveGirlTheme.separator),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 18, color: LoveGirlTheme.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('挂上点单菜单',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                            Text('TA 就能在厨房点这道菜了',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: LoveGirlTheme.textMuted)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _addToMenu,
                        activeColor: LoveGirlTheme.primary,
                        onChanged: (v) => setState(() => _addToMenu = v),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _recipe,
                maxLines: 3,
                maxLength: 3000,
                decoration: InputDecoration(
                  hintText: '食谱做法（选填，下次照着做）',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: LoveGirlTheme.separator)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: LoveGirlTheme.separator)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _story,
                maxLines: 2,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: '小故事（选填，比如第一次做翻车了）',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: LoveGirlTheme.separator)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: LoveGirlTheme.separator)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              // emoji
              Wrap(
                spacing: 8,
                children: _emojiChoices
                    .map((e) => GestureDetector(
                          onTap: () => setState(() => _emoji = e),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _emoji == e
                                  ? LoveGirlTheme.primary.withAlpha(25)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _emoji == e
                                      ? LoveGirlTheme.primary
                                      : LoveGirlTheme.separator),
                            ),
                            child:
                                Text(e, style: const TextStyle(fontSize: 20)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: LovePrimaryButton(
                  text: _sending ? '记录中…' : '收进手账',
                  icon: Icons.restaurant_menu_rounded,
                  onPressed: _sending ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seg(String label, bool selected, ValueChanged<bool> onTap) {
    return GestureDetector(
      onTap: () => onTap(true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? LoveGirlTheme.primary.withAlpha(25)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? LoveGirlTheme.primary
                  : LoveGirlTheme.separator),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? LoveGirlTheme.primary : LoveGirlTheme.textMuted,
            )),
      ),
    );
  }
}
