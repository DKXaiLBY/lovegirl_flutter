import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/travel.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/motion.dart';
import '../../widgets/lovegirl_ui.dart';
import '../../widgets/rebuild_controls.dart';
import '../../utils/constants.dart';
import '../couple/couple_binding_screen.dart';
import '../cooking/cooking_log_screen.dart';
import '../photo/photo_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../anniversary/anniversary_screen.dart';
import '../life/life_screen.dart';
import '../life/widgets/todo_list.dart';
import '../../utils/app_section.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<AppSection>? onNavigateToTab;
  final ApiService? api;

  const HomeScreen({
    super.key,
    this.onNavigateToTab,
    this.api,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ApiService _api = widget.api ?? ApiService();
  List<Map<String, dynamic>> _partnerRecent = [];
  bool _partnerBound = false;
  Map<String, dynamic>? _memoryToday; // W5 弹药库 7.3/10.2：N 年前的今天
  Map<String, dynamic>? _heroPhoto;
  Map<String, dynamic>? _partner;
  bool _coupleLoaded = false;
  bool _coupleLoading = true;
  bool _photoLoading = true;
  bool _photoFailed = false;
  int? _account;
  int _mediaRequest = 0;
  int _accountRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = context.watch<AuthProvider>().userId;
    if (_mediaRequest == 0 || account != _account) {
      _account = account;
      final accountRevision = ++_accountRevision;
      _mediaRequest++;
      _heroPhoto = _memoryToday = _partner = null;
      _photoLoading = true;
      _photoFailed = false;
      _coupleLoaded = _partnerBound = false;
      _coupleLoading = true;
      _partnerRecent = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _accountRevision == accountRevision) _refresh();
      });
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<HomeProvider>().refresh(),
      context.read<NotificationProvider>().refreshCount(),
      _loadPartnerRecent(),
      _loadMemoryToday(),
    ]);
  }

  /// W5「N 年前的今天」回忆卡（白卡+蜜桃点缀；不进渐变白名单；X 关闭当天不再出现）
  Widget _buildMemoryTodayCard() {
    final m = _memoryToday!;
    final years = m['years'] as int;
    final isPhoto = m['type'] == 'photo';
    final title = (m['title'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: context.lgCard,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          onTap: () {
            _dismissMemoryToday();
            if (isPhoto) {
              _push(const PhotoScreen());
            } else {
              widget.onNavigateToTab?.call(AppSection.travel);
            }
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
              border: Border(
                  left: BorderSide(color: LoveGirlTheme.peach, width: 3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.peach.withAlpha(28),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.history_rounded,
                      size: 22, color: LoveGirlTheme.peach),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$years 年前的今天',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: LoveGirlTheme.peachText)),
                      const SizedBox(height: 2),
                      Text(
                        title.isEmpty
                            ? (isPhoto ? '我们拍下过一张照片' : '我们去过一个地方')
                            : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: context.lgTextPrimary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      size: 16, color: context.lgTextMuted),
                  onPressed: _dismissMemoryToday,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// W5「N 年前的今天」：轻量拉取照片+足迹，命中则渲染回忆卡（失败/无命中零痕迹）
  Future<void> _loadMemoryToday() async {
    final request = ++_mediaRequest;
    final account = _accountRevision;
    if (mounted) setState(() => _photoLoading = true);
    Future<dynamic> read(Future<dynamic> response) async {
      try {
        return (await response.timeout(const Duration(seconds: 8)))
            .data['data'];
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      read(_api.getPhotos()),
      read(_api.getCreations()),
      read(_api.getTravelSpots()),
    ]);
    if (!mounted || account != _accountRevision || request != _mediaRequest) {
      return;
    }
    final photos = results[0] is List
        ? (results[0] as List)
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList()
        : <Map<String, dynamic>>[];
    final candidates = <Map<String, dynamic>>[];
    for (final photo in photos) {
      final url = (photo['url'] ?? photo['image'] ?? '').toString();
      if (url.isEmpty) continue;
      candidates.add({
        'url': url,
        'title': '${photo['frame_note'] ?? ''}'.trim().isNotEmpty
            ? photo['frame_note']
            : photo['description'] ?? '',
        'date': photo['photo_date'] ?? photo['created_at'],
        'sort': photo['created_at'] ?? photo['photo_date']
      });
    }
    if (results[1] is List) {
      for (final work in (results[1] as List).whereType<Map>()) {
        final document = work['document'];
        final sources = work['sourceUrls'];
        if (document is! Map ||
            document['kind'] != 'polaroid' ||
            sources is! List ||
            sources.isEmpty) {
          continue;
        }
        candidates.add({
          'url': sources.first.toString(),
          'title': document['title'] ?? '',
          'date': document['date'],
          'location': work['tripTitle'] ?? '',
          'sort': work['updatedAt']
        });
      }
    }
    DateTime date(Map<String, dynamic> p) =>
        DateTime.tryParse('${p['sort']}'.replaceFirst(' ', 'T')) ??
        DateTime(1970);
    candidates.sort((a, b) => date(b).compareTo(date(a)));
    final failed = results[0] is! List || results[1] is! List;
    setState(() {
      if (candidates.isNotEmpty) {
        _heroPhoto = candidates.first;
      } else if (!failed) {
        _heroPhoto = null;
      }
      _photoLoading = false;
      _photoFailed = failed;
    });
    final raw = results[2];
    final rows = raw is List
        ? raw
        : raw is Map
            ? raw['list']
            : null;
    final spots = rows is List
        ? rows
            .whereType<Map>()
            .map((p) => TravelSpot.fromJson(Map<String, dynamic>.from(p)))
            .toList()
        : <TravelSpot>[];
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || account != _accountRevision || request != _mediaRequest) {
      return;
    }
    final now = DateTime.now();
    final key =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    setState(() => _memoryToday = prefs.getString('memory_dismiss_last') == key
        ? null
        : pickMemoryToday(photos, spots, now));
  }

  Future<void> _dismissMemoryToday() async {
    final now = DateTime.now();
    final key =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('memory_dismiss_last', key);
    if (mounted) setState(() => _memoryToday = null);
  }

  Future<void> _loadPartnerRecent() async {
    final account = _accountRevision;
    Future<dynamic> read(Future<dynamic> response) async {
      try {
        return (await response.timeout(const Duration(seconds: 8)))
            .data['data'];
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait(
        [read(_api.getPartnerRecent()), read(_api.getCoupleStatus())]);
    if (!mounted || account != _accountRevision) return;
    setState(() {
      final recent = results[0];
      if (recent is Map) {
        if (recent['hasPartner'] is bool) {
          _partnerBound = recent['hasPartner'] == true;
        }
        _partnerRecent =
            (recent['items'] is List ? recent['items'] as List : [])
                .whereType<Map>()
                .where((e) => e['type'] == 'cooking' || e['type'] == 'travel')
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
      }
      final couple = results[1];
      _coupleLoading = false;
      if (couple is Map && couple['coupled'] is bool) {
        _coupleLoaded = true;
        _partnerBound = couple['coupled'] == true;
        _partner = _partnerBound && couple['partner'] is Map
            ? Map<String, dynamic>.from(couple['partner'])
            : null;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 从后台切回时刷新角标和近况（对方可能刚产生了新动态）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();
    final anniversary = home.today?['anniversary'];
    return Scaffold(
        backgroundColor: context.lgBg,
        body: RebuildPageBackground(
            child: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                        children: [
                          _HomeHeader(
                              loveDays: math.max(auth.loveDays, home.loveDays),
                              partner: _partner,
                              bound: _partnerBound,
                              known: _coupleLoaded,
                              loading: _coupleLoading,
                              onRelationship: () =>
                                  _push(const CoupleBindingScreen()),
                              onNavigateToTab: widget.onNavigateToTab),
                          const SizedBox(height: 16),
                          _HomePhotoHero(
                              photo: _heroPhoto,
                              loading: _photoLoading,
                              failed: _photoFailed,
                              revision: _mediaRequest,
                              onRecord: () =>
                                  _push(const PhotoScreen(createOnOpen: true)),
                              onOpen: () => _push(const PhotoScreen()),
                              onRetry: _loadMemoryToday),
                          if (home.error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBanner(
                                message: home.error!, onRetry: _refresh),
                          ],
                          const SizedBox(height: 16),
                          _TodayCareSection(
                              today: home.today,
                              loading: home.isLoading && home.today == null,
                              onFeedingTap: () => _push(const KitchenScreen()),
                              onTodoTap: () => _push(const LifeToolScreen(
                                  title: '待办', child: TodoListWidget())),
                              onAddTodo: () => _push(const LifeToolScreen(
                                  title: '待办',
                                  child: TodoListWidget(createOnOpen: true))),
                              onTodoToggle: _toggleTodo),
                          if (anniversary is Map) ...[
                            const SizedBox(height: 14),
                            _NextAnniversary(
                                data: anniversary,
                                onTap: () => _push(const AnniversaryScreen())),
                          ],
                          if (_memoryToday != null) ...[
                            const SizedBox(height: 14),
                            _buildMemoryTodayCard(),
                          ],
                          if (_partnerBound && _partnerRecent.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _PartnerRecentCard(
                                items: _partnerRecent,
                                onTapCooking: () =>
                                    _push(const CookingLogScreen()),
                                onNavigateToTab: widget.onNavigateToTab),
                          ],
                          if (_memoryToday == null &&
                              home.memory?.isNotEmpty == true) ...[
                            const SizedBox(height: 14),
                            _MemoryTicket(
                                memory: home.memory,
                                onTap: () => widget.onNavigateToTab
                                    ?.call(AppSection.memories)),
                          ],
                        ])))));
  }

  Future<void> _toggleTodo(int id, bool complete) async {
    final home = context.read<HomeProvider>();
    if (home.isTodoSaving(id)) return;
    final saved = await home.toggleTodo(id, complete: complete);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有修改成功，待办仍然保留，请再试一次')));
    }
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _refresh();
  }
}

String _homeImageUrl(String path) =>
    path.startsWith('http') ? path : AppConstants.baseUrl + path;

class _HomeHeader extends StatelessWidget {
  final int loveDays;
  final Map<String, dynamic>? partner;
  final bool bound, known, loading;
  final VoidCallback onRelationship;
  final ValueChanged<AppSection>? onNavigateToTab;
  const _HomeHeader(
      {required this.loveDays,
      required this.partner,
      required this.bound,
      required this.known,
      required this.loading,
      required this.onRelationship,
      this.onNavigateToTab});
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final now = DateTime.now();
    final weekday = const [
      '星期一',
      '星期二',
      '星期三',
      '星期四',
      '星期五',
      '星期六',
      '星期日'
    ][now.weekday - 1];
    return Column(key: const ValueKey('home_header'), children: [
      Row(children: [
        const Expanded(
            child: Text('今天',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
        Semantics(
            button: true,
            label: '查看你们的关系',
            child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: onRelationship,
                child: SizedBox(
                    width: 72,
                    height: 48,
                    child: Stack(children: [
                      Positioned(
                          left: 0,
                          top: 4,
                          child: _HomeAvatar(
                              path: user?['avatar']?.toString() ?? '')),
                      Positioned(
                          left: 28,
                          top: 4,
                          child: _HomeAvatar(
                              path: (partner?['avatar'] ??
                                      partner?['avatar_url'] ??
                                      '')
                                  .toString(),
                              invite: !bound)),
                    ])))),
        const SizedBox(width: 8),
        _BellBadge(onNavigateToTab: onNavigateToTab),
      ]),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text('${now.month}月${now.day}日 · $weekday',
                maxLines: 2,
                style:
                    TextStyle(fontSize: 12, color: context.lgTextSecondary))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                bound
                    ? '在一起的第$loveDays天'
                    : loading
                        ? '正在读取双人信息…'
                        : known
                            ? '邀请Ta，一起记录日常'
                            : '双人信息暂未读取',
                textAlign: TextAlign.right,
                maxLines: 2,
                style:
                    TextStyle(fontSize: 12, color: context.lgTextSecondary))),
      ]),
    ]);
  }
}

class _HomeAvatar extends StatelessWidget {
  final String path;
  final bool invite;
  const _HomeAvatar({required this.path, this.invite = false});
  @override
  Widget build(BuildContext context) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.lgPaper, width: 2)),
      child: ClipOval(
          child: path.isEmpty
              ? ColoredBox(
                  color: context.lgPrimarySoft,
                  child: Icon(
                      invite
                          ? Icons.person_add_alt_outlined
                          : Icons.person_outline,
                      size: 22,
                      color: context.lgTextSecondary))
              : CachedNetworkImage(
                  imageUrl: _homeImageUrl(path),
                  fit: BoxFit.cover,
                  memCacheWidth: 120,
                  errorWidget: (_, __, ___) => ColoredBox(
                      color: context.lgPrimarySoft,
                      child: Icon(Icons.person_outline,
                          color: context.lgTextSecondary)))));
}

class _BellBadge extends StatelessWidget {
  final ValueChanged<AppSection>? onNavigateToTab;
  const _BellBadge({this.onNavigateToTab});
  @override
  Widget build(BuildContext context) {
    final unread = context.select((NotificationProvider p) => p.unreadCount);
    return Stack(clipBehavior: Clip.none, children: [
      RebuildGlassButton(
          label: unread == 0 ? '通知' : '通知，$unread条未读',
          icon: Icons.notifications_none_outlined,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  NotificationCenterScreen(onNavigateToTab: onNavigateToTab)))),
      if (unread > 0)
        Positioned(
            top: 3,
            right: 3,
            child: IgnorePointer(
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LoveGirlTheme.red,
                        border:
                            Border.all(color: context.lgPaper, width: 1.5))))),
    ]);
  }
}

class _HomePhotoHero extends StatelessWidget {
  final Map<String, dynamic>? photo;
  final bool loading, failed;
  final int revision;
  final VoidCallback onRecord, onOpen;
  final Future<void> Function() onRetry;
  const _HomePhotoHero(
      {required this.photo,
      required this.loading,
      required this.failed,
      required this.revision,
      required this.onRecord,
      required this.onOpen,
      required this.onRetry});

  Widget _fallback(BuildContext context, {bool imageError = false}) =>
      ColoredBox(
          color: imageError ? const Color(0xff465566) : context.lgPrimarySoft,
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (loading)
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: imageError ? Colors.white : context.lgInk))
                    else
                      Icon(
                          failed || imageError
                              ? Icons.cloud_off_outlined
                              : Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: imageError
                              ? Colors.white
                              : context.lgTextSecondary),
                    const SizedBox(height: 12),
                    Text(
                        loading
                            ? '正在找回你们的照片…'
                            : failed || imageError
                                ? '照片暂时没加载出来'
                                : '留下一张两个人的照片',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            color: imageError
                                ? Colors.white
                                : context.lgTextPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (failed || imageError)
                            TextButton(
                                style: imageError
                                    ? TextButton.styleFrom(
                                        foregroundColor: Colors.white)
                                    : rebuildTextStyle(context),
                                onPressed: loading ? null : onRetry,
                                child: const Text('重试')),
                          if (!imageError)
                            RebuildGlassButton(
                                label: '记录今天',
                                icon: Icons.edit_outlined,
                                showLabel: true,
                                onPressed: onRecord),
                        ]),
                  ]))));

  @override
  Widget build(BuildContext context) {
    final item = photo;
    final rawDate =
        DateTime.tryParse('${item?['date']}'.replaceFirst(' ', 'T'));
    final title = '${item?['title'] ?? ''}'.trim().split('\n').first;
    final date = [
      if (rawDate != null) '${rawDate.month}月${rawDate.day}日',
      if ('${item?['location'] ?? ''}'.isNotEmpty) '${item!['location']}'
    ].join(' · ');
    final large = MediaQuery.textScalerOf(context).scale(14) > 19;
    return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: item == null
            ? SizedBox(
                key: const ValueKey('home_photo_empty'),
                height: 210,
                child: _fallback(context))
            : AspectRatio(
                key: const ValueKey('home_photo_hero'),
                aspectRatio: .8,
                child: Stack(fit: StackFit.expand, children: [
                  GestureDetector(
                      onTap: onOpen,
                      child: CachedNetworkImage(
                          key: ValueKey('${item['url']}:$revision'),
                          imageUrl: _homeImageUrl('${item['url']}'),
                          fit: BoxFit.cover,
                          memCacheWidth: 1000,
                          placeholder: (_, __) => ColoredBox(
                              color: const Color(0xff465566),
                              child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))),
                          errorWidget: (_, __, ___) =>
                              _fallback(context, imageError: true))),
                  if (failed)
                    Positioned(
                        top: 12,
                        left: 12,
                        child: RebuildGlass(
                            padding: const EdgeInsets.all(8),
                            child: Text('照片暂未刷新',
                                style: TextStyle(
                                    fontSize: 11, color: context.lgInk)))),
                  Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: RebuildGlass(
                          radius: 22,
                          padding: const EdgeInsets.all(12),
                          child: large
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      _caption(context, title, date),
                                      const SizedBox(height: 8),
                                      Align(
                                          alignment: Alignment.centerRight,
                                          child: RebuildGlassButton(
                                              label: '记录今天',
                                              icon: Icons.edit_outlined,
                                              showLabel: true,
                                              onPressed: onRecord))
                                    ])
                              : Row(children: [
                                  Expanded(
                                      child: _caption(context, title, date)),
                                  const SizedBox(width: 8),
                                  RebuildGlassButton(
                                      label: '记录今天',
                                      icon: Icons.edit_outlined,
                                      showLabel: true,
                                      onPressed: onRecord)
                                ]))),
                ])));
  }

  Widget _caption(BuildContext context, String title, String date) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.isEmpty ? '我们的照片' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)])),
        if (date.isNotEmpty)
          Text(date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)])),
      ]);
}

class _NextAnniversary extends StatelessWidget {
  final Map data;
  final VoidCallback onTap;
  const _NextAnniversary({required this.data, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final days = _asInt(data['days']);
    final date = DateTime.now().add(Duration(days: days));
    return RebuildGlass(
        radius: 22,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.event_outlined, size: 26, color: context.lgInk),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('下一个纪念日',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('${date.month}月${date.day}日 · ${data['title']}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: context.lgTextSecondary))
                      ])),
                  const SizedBox(width: 8),
                  Text(days == 0 ? '就是今天' : '还有$days天',
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextSecondary)),
                  const Icon(Icons.chevron_right, size: 18),
                ]))));
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final safeMessage = _sanitizeNetworkMessage(message);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // v4.0：底随主题（原 Colors.white 硬编码深色不破），细线描边对齐卡片体系
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgCardBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: context.lgInk,
            size: 18,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              safeMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.lgTextSecondary,
              ),
            ),
          ),
          TextButton(
            style: rebuildTextStyle(context),
            onPressed: onRetry,
            child: const Text('\u91cd\u8bd5'),
          ),
        ],
      ),
    );
  }
}

String _sanitizeNetworkMessage(String message) {
  if (message.contains('DioException') ||
      message.contains('HttpException') ||
      message.contains('Connection closed before full header was received') ||
      message.contains('connection error')) {
    return '网络有点不稳定，刚刚有一部分内容没加载出来。';
  }
  return message;
}

class _TodayCareSection extends StatelessWidget {
  final Map<String, dynamic>? today;
  final bool loading;
  final VoidCallback onFeedingTap, onTodoTap, onAddTodo;
  final void Function(int id, bool complete)? onTodoToggle;
  const _TodayCareSection(
      {required this.today,
      required this.loading,
      required this.onFeedingTap,
      required this.onTodoTap,
      required this.onAddTodo,
      this.onTodoToggle});
  @override
  Widget build(BuildContext context) {
    final feed = _typedMap(today?['feed']);
    final todo = _typedMap(today?['todo']);
    final rows = todo['items'] is List
        ? (todo['items'] as List).map(_typedMap).take(2).toList()
        : <Map<String, dynamic>>[];
    final total = _asInt(todo['total']).clamp(0, 1 << 30);
    final active = _asInt(todo['active']).clamp(0, total);
    final available = todo['available'] != false;
    return Column(
        key: const ValueKey('home_today_care'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Expanded(
                child: Text('今天的小事',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            if (!loading && available && total > 0)
              TextButton(
                  style: rebuildTextStyle(context),
                  onPressed: onTodoTap,
                  child: Text('${total - active}/$total 完成',
                      style: TextStyle(
                          fontSize: 11, color: context.lgTextSecondary))),
            RebuildGlassButton(
                label: '添加今天的小事', icon: Icons.add, onPressed: onAddTodo),
          ]),
          for (final row in rows) ...[
            _HomeTodoRow(
                key: _asInt(row['id']) > 0
                    ? ValueKey('home_todo_${row['id']}')
                    : null,
                id: _asInt(row['id']),
                title: _asString(row['title']),
                dueDate: _asString(row['dueDate']),
                onToggle: onTodoToggle == null
                    ? null
                    : (complete) => onTodoToggle!(_asInt(row['id']), complete)),
            Divider(height: 1, color: context.lgSeparator.withAlpha(90)),
          ],
          if (rows.isEmpty)
            TextButton(
                style: rebuildTextStyle(context),
                onPressed: loading ? null : onTodoTap,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        loading
                            ? '正在加载待办…'
                            : !available
                                ? '待办暂时没能读取，请下拉重试'
                                : total > 0
                                    ? '小事都完成了，今天从容一点'
                                    : '记下一件今天想做的小事',
                        style: TextStyle(
                            fontSize: 13, color: context.lgTextSecondary)))),
          if (feed['hasActiveOrder'] == true)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _CareEntry(
                    emoji: '🍳',
                    title: '情侣厨房',
                    badge: feed['statusLabel']?.toString() ?? '这一餐',
                    badgeTone: _CareBadgeTone.neutral,
                    subtitle: feed['title']?.toString(),
                    onTap: onFeedingTap)),
        ]);
  }
}

/// 清单条目（首页"今天要照顾的事"）
enum _CareBadgeTone { ok, warn, neutral }

class _CareEntry extends StatelessWidget {
  final String? emoji;
  final String title;
  final String badge;
  final _CareBadgeTone badgeTone;
  final String? subtitle;
  final VoidCallback onTap;

  const _CareEntry({
    this.emoji,
    required this.title,
    required this.badge,
    required this.badgeTone,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // v4.0 状态徽章语义浅底（深色走 primarySoftDark+浅 fg，参考图⑥）
    final (badgeBg, badgeFg) = switch (badgeTone) {
      _CareBadgeTone.ok => (context.lgSoftGreenBg, context.lgSoftGreenText),
      _CareBadgeTone.warn => (context.lgSoftYellowBg, context.lgSoftYellowText),
      _CareBadgeTone.neutral => (context.lgBadgeBg, context.lgBadgeText),
    };
    return PressableScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.lgCard,
            borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
            border: Border.all(color: context.lgCardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.lgPrimarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: emoji != null
                      ? Text(emoji!, style: const TextStyle(fontSize: 20))
                      : Icon(Icons.star_rounded,
                          size: 20, color: context.lgInk),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: context.lgTextPrimary)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: context.lgTextMuted)),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge,
                    style: TextStyle(
                        color: badgeFg,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.lgTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// TA 的近况：让"对方"在首页出现
class _PartnerRecentCard extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onTapCooking;
  final ValueChanged<AppSection>? onNavigateToTab;

  const _PartnerRecentCard({
    required this.items,
    required this.onTapCooking,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final visible = items.take(2).toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 点击优先跳最近动态对应页；无动态进手账
        final first =
            visible.isNotEmpty ? visible.first['type']?.toString() : null;
        if (first == 'cooking') {
          onTapCooking();
        } else if (first == 'travel') {
          onNavigateToTab?.call(AppSection.travel);
        }
      },
      child: Container(
        key: const ValueKey('home_partner_recent'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // v4.0：1px 细线替代阴影（参考图②）
        decoration: BoxDecoration(
          color: context.lgPaper,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
          border: Border.all(color: context.lgCardBorder),
        ),
        child: visible.isEmpty
            ? Row(
                children: [
                  Icon(Icons.favorite_outline,
                      size: 15, color: context.lgEmotion),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TA 还没有新动态，去记一道今天的菜吧',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.lgTextSecondary,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_rounded,
                          size: 13, color: context.lgEmotion),
                      const SizedBox(width: 5),
                      Text(
                        'TA 的近况',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: context.lgEmotion,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  for (final item in visible) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Icon(
                            item['type'] == 'cooking'
                                ? Icons.restaurant_rounded
                                : item['type'] == 'travel'
                                    ? Icons.map_rounded
                                    : Icons.quiz_outlined,
                            size: 13,
                            color: context.lgTextMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['text']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.lgTextPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _MemoryTicket extends StatelessWidget {
  final Map<String, dynamic>? memory;
  final VoidCallback onTap;

  const _MemoryTicket({
    required this.memory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = _localizedMemoryTitle(
      _asString(memory?['title'], fallback: '留一张回忆票根'),
    );
    final eventDate = _asString(memory?['eventDate'], fallback: '');
    final location = _asString(memory?['location'], fallback: '');
    final imageUrl = _memoryImageUrl(memory);
    final dateLabel = eventDate.isEmpty ? '' : _relativeDayLabel(eventDate);

    return LoveTicketCard(
      key: const ValueKey('home_memory_ticket'),
      color: context.lgPaperWarm,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _memPlaceholder(context))
                  : _memPlaceholder(context),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: context.lgTextPrimary)),
                SizedBox(height: 3),
                Text(
                  [
                    if (dateLabel.isNotEmpty) dateLabel,
                    if (location.isNotEmpty) location,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.lgTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.lgInk,
              side: BorderSide(color: context.lgInk),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text('查看回忆',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _memPlaceholder(BuildContext context) => ColoredBox(
      color: context.lgPrimarySoft,
      child: Icon(Icons.auto_stories_outlined,
          size: 28, color: context.lgTextSecondary));
}

Map<String, dynamic> _typedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  return const {};
}

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _localizedMemoryTitle(String value) {
  const travelPrefix = 'Travel check-in:';
  if (value.startsWith(travelPrefix)) {
    return value.substring(travelPrefix.length).trim();
  }
  const moodMap = {
    'excited': '那天很期待',
    'happy': '那天很开心',
    'sad': '那天有点低落',
    'angry': '那天有点生气',
    'tired': '那天有点累',
    'calm': '那天很平静',
    'romantic': '那天很浪漫',
    'neutral': '那天很普通',
  };
  return moodMap[value.toLowerCase()] ?? value;
}

String _memoryImageUrl(Map<String, dynamic>? memory) {
  if (memory == null) return '';
  const keys = [
    'imageUrl',
    'image_url',
    'photoUrl',
    'photo_url',
    'cover',
    'coverUrl',
  ];
  for (final key in keys) {
    final value = memory[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? _parseDate(String value) {
  if (value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

String _relativeDayLabel(String value) {
  final date = _parseDate(value);
  if (date == null) return '日期未记录';
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day)
      .difference(DateTime(date.year, date.month, date.day))
      .inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff > 1 && diff < 30) return '$diff天前';
  return '${date.year}年${date.month}月${date.day}日';
}

/// The provider owns the pending state so failures never leave a checked row.
class _HomeTodoRow extends StatelessWidget {
  final int id;
  final String title;
  final String dueDate;
  final void Function(bool complete)? onToggle;
  const _HomeTodoRow(
      {super.key,
      required this.id,
      required this.title,
      required this.dueDate,
      this.onToggle});

  @override
  Widget build(BuildContext context) {
    final saving =
        context.select<HomeProvider, bool>((home) => home.isTodoSaving(id));
    return Semantics(
        button: true,
        enabled: id > 0 && !saving && onToggle != null,
        label: saving ? '正在完成：$title' : '完成：$title',
        excludeSemantics: true,
        child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: id <= 0 || saving || onToggle == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onToggle!(true);
                  },
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(children: [
                  SizedBox(
                      width: 24,
                      height: 24,
                      child: saving
                          ? const Padding(
                              padding: EdgeInsets.all(3),
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(Icons.check_box_outline_blank,
                              color: context.lgTextSecondary, size: 23)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14, color: context.lgTextPrimary))),
                  if (dueDate.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(dueDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: context.lgTextSecondary))),
                  ],
                ]))));
  }
}

/// W5 弹药库 7.3/10.2：确定性挑选「N 年前的今天」（年最远优先→照片优先→id 升序；
/// photo_date 空用 created_at 兜底；候选年 ≥ 当年跳过）
Map<String, dynamic>? pickMemoryToday(
    List<Map<String, dynamic>> photos, List<TravelSpot> spots, DateTime now) {
  DateTime? parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.length < 10) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T')) ??
        DateTime.tryParse(s.substring(0, 10));
  }

  final candidates = <Map<String, dynamic>>[];
  for (final p in photos) {
    final d = parseDate(p['photo_date'] ?? p['created_at']);
    if (d == null || d.year >= now.year || !d.isBefore(now)) continue;
    if (d.month != now.month || d.day != now.day) continue;
    candidates.add({
      'type': 'photo',
      'date': d,
      'id': (p['id'] as num?)?.toInt() ?? 0,
      'title': p['description']?.toString() ?? '',
    });
  }
  for (final s in spots) {
    final d = parseDate(s.visitedDate);
    if (d == null || d.year >= now.year || !d.isBefore(now)) continue;
    if (d.month != now.month || d.day != now.day) continue;
    candidates.add({
      'type': 'travel',
      'date': d,
      'id': s.id,
      'title': s.name,
    });
  }
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    final ya = (a['date'] as DateTime).year;
    final yb = (b['date'] as DateTime).year;
    if (ya != yb) return ya.compareTo(yb);
    final pa = a['type'] == 'photo' ? 0 : 1;
    final pb = b['type'] == 'photo' ? 0 : 1;
    if (pa != pb) return pa.compareTo(pb);
    return (a['id'] as int).compareTo(b['id'] as int);
  });
  final c = candidates.first;
  final years = now.year - (c['date'] as DateTime).year;
  return {
    'type': c['type'],
    'years': years,
    'id': c['id'],
    'title': c['title'],
  };
}
