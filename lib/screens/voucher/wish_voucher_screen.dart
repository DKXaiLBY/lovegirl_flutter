import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart' show ApiService, extractServerMessage;
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';

/// 愿望兑换券：TA 发行的券用爱心豆兑换，兑换后 TA 现实兑现
class WishVoucherScreen extends StatefulWidget {
  const WishVoucherScreen({super.key});

  @override
  State<WishVoucherScreen> createState() => _WishVoucherScreenState();
}

class _WishVoucherScreenState extends State<WishVoucherScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<Map<String, dynamic>> _partnerVouchers = [];
  List<Map<String, dynamic>> _myVouchers = [];
  List<Map<String, dynamic>> _redemptions = [];
  String? _partnerName;
  bool _hasPartner = true;
  bool _loading = true;
  int _balance = 0;

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
      final api = ApiService();
      final listRes = await api.getVoucherList();
      final d = listRes.data?['data'];
      if (d is Map) {
        _partnerVouchers = _mapList(d['partnerVouchers']);
        _myVouchers = _mapList(d['myVouchers']);
        _partnerName = d['partnerName']?.toString();
        _hasPartner = d['hasPartner'] == true;
      }
      final redRes = await api.getVoucherRedemptions();
      final rd = redRes.data?['data'];
      _redemptions = rd is List ? rd.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() : [];
      final balRes = await api.getBeanBalance();
      _balance = (balRes.data?['data']?['balance'] as num?)?.toInt() ?? 0;
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
      builder: (_) => const _CreateVoucherSheet(),
    );
    if (created == true) _load();
  }

  Future<void> _redeem(Map<String, dynamic> v) async {
    final cost = (v['cost_bean'] as num?)?.toInt() ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('兑换「${v['title']}」？',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(
          '将花费 $cost 颗爱心豆（当前余额 $_balance）。\n兑换后 $_partnerName 会收到通知，快去使唤 TA 吧！',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再想想')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.lgInk),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('兑换')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService().redeemVoucher((v['id'] as num).toInt());
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已兑换「${v['title']}」，等 $_partnerName 兑现吧'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      final msg = extractServerMessage(e, fallback: '兑换失败，再试一次');
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: context.lgInk,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded, size: 18),
        label: const Text('发行一张券',
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
                    '愿望兑换券',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.lgPaper,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: context.lgSeparator),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.savings_rounded,
                            size: 14, color: LoveGirlTheme.orange),
                        const SizedBox(width: 4),
                        Text('$_balance',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '发行你的愿望，或用豆子兑换 TA 的承诺',
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
              tabs: [
                Tab(text: _hasPartner ? '${_partnerName ?? 'TA'} 的券铺' : 'TA 的券铺'),
                const Tab(text: '兑换记录'),
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
                        RefreshIndicator(
                          color: LoveGirlTheme.primary,
                          onRefresh: _load,
                          child: _ShopTab(
                            vouchers: _partnerVouchers,
                            hasPartner: _hasPartner,
                            partnerName: _partnerName,
                            onRedeem: _redeem,
                            onRetry: _load,
                          ),
                        ),
                        RefreshIndicator(
                          color: LoveGirlTheme.primary,
                          onRefresh: _load,
                          child: _RedemptionsTab(
                            redemptions: _redemptions,
                            myVouchers: _myVouchers,
                            onChanged: _load,
                            onRetry: _load,
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

/// TA 的券铺
class _ShopTab extends StatelessWidget {
  final List<Map<String, dynamic>> vouchers;
  final bool hasPartner;
  final String? partnerName;
  final void Function(Map<String, dynamic>) onRedeem;
  final VoidCallback onRetry;

  const _ShopTab({
    required this.vouchers,
    required this.hasPartner,
    required this.partnerName,
    required this.onRedeem,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasPartner) {
      return ListView(children: const [
        SizedBox(height: 100),
        EmptyState(
            icon: Icons.favorite_outline,
            title: '先绑定伴侣',
            subtitle: '绑定后才能发行和兑换券'),
      ]);
    }
    if (vouchers.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        EmptyState(
          icon: Icons.storefront_outlined,
          title: '${partnerName ?? 'TA'} 还没发行券',
          subtitle: '催 TA 发一张，或者你先发一张让 TA 来兑',
          onRetry: onRetry,
          retryText: '刷新',
        ),
      ]);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
      itemCount: vouchers.length,
      itemBuilder: (_, i) {
        final v = vouchers[i];
        return _VoucherCard(
          emoji: v['emoji']?.toString() ?? '🎁',
          title: v['title']?.toString() ?? '',
          cost: (v['cost_bean'] as num?)?.toInt() ?? 0,
          actionLabel: '兑换',
          onAction: () => onRedeem(v),
        );
      },
    );
  }
}

/// 兑换记录 tab（含我发行的券管理）
class _RedemptionsTab extends StatefulWidget {
  final List<Map<String, dynamic>> redemptions;
  final List<Map<String, dynamic>> myVouchers;
  final VoidCallback onChanged;
  final VoidCallback onRetry;

  const _RedemptionsTab({
    required this.redemptions,
    required this.myVouchers,
    required this.onChanged,
    required this.onRetry,
  });

  @override
  State<_RedemptionsTab> createState() => _RedemptionsTabState();
}

class _RedemptionsTabState extends State<_RedemptionsTab> {
  bool _busy = false;

  Future<void> _action(
      Future<dynamic> Function() fn, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(okMsg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('操作失败，再试一次'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.redemptions.isEmpty && widget.myVouchers.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        EmptyState(
          icon: Icons.receipt_long_outlined,
          title: '还没有兑换记录',
          subtitle: '发行的券被兑换后会出现在这里',
          onRetry: widget.onRetry,
          retryText: '刷新',
        ),
      ]);
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
      children: [
        if (widget.myVouchers.isNotEmpty) ...[
          const Text('我发行的券',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...widget.myVouchers.map((v) => _MyVoucherRow(
                v: v,
                busy: _busy,
                onToggle: () => _action(
                  () => ApiService().setVoucherActive(
                      (v['id'] as num).toInt(), v['is_active'] != 1),
                  v['is_active'] == 1 ? '已下架' : '已上架',
                ),
              )),
          const SizedBox(height: 16),
        ],
        if (widget.redemptions.isNotEmpty) ...[
          const Text('兑换记录',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...widget.redemptions.map((r) => _RedemptionRow(
                r: r,
                busy: _busy,
                onDone: () => _action(
                    () => ApiService().doneVoucherRedemption(
                        (r['id'] as num).toInt(),
                        proofUrl: null),
                    '已标记兑现，等 TA 确认'),
                onConfirm: () => _action(
                    () => ApiService()
                        .confirmVoucherRedemption((r['id'] as num).toInt()),
                    '确认完成，这张券圆满啦'),
                onCancel: () => _action(
                    () => ApiService()
                        .cancelVoucherRedemption((r['id'] as num).toInt()),
                    '已取消，豆子退回'),
              )),
        ],
      ],
    );
  }
}

class _MyVoucherRow extends StatelessWidget {
  final Map<String, dynamic> v;
  final bool busy;
  final VoidCallback onToggle;

  const _MyVoucherRow(
      {required this.v, required this.busy, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final active = v['is_active'] == 1;
    final redeemed = (v['redeemed_count'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgSeparator),
      ),
      child: Row(
        children: [
          Text(v['emoji']?.toString() ?? '🎁',
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? context.lgTextPrimary
                        : context.lgTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${v['cost_bean']} 豆 · 已被兑换 $redeemed 次',
                  style: TextStyle(
                      fontSize: 12, color: context.lgTextMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onToggle,
            child: Text(active ? '下架' : '上架',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _RedemptionRow extends StatelessWidget {
  final Map<String, dynamic> r;
  final bool busy;
  final VoidCallback onDone;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _RedemptionRow({
    required this.r,
    required this.busy,
    required this.onDone,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final iAmRedeemer = r['iAmRedeemer'] == true;
    final status = r['status']?.toString();
    final title = r['title']?.toString() ?? '';
    final cost = (r['cost_bean'] as num?)?.toInt() ?? 0;

    final (String statusLabel, Color statusColor) = switch (status) {
      'pending' => ('待兑现', LoveGirlTheme.orange),
      'done' => ('已兑现·待确认', LoveGirlTheme.secondary),
      'confirmed' => ('已完成', LoveGirlTheme.secondary),
      _ => ('已取消', context.lgTextMuted),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgSeparator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r['emoji']?.toString() ?? '🎁',
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  iAmRedeemer ? '我兑换了「$title」' : 'TA 兑换了「$title」',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.lgTextPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$cost 颗爱心豆',
              style: TextStyle(fontSize: 12, color: context.lgTextMuted)),
          if (status == 'pending' && !iAmRedeemer) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LovePrimaryButton(
                    text: busy ? '处理中…' : '我兑现好了',
                    icon: Icons.check_rounded,
                    onPressed: busy ? null : onDone,
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                    onPressed: busy ? null : onCancel,
                    child: const Text('取消')),
              ],
            ),
          ],
          if (status == 'done' && iAmRedeemer) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: LovePrimaryButton(
                text: busy ? '处理中…' : '确认完成',
                icon: Icons.favorite_rounded,
                onPressed: busy ? null : onConfirm,
              ),
            ),
          ],
          if (status == 'pending' && iAmRedeemer) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: busy ? null : onCancel,
                  child: const Text('取消兑换（退豆）',
                      style: TextStyle(fontSize: 12))),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoucherCard extends StatelessWidget {
  final String emoji;
  final String title;
  final int cost;
  final String actionLabel;
  final VoidCallback onAction;

  const _VoucherCard({
    required this.emoji,
    required this.title,
    required this.cost,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: LovePaper(
        color: context.lgPaperWarm,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.lgPaper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.lgSeparator),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.savings_rounded,
                          size: 14, color: LoveGirlTheme.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$cost 颗爱心豆',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: LoveGirlTheme.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.lgInk,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: onAction,
              child: Text(actionLabel,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 发行券 bottom sheet
class _CreateVoucherSheet extends StatefulWidget {
  const _CreateVoucherSheet();

  @override
  State<_CreateVoucherSheet> createState() => _CreateVoucherSheetState();
}

class _CreateVoucherSheetState extends State<_CreateVoucherSheet> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  String _emoji = '🎁';
  bool _sending = false;

  static const _emojiChoices = ['🎁', '🧋', '💆', '🎬', '🍜', '🎮', '🍫', '💐'];

  @override
  void dispose() {
    _title.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final title = _title.text.trim();
    final cost = int.tryParse(_cost.text.trim()) ?? 0;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('给券起个名字吧'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1)));
      return;
    }
    if (cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('定个豆价（大于 0）'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1)));
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService().createVoucher(title, cost, _emoji);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('发行失败，再试一次'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.lgBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(26)),
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
                  color: context.lgSeparator,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('发行一张愿望券',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('TA 用爱心豆兑换后，你就要兑现哦',
                style: TextStyle(
                    fontSize: 12.5, color: context.lgTextSecondary)),
            const SizedBox(height: 16),
            const Text('选个图标',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _emojiChoices
                  .map((e) => GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _emoji == e
                                ? context.lgInk
                                : context.lgPaper,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: context.lgSeparator),
                          ),
                          child: Text(e,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 60,
              decoration: InputDecoration(
                hintText: '券的名字，如「一次肩颈按摩」',
                filled: true,
                fillColor: context.lgPaper,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.lgSeparator)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.lgSeparator)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6)
              ],
              decoration: InputDecoration(
                hintText: '豆价，如 50',
                filled: true,
                fillColor: context.lgPaper,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.lgSeparator)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.lgSeparator)),
                prefixIcon: const Icon(Icons.savings_rounded,
                    size: 20, color: LoveGirlTheme.orange),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: LovePrimaryButton(
                text: _sending ? '发行中…' : '上架这张券',
                icon: Icons.add_card_rounded,
                onPressed: _sending ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
