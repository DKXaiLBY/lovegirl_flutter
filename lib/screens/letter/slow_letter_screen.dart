import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart' show ApiService, extractServerMessage;
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';

/// 慢信（时间胶囊）：写给 TA 的信，到指定日期才能拆开
class SlowLetterScreen extends StatefulWidget {
  const SlowLetterScreen({super.key});

  @override
  State<SlowLetterScreen> createState() => _SlowLetterScreenState();
}

class _SlowLetterScreenState extends State<SlowLetterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<Map<String, dynamic>> _inbox = [];
  List<Map<String, dynamic>> _outbox = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getLetterList();
      final d = res.data?['data'];
      if (d is Map) {
        _inbox = (d['inbox'] as List? ?? [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _outbox = (d['outbox'] as List? ?? [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCompose() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const LetterComposeScreen()));
    if (sent == true) _load();
  }

  Future<void> _openLetter(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LetterReadScreen(letterId: id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        backgroundColor: context.lgInk,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('写一封慢信',
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
                    '慢信',
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
                '把现在的心意封存起来，寄给未来的你们',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.lgTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: context.lgInk,
              unselectedLabelColor: context.lgTextMuted,
              indicatorColor: context.lgInk,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: '收到的'),
                Tab(text: '寄出的'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: LoveGirlTheme.primary))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _LetterList(
                            letters: _inbox,
                            isOutbox: false,
                            onTap: _openLetter,
                            onRetry: _load),
                        _LetterList(
                            letters: _outbox,
                            isOutbox: true,
                            onTap: _openLetter,
                            onRetry: _load),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LetterList extends StatelessWidget {
  final List<Map<String, dynamic>> letters;
  final bool isOutbox;
  final void Function(int id) onTap;
  final VoidCallback onRetry;

  const _LetterList({
    required this.letters,
    required this.isOutbox,
    required this.onTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (letters.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        EmptyState(
          icon: isOutbox
              ? Icons.send_outlined
              : Icons.mark_email_unread_outlined,
          title: isOutbox ? '还没有寄出过慢信' : '还没有收到慢信',
          subtitle: isOutbox ? '写一封给未来的 TA' : '让 TA 也写一封吧',
          onRetry: onRetry,
          retryText: '刷新',
        ),
      ]);
    }
    return RefreshIndicator(
      color: LoveGirlTheme.primary,
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
        itemCount: letters.length,
        itemBuilder: (_, i) {
          final e = letters[i];
          final unlocked = e['unlocked'] == true;
          final unread = e['unread'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: unread ? context.lgPaperWarm : context.lgPaper,
              borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
              child: InkWell(
                borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
                onTap: () => onTap((e['id'] as num).toInt()),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(LoveGirlTheme.radiusLg),
                    border: Border.all(color: context.lgSeparator),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: unlocked
                              ? context.lgPrimarySoft
                              : context.lgSeparator.withAlpha(120),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          unlocked
                              ? Icons.mail_rounded
                              : Icons.lock_outline_rounded,
                          size: 20,
                          color: unlocked
                              ? context.lgInk
                              : context.lgTextMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e['title']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: context.lgTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              unlocked
                                  ? (isOutbox
                                      ? '已可拆读 · ${e['readByPartner'] == true ? "TA 看过了" : "TA 还没拆"}'
                                      : (unread ? '可以拆开啦' : '已读过'))
                                  : '${e['unlockDate']} 解锁',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.lgTextMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: context.lgEmotion,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 写信页
class LetterComposeScreen extends StatefulWidget {
  const LetterComposeScreen({super.key});

  @override
  State<LetterComposeScreen> createState() => _LetterComposeScreenState();
}

class _LetterComposeScreenState extends State<LetterComposeScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  final FocusNode _contentFocus = FocusNode();
  String? _contentError;
  DateTime _unlockDate = DateTime.now().add(const Duration(days: 30));
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  String get _dateStr {
    final d = _unlockDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _unlockDate,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
      helpText: '选择拆信的日子',
      cancelText: '取消',
      confirmText: '就这天',
    );
    if (picked != null) setState(() => _unlockDate = picked);
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_content.text.trim().isEmpty) {
      // 行内校验：正文框红边+错误文案，收起键盘让错误可见（snackbar 会被键盘挡住）
      setState(() => _contentError = '信还空着呢，写点什么吧');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (_contentFocus.hasFocus) _contentFocus.unfocus();
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService().sendLetter(
          _title.text.trim(), _content.text.trim(), _dateStr);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final msg = extractServerMessage(e, fallback: '寄出失败，再试一次');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    '写一封慢信',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  LovePaper(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _title,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            hintText: '给信起个名字（可留空）',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _content,
                          focusNode: _contentFocus,
                          maxLines: 10,
                          maxLength: 5000,
                          onChanged: (v) {
                            if (_contentError != null && v.trim().isNotEmpty) {
                              setState(() => _contentError = null);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: '写下现在想说的话…\n到拆信那天，它会变成一份来自过去的礼物',
                            border: InputBorder.none,
                            errorText: _contentError,
                          ),
                          style: const TextStyle(
                              fontSize: 15, height: 1.7),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LovePaper(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock_clock_rounded,
                                size: 18, color: context.lgEmotion),
                            const SizedBox(width: 8),
                            const Text(
                              '拆信日子',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _pickDate,
                              child: Text(_dateStr,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '在那之前谁也拆不开（包括你自己重装 App 也不行，内容存在你们自己的服务器上）。',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: context.lgTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: LovePrimaryButton(
                      text: _sending ? '封存中…' : '封存这封信',
                      icon: Icons.favorite_rounded,
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 读信页（信纸风）
class LetterReadScreen extends StatefulWidget {
  final int letterId;

  const LetterReadScreen({super.key, required this.letterId});

  @override
  State<LetterReadScreen> createState() => _LetterReadScreenState();
}

class _LetterReadScreenState extends State<LetterReadScreen> {
  Map<String, dynamic>? _letter;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().getLetter(widget.letterId);
      final d = res.data?['data'];
      if (d is Map && mounted) {
        setState(() => _letter = d.cast<String, dynamic>());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = extractServerMessage(e, fallback: '信加载失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? EmptyState(
                      icon: Icons.lock_clock_rounded, title: _error!)
                  : _letter == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: LoveGirlTheme.primary))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          children: [
                            LovePaper(
                              color: context.lgPaperWarm,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.mark_email_read_rounded,
                                          size: 16,
                                          color: context.lgEmotion),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_letter!['senderName'] ?? 'TA'} 写于 ${_letter!['createdAt']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: context.lgTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _letter!['title']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '解锁日：${_letter!['unlockDate']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.lgTextMuted,
                                    ),
                                  ),
                                  const Divider(height: 28),
                                  Text(
                                    _letter!['content']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
