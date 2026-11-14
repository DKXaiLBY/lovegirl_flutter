import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_dates.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/rebuild_controls.dart';
import '../anniversary/anniversary_screen.dart';
import '../couple/couple_binding_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ApiService? api;
  const ProfileScreen({super.key, this.api});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _api = widget.api ?? ApiService();
  int? _account;
  int _request = 0;
  bool _loading = true;
  Map<String, dynamic>? _couple;
  List<Map<String, dynamic>>? _anniversaries;
  String? _cover;
  List<String> _errors = [];
  bool get _bound => _couple?['coupled'] == true;
  Map<String, dynamic>? get _partner => _bound && _couple?['partner'] is Map
      ? Map<String, dynamic>.from(_couple!['partner'])
      : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<AuthProvider>().userId;
    if (_request == 0 || _account != id) {
      _account = id;
      _request++;
      _loading = true;
      _couple = null;
      _anniversaries = null;
      _cover = null;
      _errors = [];
      final request = _request;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && request == _request) _load();
      });
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final errors = <String>[];
    setState(() => _loading = true);
    Future<dynamic> read(Future<dynamic> response, String name) async {
      try {
        return (await response.timeout(const Duration(seconds: 8)))
            .data['data'];
      } catch (_) {
        errors.add(name);
        return null;
      }
    }

    final values = await Future.wait([
      read(_api.getCoupleStatus(), '关系'),
      read(_api.getAnniversaries(), '纪念日'),
      read(_api.getPhotos(), '照片'),
      read(_api.getCreations(), '作品'),
    ]);
    if (!mounted || request != _request) return;
    final images = <Map<String, String>>[];
    if (values[2] is List) {
      for (final p in (values[2] as List).whereType<Map>()) {
        final url = '${p['url'] ?? p['image'] ?? ''}';
        if (url.isNotEmpty) {
          images.add({'url': url, 'date': '${p['created_at'] ?? ''}'});
        }
      }
    }
    if (values[3] is List) {
      for (final p in (values[3] as List).whereType<Map>()) {
        final urls = p['sourceUrls'];
        if (p['document'] is Map &&
            p['document']['kind'] == 'polaroid' &&
            urls is List &&
            urls.isNotEmpty) {
          images
              .add({'url': '${urls.first}', 'date': '${p['updatedAt'] ?? ''}'});
        }
      }
    }
    images.sort((a, b) => b['date']!.compareTo(a['date']!));
    setState(() {
      if (values[0] is Map && values[0]['coupled'] is bool) {
        _couple = Map<String, dynamic>.from(values[0]);
      }
      if (values[1] is List) {
        _anniversaries = (values[1] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (images.isNotEmpty) {
        _cover = images.first['url'];
      } else if (values[2] is List && values[3] is List) {
        _cover = null;
      }
      _errors = errors;
      _loading = false;
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  String _url(String path) =>
      path.startsWith('http') ? path : AppConstants.baseUrl + path;
  Widget _avatar(Map<String, dynamic>? person) {
    final url = '${person?['avatar'] ?? person?['avatar_url'] ?? ''}';
    return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.lgPrimarySoft,
            border: Border.all(color: context.lgPaper, width: 2)),
        child: ClipOval(
            child: url.isEmpty
                ? Icon(Icons.person_outline, color: context.lgTextSecondary)
                : CachedNetworkImage(
                    imageUrl: _url(url),
                    fit: BoxFit.cover,
                    memCacheWidth: 140,
                    errorWidget: (_, __, ___) => Icon(Icons.person_outline,
                        color: context.lgTextSecondary))));
  }

  void _people() {
    final me = context.read<AuthProvider>().user;
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(
            minimum: const EdgeInsets.only(bottom: 24),
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('双方资料',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      for (final person in [me, if (_partner != null) _partner])
                        ListTile(
                            leading: _avatar(person),
                            title: Text('${person?['nickname'] ?? '未填写昵称'}'),
                            subtitle:
                                Text(identical(person, me) ? '我的资料' : '伴侣资料')),
                      if (_couple == null)
                        const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('关系暂未读取')),
                      if (_couple != null && !_bound)
                        const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('绑定后可以查看伴侣资料')),
                      TextButton(
                          style: rebuildTextStyle(context),
                          onPressed: () {
                            Navigator.pop(sheet);
                            _open(const SettingsScreen());
                          },
                          child: const Text('编辑我的资料')),
                    ])))));
  }

  Widget _row(IconData icon, String title, String hint, VoidCallback onTap) =>
      InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(icon, size: 24, color: context.lgInk),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title, style: const TextStyle(fontSize: 15)),
                      if (hint.isNotEmpty)
                        Text(hint,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: context.lgTextSecondary)),
                    ])),
                const Icon(Icons.chevron_right, size: 20),
              ])));

  Widget _hero(Map<String, dynamic>? me) {
    final start = resolveLoveStartDate(
        explicitDate: me?['loveStartDate']?.toString(),
        anniversaries: _anniversaries ?? []);
    final days = start == null
        ? null
        : resolveLoveDays(explicitDate: start.toIso8601String());
    final caption = _loading && _couple == null
        ? '正在读取关系…'
        : _couple == null
            ? '关系暂未读取'
            : !_bound
                ? '邀请Ta，一起留下日常'
                : days == null
                    ? '设置属于你们的纪念日起点'
                    : '在一起的第$days天';
    return ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: AspectRatio(
            aspectRatio: 1.08,
            child: Stack(fit: StackFit.expand, children: [
              if (_cover != null)
                CachedNetworkImage(
                    imageUrl: _url(_cover!),
                    fit: BoxFit.cover,
                    memCacheWidth: 1000,
                    errorWidget: (_, __, ___) => RebuildPageBackground(
                        child: Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                color: context.lgTextSecondary)))),
              if (_cover == null)
                const RebuildPageBackground(child: SizedBox.expand()),
              DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                    context.lgIsDark
                        ? const Color(0xdd171c23)
                        : const Color(0xddeff8ff),
                    Colors.transparent
                  ]))),
              Positioned(
                  top: 0,
                  left: 16,
                  right: 12,
                  child: SafeArea(
                      bottom: false,
                      child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            const Expanded(
                                child: Text('我们',
                                    style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800))),
                            RebuildGlassButton(
                                label: '设置',
                                icon: Icons.settings_outlined,
                                onPressed: () => _open(const SettingsScreen())),
                          ])))),
              if (_cover == null)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.favorite_border,
                              size: 44, color: context.lgTextSecondary),
                          const SizedBox(height: 12),
                          Text(
                              _errors.contains('照片') && _errors.contains('作品')
                                  ? '照片暂时没能读取'
                                  : '你们的照片，会留在这里',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: context.lgTextSecondary,
                                  fontSize: 14)),
                        ]))),
              Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: RebuildGlass(
                      radius: 28,
                      child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: _couple == null
                              ? _load
                              : _bound
                                  ? () => _open(const AnniversaryScreen())
                                  : () => _open(const CoupleBindingScreen()),
                          child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(children: [
                                SizedBox(
                                    width: 84,
                                    height: 48,
                                    child: Stack(children: [
                                      Positioned(left: 0, child: _avatar(me)),
                                      if (_bound)
                                        Positioned(
                                            left: 32, child: _avatar(_partner)),
                                    ])),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(caption,
                                        maxLines: 2,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.lgInk))),
                                const Icon(Icons.chevron_right, size: 20),
                              ]))))),
            ])));
  }

  Widget _importantDays() {
    final next = upcomingAnniversary(_anniversaries ?? [], maxDays: null);
    final nextDate = next == null
        ? null
        : DateTime.now().add(Duration(days: next['days'] as int));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Text('重要日子',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      if (_anniversaries == null)
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_loading ? '正在读取纪念日…' : '纪念日暂未读取',
                style: TextStyle(color: context.lgTextSecondary)))
      else if (next != null)
        LoveTicketCard(
            color: context.lgPaper,
            padding: const EdgeInsets.all(16),
            child: InkWell(
                onTap: () => _open(const AnniversaryScreen()),
                child: Row(children: [
                  Icon(Icons.event_outlined, color: context.lgInk, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${next['title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)),
                        Text('${nextDate!.month}月${nextDate.day}日',
                            style: TextStyle(
                                fontSize: 12, color: context.lgTextSecondary)),
                      ])),
                  const SizedBox(width: 12),
                  Column(children: [
                    Text(next['days'] == 0 ? '就是' : '还有',
                        style: TextStyle(
                            fontSize: 11, color: context.lgTextSecondary)),
                    Text(next['days'] == 0 ? '今天' : '${next['days']} 天',
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: context.lgIsDark
                                ? const Color(0xff93beff)
                                : const Color(0xff2a66ad))),
                  ]),
                ])))
      else
        Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
            child: Text(_anniversaries!.isEmpty ? '记下一个对你们重要的日子' : '近期没有到来的纪念日',
                style:
                    TextStyle(color: context.lgTextSecondary, fontSize: 13))),
      RebuildGlass(
          child: _row(Icons.calendar_month_outlined, '管理纪念日', '',
              () => _open(const AnniversaryScreen()))),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context.lgBg,
      body: RebuildPageBackground(
          child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    _hero(context.watch<AuthProvider>().user),
                    if (_errors.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 12, 0),
                          child: Row(children: [
                            Expanded(
                                child: Text('${_errors.join('、')}暂未刷新',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.lgTextSecondary))),
                            TextButton(
                                style: rebuildTextStyle(context),
                                onPressed: _loading ? null : _load,
                                child: const Text('重试')),
                          ])),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                        child: RebuildGlass(
                            child: _row(
                                Icons.favorite_border,
                                '我们的关系',
                                _loading && _couple == null
                                    ? '正在读取…'
                                    : _couple == null
                                        ? '关系暂未读取'
                                        : _bound
                                            ? '已绑定 · ${_partner?['nickname'] ?? '伴侣'}'
                                            : '尚未绑定伴侣',
                                _bound
                                    ? _people
                                    : () =>
                                        _open(const CoupleBindingScreen())))),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _importantDays()),
                    const SizedBox(height: 12),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: RebuildGlass(
                            child: Column(children: [
                          _row(Icons.person_outline, '双方资料', '', _people),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _row(Icons.link_outlined, '伴侣绑定', '',
                              () => _open(const CoupleBindingScreen())),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _row(
                              Icons.notifications_outlined,
                              '隐私与通知',
                              '',
                              () => _open(
                                  const SettingsScreen(openPrivacy: true))),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _row(Icons.settings_outlined, '设置与更新', '',
                              () => _open(const SettingsScreen())),
                        ]))),
                  ]))));
}
