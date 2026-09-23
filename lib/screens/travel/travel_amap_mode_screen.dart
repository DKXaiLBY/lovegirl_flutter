import 'dart:async';
import 'dart:io';

import 'package:amap_flutter_base/amap_flutter_base.dart' show LatLng;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/travel_form_screen.dart';
import 'package:lovegirl_flutter/screens/travel/travel_ticket_screen.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/widgets/travel_map_widget.dart';

class TravelAmapModeScreen extends StatefulWidget {
  /// embedded=true：作为旅行页主视图内嵌（隐藏返回钮、返回动作交给外部 tab 切换）
  const TravelAmapModeScreen({super.key, this.embedded = false, this.onExit});

  final bool embedded;
  final VoidCallback? onExit;

  @override
  State<TravelAmapModeScreen> createState() => _TravelAmapModeScreenState();
}

class _TravelAmapModeScreenState extends State<TravelAmapModeScreen> {
  static const MethodChannel _deviceChannel = MethodChannel('lovegirl/device');

  bool get _embedded => widget.embedded;

  final GlobalKey<TravelMapWidgetState> _mapKey = GlobalKey();
  Timer? _mountTimer;
  Timer? _retryTimer;
  bool _checkingNativeSupport = true;
  bool _mountMap = false;
  bool _showMountRetry = false;
  bool _mapReportedReady = false;
  bool _unsupportedNativeMap = false;
  String? _unsupportedReason;

  bool _introDismissed = false;

  Future<void> _loadIntroDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _introDismissed = prefs.getBool('amap_intro_dismissed') ?? false);
  }

  Future<void> _dismissIntro() async {
    setState(() => _introDismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('amap_intro_dismissed', true);
  }

  /// 一键把全部有坐标地点串成路线预览（介绍卡入口）
  Future<void> _previewRouteAll() async {
    final provider = context.read<TravelProvider>();
    final validSpots = provider.mapSpots.where(_hasValidCoordinate).toList();
    if (validSpots.length < 2) {
      _showFloatingMessage('至少还需要一个有坐标的地点，才能把路线串起来。');
      return;
    }
    validSpots.sort((a, b) {
      final dayCompare = (a.routeDay ?? 999).compareTo(b.routeDay ?? 999);
      if (dayCompare != 0) return dayCompare;
      final orderCompare = (a.routeOrder ?? 999).compareTo(b.routeOrder ?? 999);
      if (orderCompare != 0) return orderCompare;
      return a.name.compareTo(b.name);
    });
    await provider.previewRoute(validSpots, 'walking');
    if (!mounted) return;
    if (provider.activeRoute != null && provider.activeRoute!.path.length >= 2) {
      _mapKey.currentState?.fitBounds();
      _showFloatingMessage('已按当前地点顺序生成路线预览。');
    } else {
      _showFloatingMessage(provider.routeError ?? '路线预览暂时不可用，请稍后再试。');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadIntroDismissed();
    _initNativeMapSupport();
  }

  @override
  void dispose() {
    _mountTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initNativeMapSupport() async {
    final result = await _checkNativeMapSupport();
    if (!mounted) return;
    setState(() {
      _checkingNativeSupport = false;
      _unsupportedNativeMap = result.unsupported;
      _unsupportedReason = result.message;
    });
    if (!result.unsupported) {
      _scheduleMapMount();
    }
  }

  Future<_NativeMapSupportResult> _checkNativeMapSupport() async {
    if (!Platform.isAndroid) {
      return const _NativeMapSupportResult.supported();
    }

    try {
      final abis =
          await _deviceChannel.invokeListMethod<String>('getSupportedAbis') ??
              const <String>[];
      final normalized =
          abis.map((abi) => abi.toLowerCase()).toList(growable: false);
      if (normalized.any((abi) => abi.startsWith('x86'))) {
        return const _NativeMapSupportResult.unsupported(
          '当前设备是模拟器架构，高德原生真地图建议在安卓真机上查看。',
        );
      }
    } catch (_) {
      // 设备探测失败时继续尝试挂载原生地图，让插件自己给出结果。
    }

    return const _NativeMapSupportResult.supported();
  }

  void _scheduleMapMount() {
    _mountTimer?.cancel();
    _retryTimer?.cancel();
    if (mounted) {
      setState(() {
        _mountMap = false;
        _showMountRetry = false;
        _mapReportedReady = false;
      });
    }

    _mountTimer = Timer(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _mountMap = true);
      _retryTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted || !_mountMap || _mapReportedReady) return;
        setState(() => _showMountRetry = true);
      });
    });
  }

  void _handleMapReady() {
    _retryTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _mapReportedReady = true;
      _showMountRetry = false;
    });
  }

  Future<void> _openAddSpot() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TravelFormScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      await context.read<TravelProvider>().refreshAll();
    }
  }

  void _openSpotSheet(TravelSpot spot) {
    context.read<TravelProvider>().highlightSpot(spot.id);
    _mapKey.currentState?.animateToSpot(spot);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpotSheet(
        spot: spot,
        onAddRoute: () => _previewRouteFromSpot(spot),
        onGenerateTicket: () => _openTravelTicket(spot),
        onRecordExpense: () => _showExpenseHint(spot),
        onEdit: () async {
          Navigator.of(context).pop();
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TravelFormScreen(spot: spot)),
          );
          if (!mounted) return;
          if (result == true) {
            await context.read<TravelProvider>().refreshAll();
          }
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        context.read<TravelProvider>().highlightSpot(null);
      }
    });
  }

  Future<void> _previewRouteFromSpot(TravelSpot spot) async {
    Navigator.of(context).pop();
    final provider = context.read<TravelProvider>();
    final validSpots = provider.mapSpots.where(_hasValidCoordinate).toList();
    if (validSpots.length < 2) {
      _showFloatingMessage('至少还需要一个有坐标的地点，才能把路线串起来。');
      return;
    }

    validSpots.sort((a, b) {
      if (a.id == spot.id) return -1;
      if (b.id == spot.id) return 1;
      final dayCompare = (a.routeDay ?? 999).compareTo(b.routeDay ?? 999);
      if (dayCompare != 0) return dayCompare;
      final orderCompare = (a.routeOrder ?? 999).compareTo(b.routeOrder ?? 999);
      if (orderCompare != 0) return orderCompare;
      return a.name.compareTo(b.name);
    });

    await provider.previewRoute(validSpots, 'walking');
    if (!mounted) return;
    final activeRoute = provider.activeRoute;
    if (activeRoute != null && activeRoute.path.length >= 2) {
      _mapKey.currentState?.fitBounds();
      _showFloatingMessage('已按当前地点顺序生成路线预览。');
    } else {
      _showFloatingMessage(provider.routeError ?? '路线预览暂时不可用，请稍后再试。');
    }
  }

  void _openTravelTicket(TravelSpot spot) {
    Navigator.of(context).pop();
    if (spot.status != 'visited') {
      _showFloatingMessage('“${spot.name}”打卡后，就可以生成正式旅行票根。');
      return;
    }

    final provider = context.read<TravelProvider>();
    final visitedSpots =
        provider.spots.where((item) => item.status == 'visited').toList();
    if (visitedSpots.isEmpty) {
      _showFloatingMessage('先完成一次打卡，再生成正式旅行票根。');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TravelTicketScreen(
          visitedSpots: visitedSpots,
          stats: provider.computedStats,
        ),
      ),
    );
  }

  void _showExpenseHint(TravelSpot spot) {
    Navigator.of(context).pop();
    _showFloatingMessage('“${spot.name}”的花费会和记账联动；当前先在地点编辑里记录预算。');
  }

  void _showFloatingMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleMapLongPress(LatLng position) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已记录位置 ${position.latitude.toStringAsFixed(4)}, '
          '${position.longitude.toStringAsFixed(4)}，可以继续补充地点信息。',
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: '新增地点', onPressed: _openAddSpot),
      ),
    );
  }

  bool _hasValidCoordinate(TravelSpot spot) {
    return spot.lat.isFinite &&
        spot.lng.isFinite &&
        spot.lat >= -90 &&
        spot.lat <= 90 &&
        spot.lng >= -180 &&
        spot.lng <= 180 &&
        !(spot.lat == 0 && spot.lng == 0);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TravelProvider>(
      builder: (context, provider, _) {
        final validMapSpots =
            provider.mapSpots.where(_hasValidCoordinate).toList();
        final missingCoordinateOnly =
            provider.mapSpots.isNotEmpty && validMapSpots.isEmpty;

        if (provider.mapSpots.isEmpty) {
          return _EmptyMapScaffold(
            onBack: _embedded
                ? (widget.onExit ?? () => Navigator.of(context).pop())
                : () => Navigator.of(context).pop(),
            onAddSpot: _openAddSpot,
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: _buildMapSurface(provider, validMapSpots),
              ),
              if (_showMountRetry && !_unsupportedNativeMap)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 72,
                  left: 16,
                  right: 16,
                  child: _MapRetryBanner(
                    onRetry: _scheduleMapMount,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              if (missingCoordinateOnly)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 72,
                  left: 16,
                  right: 16,
                  child: const _MissingCoordinateBanner(),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_introDismissed)
                        _TopOverlay(
                          spotCount: provider.mapSpots.length,
                          hasRoute: provider.activeRoute != null,
                          unsupportedReason: _unsupportedReason,
                          showBack: !_embedded,
                          onBack: () => Navigator.of(context).pop(),
                          onDismiss: _dismissIntro,
                          onFitSpots: () => _mapKey.currentState?.fitBounds(),
                          onPreviewRoute: _previewRouteAll,
                        ),
                      const SizedBox(height: 14),
                      if (!_unsupportedNativeMap) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _MapActionRail(
                            onCycleStyle: () =>
                                _mapKey.currentState?.cycleMapStyle(),
                            onFitBounds: () =>
                                _mapKey.currentState?.fitBounds(),
                            onLocateMe: () => _mapKey.currentState?.locateMe(),
                          ),
                        ),
                      ],
                      const Spacer(),
                      _BottomOverlay(
                        activeRoute: provider.activeRoute,
                        spotCount: provider.mapSpots.length,
                        onAddSpot: _openAddSpot,
                        onFitBounds: () => _mapKey.currentState?.fitBounds(),
                        onClearRoute: provider.clearActiveRoute,
                        onBack: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapSurface(
    TravelProvider provider,
    List<TravelSpot> validMapSpots,
  ) {
    if (_checkingNativeSupport) {
      return _MapMountPlaceholder();
    }
    if (_unsupportedNativeMap) {
      return const _UnsupportedMapPlaceholder();
    }
    if (!_mountMap) {
      return _MapMountPlaceholder();
    }
    return TravelMapWidget(
      key: _mapKey,
      spots: validMapSpots,
      allSpots: provider.spots,
      currentUserId: context.read<AuthProvider>().userId,
      highlightedId: provider.highlightedId,
      routes: provider.routes,
      activeRoute: provider.activeRoute,
      onMapReady: _handleMapReady,
      onMarkerTap: _openSpotSheet,
      onLongPress: _handleMapLongPress,
    );
  }
}

class _EmptyMapScaffold extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onAddSpot;

  const _EmptyMapScaffold({
    required this.onBack,
    required this.onAddSpot,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopOverlay(
                        spotCount: 0,
                        hasRoute: false,
                        onBack: onBack,
                        onDismiss: () {},
                        onFitSpots: () {},
                        onPreviewRoute: () {},
                      ),
              SizedBox(height: 16),
              Expanded(
                child: LoveTicketCard(
                  color: const Color(0xFFFFFCF8),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: context.lgSecondarySoft,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                LoveStickerIcon(
                                  icon: Icons.map_outlined,
                                  color: LoveGirlTheme.secondary,
                                  size: 42,
                                  iconSize: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '先放一个想去的地方进来',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: context.lgTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              '真地图适合出发前看顺不顺路，也适合旅行时边走边看。现在还没有地点，先新增一个地点会更顺手。',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: context.lgTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MapHelpBanner(onAddSpot: onAddSpot, onBack: onBack),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onBack,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.lgTextPrimary,
                                side: BorderSide(
                                  color: context.lgSeparator.withAlpha(180),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('回到预览'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onAddSpot,
                              icon: const Icon(
                                Icons.add_location_alt_rounded,
                                size: 18,
                              ),
                              label: const Text('新增地点'),
                              style: FilledButton.styleFrom(
                                backgroundColor: LoveGirlTheme.secondary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding:
                                    EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopOverlay extends StatelessWidget {
  final int spotCount;
  final bool hasRoute;
  final String? unsupportedReason;
  final VoidCallback onBack;
  final VoidCallback onDismiss;
  final VoidCallback onFitSpots;
  final VoidCallback onPreviewRoute;

  /// embedded 内嵌模式：隐藏返回圆钮（返回动作由外部底部 tab 承担）
  final bool showBack;

  const _TopOverlay({
    required this.spotCount,
    required this.hasRoute,
    this.unsupportedReason,
    required this.onBack,
    required this.onDismiss,
    required this.onFitSpots,
    required this.onPreviewRoute,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final summaryText =
        hasRoute ? '已经把想去的地方串起来了，出发时边走边看会更顺。' : '点一个地点看详情，也可以继续在地图上规划路线。';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack) ...[
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onTap: onBack,
          ),
          SizedBox(width: 12),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(232),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(120)),
              boxShadow: LoveGirlTheme.cardShadow(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '旅行地图',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: context.lgTextPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onDismiss,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: context.lgTextMuted),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  summaryText,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: context.lgTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: onFitSpots,
                      child: LovePill(
                        text: '$spotCount 个地点 · 查看全局',
                        color: LoveGirlTheme.secondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: onPreviewRoute,
                      child: LovePill(
                        text: hasRoute ? '已加载路线 · 查看' : '一键串成路线',
                        color: hasRoute
                            ? context.lgInk
                            : context.lgTextMuted,
                      ),
                    ),
                  ],
                ),
                if (unsupportedReason?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  _SmallNotice(text: unsupportedReason!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MapActionRail extends StatelessWidget {
  final VoidCallback onCycleStyle;
  final VoidCallback onFitBounds;
  final VoidCallback onLocateMe;

  const _MapActionRail({
    required this.onCycleStyle,
    required this.onFitBounds,
    required this.onLocateMe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RailButton(
            icon: Icons.layers_rounded, label: '标准地图', onTap: onCycleStyle),
        const SizedBox(height: 10),
        _RailButton(
            icon: Icons.my_location_rounded, label: '定位', onTap: onLocateMe),
        const SizedBox(height: 10),
        _RailButton(
            icon: Icons.alt_route_rounded, label: '路线', onTap: onFitBounds),
      ],
    );
  }
}

class _BottomOverlay extends StatelessWidget {
  final TravelRoute? activeRoute;
  final int spotCount;
  final VoidCallback onAddSpot;
  final VoidCallback onFitBounds;
  final VoidCallback onClearRoute;
  final VoidCallback onBack;

  const _BottomOverlay({
    required this.activeRoute,
    required this.spotCount,
    required this.onAddSpot,
    required this.onFitBounds,
    required this.onClearRoute,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (spotCount == 0) ...[
          _MapHelpBanner(onAddSpot: onAddSpot, onBack: onBack),
          const SizedBox(height: 12),
        ],
        if (activeRoute != null) ...[
          _RouteTicket(route: activeRoute!, onClearRoute: onClearRoute),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAddSpot,
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('新增地点'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: context.lgTextPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onFitBounds,
                icon: const Icon(Icons.fit_screen_rounded, size: 18),
                label: const Text('查看全局'),
                style: FilledButton.styleFrom(
                  backgroundColor: LoveGirlTheme.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteTicket extends StatelessWidget {
  final TravelRoute route;
  final VoidCallback onClearRoute;

  const _RouteTicket({
    required this.route,
    required this.onClearRoute,
  });

  @override
  Widget build(BuildContext context) {
    final title = route.title.isEmpty ? '当前路线' : route.title;
    final meta = [
      if (route.city.isNotEmpty) route.city,
      if (route.spots.isNotEmpty) '${route.spots.length} 个地点',
      if (route.distance != null)
        '${(route.distance! / 1000).toStringAsFixed(1)} 公里',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(238),
        borderRadius: BorderRadius.circular(26),
        boxShadow: LoveGirlTheme.cardShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.lgInk.withAlpha(18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.alt_route_rounded,
              color: context.lgInk,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.lgTextPrimary,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.lgTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(onPressed: onClearRoute, child: const Text('清除')),
        ],
      ),
    );
  }
}

class _SpotSheet extends StatelessWidget {
  final TravelSpot spot;
  final VoidCallback onAddRoute;
  final VoidCallback onGenerateTicket;
  final VoidCallback onRecordExpense;
  final VoidCallback onEdit;

  const _SpotSheet({
    required this.spot,
    required this.onAddRoute,
    required this.onGenerateTicket,
    required this.onRecordExpense,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final notes = [
      if ((spot.noteMine ?? '').isNotEmpty) '我：${spot.noteMine}',
      if ((spot.noteHer ?? '').isNotEmpty) '她：${spot.noteHer}',
      if ((spot.note ?? '').isNotEmpty) spot.note!,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LoveTicketCard(
          color: const Color(0xFFFFFCF8),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.lgSeparator,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SpotCover(spot: spot),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusBadge(status: spot.status),
                              if (spot.editedByBoth)
                                LovePill(
                                  text: '我们都编辑',
                                  icon: Icons.favorite_rounded,
                                  color: context.lgInk,
                                ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            spot.name.isEmpty ? '未命名地点' : spot.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: context.lgTextPrimary,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            _spotAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: context.lgTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                _InfoGrid(spot: spot),
                if (notes.isNotEmpty) ...[
                  SizedBox(height: 12),
                  LovePaper(
                    elevated: false,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '想对她说',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: context.lgTextMuted,
                          ),
                        ),
                        SizedBox(height: 8),
                        ...notes.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              note,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: context.lgTextPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SheetButton(
                      icon: Icons.alt_route_rounded,
                      label: '加入路线',
                      onPressed: onAddRoute,
                      outlined: true,
                    ),
                    _SheetButton(
                      icon: Icons.confirmation_number_outlined,
                      label: '生成票根',
                      onPressed: onGenerateTicket,
                    ),
                    _SheetButton(
                      icon: Icons.edit_note_rounded,
                      label: '记一笔花费',
                      onPressed: onRecordExpense,
                      outlined: true,
                    ),
                    _SheetButton(
                      icon: Icons.edit_location_alt_outlined,
                      label: '编辑地点',
                      onPressed: onEdit,
                      outlined: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _spotAddress {
    if (spot.address.isNotEmpty && spot.city.isNotEmpty) {
      return '${spot.city} · ${spot.address}';
    }
    if (spot.address.isNotEmpty) return spot.address;
    if (spot.city.isNotEmpty) return spot.city;
    return '还没有填写地址';
  }
}

class _InfoGrid extends StatelessWidget {
  final TravelSpot spot;

  const _InfoGrid({required this.spot});

  @override
  Widget build(BuildContext context) {
    final items = <_InfoItem>[
      _InfoItem(
        Icons.wb_sunny_outlined,
        '天气',
        spot.weather?.isNotEmpty == true ? spot.weather! : '待补充',
      ),
      _InfoItem(
        Icons.event_rounded,
        '计划日期',
        spot.plannedDate?.isNotEmpty == true
            ? spot.plannedDate!
            : (spot.visitedDate?.isNotEmpty == true
                ? spot.visitedDate!
                : '待安排'),
      ),
      _InfoItem(
        Icons.account_balance_wallet_outlined,
        '预计预算',
        spot.budget != null ? '¥ ${spot.budget!.toStringAsFixed(0)}' : '待记录',
      ),
      _InfoItem(
        Icons.group_rounded,
        '共同编辑',
        spot.editedByBoth
            ? '我们都编辑'
            : (spot.creatorNickname?.isNotEmpty == true
                ? spot.creatorNickname!
                : '待补充'),
      ),
      if (spot.transportation?.isNotEmpty == true)
        _InfoItem(Icons.directions_rounded, '交通方式', spot.transportation!),
      if (spot.businessHours?.isNotEmpty == true)
        _InfoItem(Icons.schedule_rounded, '营业时间', spot.businessHours!),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 78,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemBuilder: (context, index) => _InfoCell(item: items[index]),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem(this.icon, this.label, this.value);
}

class _InfoCell extends StatelessWidget {
  final _InfoItem item;

  const _InfoCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EE),
        border: Border.all(color: context.lgSeparator.withAlpha(170)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 17, color: context.lgTextMuted),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.lgTextMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  item.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: context.lgTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotCover extends StatelessWidget {
  final TravelSpot spot;

  const _SpotCover({required this.spot});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 86,
      decoration: BoxDecoration(
        color: LoveGirlTheme.secondary.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.lgSeparator.withAlpha(180)),
      ),
      child: Center(
        child: Text(
          spot.emoji.isEmpty ? '📍' : spot.emoji,
          style: const TextStyle(fontSize: 34),
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        SizedBox(width: 8),
        Text(label),
      ],
    );
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: LoveGirlTheme.secondary,
          side: const BorderSide(color: LoveGirlTheme.secondary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: context.lgInk,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      child: child,
    );
  }
}

class _MapMountPlaceholder extends StatelessWidget {
  const _MapMountPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(232),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          key: ValueKey('travel_amap_placeholder'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              '正在打开高德地图…',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.lgTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapRetryBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _MapRetryBanner({
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      title: '地图加载有点慢',
      text: '如果一直停在这里，可以先重试一次；还是不行就回到预览地图继续安排。',
      actions: [
        OutlinedButton(onPressed: onBack, child: const Text('回到预览')),
        FilledButton(onPressed: onRetry, child: const Text('重新打开')),
      ],
    );
  }
}

class _MissingCoordinateBanner extends StatelessWidget {
  const _MissingCoordinateBanner();

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      title: '这些地点还没有地图坐标',
      text: '地点信息已经保存了，但缺少经纬度，真地图暂时无法把它们标出来。回到预览页补一下地址或坐标会更省心。',
    );
  }
}

class _MapHelpBanner extends StatelessWidget {
  final VoidCallback? onAddSpot;
  final VoidCallback? onBack;

  const _MapHelpBanner({
    required this.onAddSpot,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      title: '真地图现在还比较空',
      text: '先新增一个地点，就能开始标记路线；如果底图一直发黑，也可以回到预览地图继续安排。',
      actions: [
        if (onBack != null)
          OutlinedButton(onPressed: onBack, child: const Text('回到预览')),
        if (onAddSpot != null)
          FilledButton(onPressed: onAddSpot, child: const Text('新增地点')),
      ],
    );
  }
}

class _UnsupportedMapPlaceholder extends StatelessWidget {
  const _UnsupportedMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161616),
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.16,
              child: CustomPaint(
                painter: _FallbackMapPainter(routeColor: context.lgInk)),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withAlpha(28)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: Colors.white70,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '模拟器预览',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackMapPainter extends CustomPainter {
  final Color routeColor;

  _FallbackMapPainter({required this.routeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final routePaint = Paint()
      ..color = routeColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var x = -size.width; x < size.width * 1.8; x += 88) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.width * 0.35, size.height),
        roadPaint,
      );
    }
    for (var y = 80.0; y < size.height; y += 96) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - size.width * 0.12),
        roadPaint,
      );
    }

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.82)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.60,
        size.width * 0.64,
        size.height * 0.62,
        size.width * 0.76,
        size.height * 0.36,
      )
      ..cubicTo(
        size.width * 0.84,
        size.height * 0.18,
        size.width * 0.64,
        size.height * 0.14,
        size.width * 0.55,
        size.height * 0.24,
      );
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String text;
  final List<Widget> actions;

  const _NoticeCard({
    required this.title,
    required this.text,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(236),
        borderRadius: BorderRadius.circular(18),
        boxShadow: LoveGirlTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.lgTextPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: context.lgTextSecondary,
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(height: 10),
            Row(
              children: actions
                  .map((action) => Expanded(child: action))
                  .expand((widget) => [widget, const SizedBox(width: 10)])
                  .toList()
                ..removeLast(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallNotice extends StatelessWidget {
  final String text;

  const _SmallNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.lgInk.withAlpha(48)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: context.lgTextSecondary,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(235),
            shape: BoxShape.circle,
            boxShadow: LoveGirlTheme.cardShadow(),
          ),
          child: Icon(icon, color: context.lgTextPrimary),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(238),
            shape: BoxShape.circle,
            boxShadow: LoveGirlTheme.cardShadow(),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: context.lgTextPrimary),
              SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: context.lgTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;

    switch (status) {
      case 'visited':
        text = '已打卡';
        color = LoveGirlTheme.accent;
        break;
      case 'planned':
        text = '计划中';
        color = LoveGirlTheme.secondary;
        break;
      case 'wish':
      default:
        text = '想去';
        color = context.lgInk;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _NativeMapSupportResult {
  final bool unsupported;
  final String? message;

  const _NativeMapSupportResult.supported()
      : unsupported = false,
        message = null;

  const _NativeMapSupportResult.unsupported(this.message) : unsupported = true;
}
