import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/travel_amap_mode_screen.dart';
import 'package:lovegirl_flutter/screens/travel/travel_form_screen.dart';
import 'package:lovegirl_flutter/screens/travel/travel_ticket_screen.dart';
import 'package:lovegirl_flutter/widgets/travel_photo_grid.dart';
import 'package:lovegirl_flutter/widgets/city_picker.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/widgets/lovegirl_ui.dart';
import 'package:lovegirl_flutter/widgets/illus_image.dart';

String _travelDisplayText(String? value, String fallback) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return fallback;
  if (text.contains('\uFFFD')) return fallback;

  final questionCount = RegExp(r'[\?？]').allMatches(text).length;
  if (questionCount == 0) return text;

  final compact = text.replaceAll(RegExp(r'[\s\?？.,，。:：;；\-_\\/]+'), '');
  if (compact.isEmpty) return fallback;

  final runeCount = text.runes.length;
  if (questionCount >= 3 && questionCount >= runeCount / 2) return fallback;

  return text;
}

class TravelMainScreen extends StatefulWidget {
  const TravelMainScreen({super.key});

  @override
  State<TravelMainScreen> createState() => _TravelMainScreenState();
}

class _TravelMainScreenState extends State<TravelMainScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _showSearch = false;
  int _viewIndex = 0; // 0=地图 1=清单 2=票根
  late AnimationController _fabAnimCtrl;

  @override
  void initState() {
    super.initState();
    _fabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TravelProvider>().refreshAll();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _fabAnimCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      context.read<TravelProvider>().setSearchQuery(value.trim());
    });
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchCtrl.clear();
        context.read<TravelProvider>().setSearchQuery('');
      }
    });
  }

  void _setView(int index) {
    if (_viewIndex == index) return;
    setState(() => _viewIndex = index);
  }

  void _onMarkerTap(TravelSpot spot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SpotDetailSheet(
        spot: spot,
        onAddRoute: () => _previewRouteFromSpot(ctx, spot),
        onGenerateTicket: () => _openTravelTicketFromSpot(ctx, spot),
        onRecordExpense: () => _showExpenseHint(ctx, spot),
        onEdit: () async {
          Navigator.pop(ctx);
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TravelFormScreen(spot: spot),
            ),
          );
          if (!mounted) return;
          if (result == true) {
            context.read<TravelProvider>().refreshAll();
          }
        },
        onDelete: () async {
          Navigator.pop(ctx);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text('\u5220\u9664\u5730\u70b9'),
              content: Text(
                '确定要删除“${_travelDisplayText(spot.name, '这个地点')}”吗？',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('\u53d6\u6d88'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text('\u5220\u9664',
                      style: TextStyle(color: LoveGirlTheme.red)),
                ),
              ],
            ),
          );
          if (confirm == true && mounted) {
            await context.read<TravelProvider>().deleteSpot(spot.id);
          }
        },
      ),
    );
  }

  Future<void> _previewRouteFromSpot(
    BuildContext sheetContext,
    TravelSpot spot,
  ) async {
    Navigator.pop(sheetContext);
    await _previewRouteForSpot(spot);
  }

  Future<void> _previewRouteForSpot(TravelSpot spot) async {
    final provider = context.read<TravelProvider>();
    final validSpots =
        provider.filteredSpots.where(_hasValidCoordinate).toList();
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
    _showFloatingMessage(
      provider.activeRoute != null
          ? '已按当前地点顺序生成路线预览。'
          : (provider.routeError ?? '路线预览暂时不可用，请稍后再试。'),
    );
  }

  void _openTravelTicketFromSpot(BuildContext sheetContext, TravelSpot spot) {
    Navigator.pop(sheetContext);
    _openTravelTicketForSpot(spot);
  }

  void _openTravelTicketForSpot(TravelSpot spot) {
    final spotName = _travelDisplayText(spot.name, '这个地点');
    if (spot.status != 'visited') {
      _showFloatingMessage('“$spotName”打卡后，就可以生成正式旅行票根。');
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

  void _showExpenseHint(BuildContext sheetContext, TravelSpot spot) {
    Navigator.pop(sheetContext);
    _showExpenseHintForSpot(spot);
  }

  void _showExpenseHintForSpot(TravelSpot spot) {
    final spotName = _travelDisplayText(spot.name, '这个地点');
    _showFloatingMessage('“$spotName”的花费会和记账联动；当前先在地点编辑里记录预算。');
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
        // 三视图：地图（全屏高德）/ 地点清单 / 票根回忆；底部悬浮 tab 切换
        return Scaffold(
          backgroundColor: context.lgBg,
          body: Stack(
            children: [
              IndexedStack(
                index: _viewIndex,
                children: [
                  TravelAmapModeScreen(
                      embedded: true, onExit: () => _setView(1)),
                  _buildListPage(provider),
                  _buildTicketPage(provider),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: _TravelViewTabs(
                  index: _viewIndex,
                  onChanged: _setView,
                ),
              ),
            ],
          ),
          floatingActionButton: _viewIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final travelProvider = context.read<TravelProvider>();
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TravelFormScreen(),
                      ),
                    );
                    if (!mounted) return;
                    if (result == true) {
                      travelProvider.refreshAll();
                    }
                  },
                  backgroundColor: context.lgInk,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: const Text('记一个地点',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                )
              : null,
        );
      },
    );
  }

  /// 清单视图：搜索 / 筛选排序 / 地点列表（地图已独立为全屏主视图）
  Widget _buildListPage(TravelProvider provider) {
    return LovePage(
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: () => provider.refreshAll(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(provider)),
            if (_showSearch) SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildFilterAndSort(provider)),
            if (provider.loading && provider.spots.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.hasError && provider.spots.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildError(provider),
              )
            else if (provider.filteredSpots.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmpty(provider),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final spot = provider.filteredSpots[index];
                      return Dismissible(
                        key: ValueKey('travel_spot_${spot.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            color: LoveGirlTheme.red,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white, size: 26),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                              title: const Text('删除地点'),
                              content: Text(
                                '确定要删除“${_travelDisplayText(spot.name, '这个地点')}”吗？地图和路线会同步更新。',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('删除',
                                      style: TextStyle(
                                          color: LoveGirlTheme.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) {
                          context.read<TravelProvider>().deleteSpot(spot.id);
                        },
                        child: _SpotCard(
                          spot: spot,
                          index: index,
                          onTap: () => _onMarkerTap(spot),
                        ),
                      );
                    },
                    childCount: provider.filteredSpots.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 票根回忆：已打卡地点回顾 + 生成正式旅行票根
  Widget _buildTicketPage(TravelProvider provider) {
    final visited =
        provider.spots.where((s) => s.status == 'visited').toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
        children: [
          Row(
            children: [
              Text('票根回忆',
                  style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: context.lgTextPrimary)),
              const Spacer(),
              if (visited.isNotEmpty)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.lgInk,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.confirmation_number_rounded,
                      size: 16),
                  label: const Text('生成正式票根',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => TravelTicketScreen(
                                visitedSpots: visited,
                                stats: provider.computedStats,
                              )),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (visited.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: context.lgPaper,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: context.lgSeparator),
              ),
              child: Column(
                children: [
                  IllusImg('empty_ticket', height: 110),
                  const SizedBox(height: 10),
                  Text('还没有票根',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.lgTextPrimary)),
                  const SizedBox(height: 4),
                  Text('去地图打卡第一个地点，票根就会出现在这里',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5, color: context.lgTextSecondary)),
                ],
              ),
            )
          else
            ...visited.map((spot) {
              final date = (spot.visitedDate ?? '').toString();
              final stars = spot.rating ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.lgPaper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.lgSeparator),
                ),
                child: Row(
                  children: [
                    IllusImg('empty_ticket', height: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(spot.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.lgTextPrimary)),
                            const SizedBox(height: 3),
                            Text(
                              [spot.city, if (date.isNotEmpty) date]
                                  .where((x) => x.isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.lgTextMuted),
                            ),
                          ]),
                    ),
                    if (stars > 0)
                      Text('★' * stars,
                          style: TextStyle(
                              fontSize: 11, color: LoveGirlTheme.orange)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeader(TravelProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '\u65c5\u884c\u5730\u56fe',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: context.lgTextPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            Icons.favorite_border_rounded,
            size: 22,
            color: context.lgInk,
          ),
          const Spacer(),
          _MorphIconButton(
            icon: _showSearch ? Icons.close_rounded : Icons.search_rounded,
            active: _showSearch,
            tooltip: _showSearch ? '关闭搜索' : '搜索',
            onTap: _toggleSearch,
          ),
          const SizedBox(width: 8),
          _buildSortMenu(provider),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText:
                '\u641c\u7d22\u5730\u70b9\u3001\u57ce\u5e02\u3001\u5907\u6ce8...',
            hintStyle: TextStyle(
                color: context.lgTextMuted.withAlpha(150), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded,
                color: context.lgInk, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      context.read<TravelProvider>().setSearchQuery('');
                    },
                  )
                : null,
            filled: true,
            fillColor: context.lgCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortMenu(TravelProvider provider) {
    final sortLabels = {
      'default': '\u9ed8\u8ba4',
      'name': '\u540d\u79f0',
      'rating': '\u8bc4\u5206',
      'date': '\u65e5\u671f',
      'city': '\u57ce\u5e02',
    };
    final sortIcons = {
      'default': Icons.sort_rounded,
      'name': Icons.sort_by_alpha_rounded,
      'rating': Icons.star_rounded,
      'date': Icons.calendar_today_rounded,
      'city': Icons.location_city_rounded,
    };

    return PopupMenuButton<String>(
      tooltip: '\u6392\u5e8f',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) => provider.setSortBy(value),
      itemBuilder: (ctx) => sortLabels.entries.map((e) {
        final isActive = provider.sortBy == e.key;
        return PopupMenuItem(
          value: e.key,
          child: Row(
            children: [
              Icon(sortIcons[e.key],
                  size: 18,
                  color: isActive
                      ? context.lgInk
                      : context.lgTextSecondary),
              const SizedBox(width: 10),
              Text(e.value,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? context.lgInk
                        : context.lgTextPrimary,
                  )),
              if (isActive) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: context.lgInk),
              ],
            ],
          ),
        );
      }).toList(),
      child: LoveIconButton(
        icon: sortIcons[provider.sortBy] ?? Icons.sort_rounded,
        tooltip: '\u6392\u5e8f',
        isActive: provider.sortBy != 'default',
      ),
    );
  }

  Widget _buildFilterAndSort(TravelProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (provider.searchQuery.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.lgInk.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_rounded,
                      size: 14, color: context.lgInk),
                  const SizedBox(width: 4),
                  Text('\u201c${provider.searchQuery}\u201d',
                      style: TextStyle(
                          fontSize: 12,
                          color: context.lgInk,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Text('${provider.filteredSpots.length} \u4e2a\u7ed3\u679c',
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: _buildFilter(provider)),
        ],
      ),
    );
  }





  Widget _buildFilter(TravelProvider provider) {
    final filters = [
      {'key': 'wish', 'label': '想去'},
      {'key': 'planned', 'label': '计划中'},
      {'key': 'visited', 'label': '已打卡'},
      {'key': 'both', 'label': '我们都编辑'},
      {'key': '', 'label': '全部'},
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final f = filters[index];
          final active = provider.activeStatus == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(f['label']!),
              selected: active,
              onSelected: (_) => provider.setStatus(f['key']!),
              selectedColor: LoveGirlTheme.primary.withAlpha(30),
              labelStyle: TextStyle(
                fontSize: 12,
                color: active
                    ? context.lgInk
                    : context.lgTextSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(TravelProvider provider) {
    return Center(
      child: LovePaper(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        radius: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoveStickerIcon(
              icon: Icons.cloud_off_rounded,
              color: LoveGirlTheme.orange,
            ),
            SizedBox(height: 16),
            Text(
              provider.error ?? '\u52a0\u8f7d\u5931\u8d25',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.lgTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            LovePrimaryButton(
              text: '\u91cd\u65b0\u52a0\u8f7d',
              icon: Icons.refresh_rounded,
              color: context.lgInk,
              onPressed: () => provider.refreshAll(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(TravelProvider provider) {
    String emoji;
    String msg;
    String hint;

    if (provider.searchQuery.isNotEmpty) {
      emoji = '\uD83D\uDD0E';
      msg = '\u6ca1\u6709\u627e\u5230\u201c${provider.searchQuery}\u201d';
      hint = '\u6362\u4e2a\u5173\u952e\u8bcd\u8bd5\u8bd5';
    } else if (provider.activeStatus == 'visited') {
      emoji = '\u2705';
      msg = '\u8fd8\u6ca1\u6709\u53bb\u8fc7\u7684\u5730\u65b9';
      hint =
          '\u53bb\u8fc7\u7684\u5730\u70b9\u6253\u5361\u540e\u4f1a\u51fa\u73b0\u5728\u8fd9\u91cc';
    } else if (provider.activeStatus == 'wish') {
      emoji = '\u2B50';
      msg = '\u8fd8\u6ca1\u6709\u60f3\u53bb\u7684\u5730\u65b9';
      hint =
          '\u6807\u8bb0\u5fc3\u613f\u5355\uff0c\u8bb0\u5f55\u60f3\u53bb\u7684\u8fdc\u65b9';
    } else if (provider.activeStatus == 'planned') {
      emoji = '\uD83D\uDDD3';
      msg = '\u8fd8\u6ca1\u6709\u8ba1\u5212\u4e2d\u7684\u5730\u65b9';
      hint = '\u89c4\u5212\u4e0b\u4e00\u6b21\u65c5\u884c\u5427';
    } else {
      emoji = '\uD83D\uDDFA\uFE0F';
      msg = '\u8fd8\u6ca1\u6709\u65c5\u884c\u8db3\u8ff9';
      hint =
          '\u957f\u6309\u5730\u56fe\u6216\u70b9\u51fb + \u5f00\u59cb\u8bb0\u5f55';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          SizedBox(height: 16),
          Text(msg,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.lgTextSecondary)),
          const SizedBox(height: 6),
          Text(hint,
              style: TextStyle(fontSize: 13, color: context.lgTextMuted)),
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, String status) {
  switch (status) {
    case 'visited':
      return const Color(0xFF4CAF50);
    case 'wish':
      return const Color(0xFFFF9800);
    case 'planned':
      return const Color(0xFF9C27B0);
    default:
      return context.lgInk;
  }
}




class _SpotCard extends StatefulWidget {
  final TravelSpot spot;
  final int index;
  final VoidCallback onTap;

  const _SpotCard({
    required this.spot,
    required this.index,
    required this.onTap,
  });

  @override
  State<_SpotCard> createState() => _SpotCardState();
}

class _SpotCardState extends State<_SpotCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 400));
    _startTimer = Timer(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final color = _statusColor(context, spot.status);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: LovePaper(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.only(bottom: 10),
          radius: 14,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(color: color, width: 3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          spot.emoji.isNotEmpty ? spot.emoji : '\uD83D\uDCCD',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    _travelDisplayText(spot.name, '未命名地点'),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: context.lgTextPrimary)),
                              ),
                              if (spot.creatorNickname?.isNotEmpty == true)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        LoveGirlTheme.secondary.withAlpha(14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    spot.creatorNickname!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: LoveGirlTheme.secondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 3),
                          Row(
                            children: [
                              if (_travelDisplayText(spot.city, '')
                                  .isNotEmpty) ...[
                                Icon(Icons.location_on,
                                    size: 12, color: context.lgTextMuted),
                                SizedBox(width: 2),
                                Text(_travelDisplayText(spot.city, ''),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.lgTextMuted)),
                              ],
                              if (spot.rating != null && spot.rating! > 0) ...[
                                SizedBox(width: 8),
                                ...List.generate(
                                    spot.rating!,
                                    (_) => const Icon(Icons.star,
                                        size: 12, color: Color(0xFFFFB800))),
                              ],
                            ],
                          ),
                          if ((spot.note?.isNotEmpty == true) ||
                              spot.visitedDate != null ||
                              spot.plannedDate != null) ...[
                            SizedBox(height: 6),
                            Text(
                              [
                                if (spot.visitedDate != null)
                                  '打卡 ${spot.visitedDate}',
                                if (spot.visitedDate == null &&
                                    spot.plannedDate != null)
                                  '计划 ${spot.plannedDate}',
                                if (spot.weather?.isNotEmpty == true)
                                  spot.weather!.trim(),
                                if (spot.budget != null && spot.budget! > 0)
                                  '预算 ¥${spot.budget!.toStringAsFixed(0)}',
                                if (spot.editedByBoth) '我们都编辑',
                                if (_travelDisplayText(spot.note, '')
                                    .isNotEmpty)
                                  _travelDisplayText(spot.note, ''),
                              ].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: context.lgTextMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(spot.status),
                          style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }


  String _statusLabel(String status) {
    switch (status) {
      case 'visited':
        return '\u5df2\u6253\u5361';
      case 'wish':
        return '想去';
      case 'planned':
        return '\u8ba1\u5212\u4e2d';
      default:
        return status;
    }
  }
}

class _QuickAddSheet extends StatefulWidget {
  final double lat;
  final double lng;
  final VoidCallback onSaved;

  const _QuickAddSheet({
    required this.lat,
    required this.lng,
    required this.onSaved,
  });

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  final _nameCtrl = TextEditingController();
  String _city = '';
  String _status = 'visited';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final city = await showCityPicker(context, currentCity: _city);
    if (city != null) setState(() => _city = city);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('\u8bf7\u8f93\u5165\u5730\u70b9\u540d\u79f0'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_city.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('\u8bf7\u9009\u62e9\u57ce\u5e02'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'city': _city,
        'status': _status,
        'lat': widget.lat,
        'lng': widget.lng,
        'emoji': '\uD83D\uDCCD',
      };
      if (!mounted) return;
      await context.read<TravelProvider>().createSpot(data);
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u6dfb\u52a0\u6210\u529f'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: LoveGirlTheme.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        color: context.lgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('\uD83D\uDCCD \u5feb\u901f\u6dfb\u52a0\u5730\u70b9',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: '\u5730\u70b9\u540d\u79f0 *',
              filled: true,
              fillColor: context.lgBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickCity,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: context.lgBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_city,
                      size: 20, color: context.lgTextMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _city.isEmpty ? '\u9009\u62e9\u57ce\u5e02 *' : _city,
                      style: TextStyle(
                        fontSize: 15,
                        color: _city.isEmpty
                            ? context.lgTextMuted
                            : context.lgTextPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: context.lgTextMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statusChip(
                'visited',
                '\u2713 \u5df2\u6253\u5361',
                const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 8),
              _statusChip(
                'wish',
                '\u2605 \u5fc3\u613f\u5355',
                const Color(0xFFFF9800),
              ),
              const SizedBox(width: 8),
              _statusChip(
                'planned',
                '\uD83D\uDDD3 \u8ba1\u5212\u4e2d',
                const Color(0xFF9C27B0),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\u5750\u6807 ${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}',
            style: TextStyle(
                fontSize: 12, color: context.lgTextMuted.withAlpha(150)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.lgInk,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('\u4fdd\u5b58',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String value, String label, Color color) {
    final active = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(30) : context.lgBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? color : Colors.black.withAlpha(10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? color : context.lgTextSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TicketActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;
  final bool danger;

  const _TicketActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? LoveGirlTheme.red : context.lgInk;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        SizedBox(width: 8),
        Text(label),
      ],
    );

    if (outlined || danger) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(danger ? 120 : 180)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: child,
    );
  }
}

class _SpotDetailSheet extends StatelessWidget {
  final TravelSpot spot;
  final VoidCallback onAddRoute;
  final VoidCallback onGenerateTicket;
  final VoidCallback onRecordExpense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SpotDetailSheet({
    required this.spot,
    required this.onAddRoute,
    required this.onGenerateTicket,
    required this.onRecordExpense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, spot.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: context.lgPaperWarm,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
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
                    color: context.lgSeparator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withAlpha(18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(spot.status),
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (spot.editedByBoth)
                    LovePill(
                      text: '我们都编辑',
                      icon: Icons.favorite_rounded,
                      color: context.lgInk,
                    ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withAlpha(18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        spot.emoji.isNotEmpty ? spot.emoji : '\uD83D\uDCCD',
                        style: const TextStyle(fontSize: 25),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _travelDisplayText(spot.name, '未命名地点'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: context.lgTextPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: context.lgTextMuted,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _travelDisplayText(spot.city, '还没填写城市'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.lgTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_travelDisplayText(spot.address, '').isNotEmpty) ...[
                LovePaper(
                  padding: const EdgeInsets.all(12),
                  elevated: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: context.lgTextMuted,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _travelDisplayText(spot.address, ''),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: context.lgTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildInfoSection(context, spot),
              const SizedBox(height: 16),
              TravelPhotoGrid(
                spotId: spot.id,
                editable: false,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _TicketActionButton(
                    icon: Icons.alt_route_rounded,
                    label: '加入路线',
                    onPressed: onAddRoute,
                    outlined: true,
                  ),
                  _TicketActionButton(
                    icon: Icons.confirmation_number_outlined,
                    label: '生成票根',
                    onPressed: onGenerateTicket,
                  ),
                  _TicketActionButton(
                    icon: Icons.edit_note_rounded,
                    label: '记一笔花费',
                    onPressed: onRecordExpense,
                    outlined: true,
                  ),
                  _TicketActionButton(
                    icon: Icons.edit,
                    label: '编辑',
                    onPressed: onEdit,
                    outlined: true,
                  ),
                  _TicketActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    onPressed: onDelete,
                    danger: true,
                    outlined: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, TravelSpot spot) {
    final items = <Widget>[];
    void addClean(IconData icon, String label, String? value) {
      final clean = _travelDisplayText(value, '');
      if (clean.isNotEmpty) {
        items.add(_infoRow(context, icon, label, clean));
      }
    }

    addClean(Icons.wb_sunny_outlined, '天气', spot.weather);

    if (spot.visitedDate != null) {
      items.add(
          _infoRow(context, Icons.calendar_today, '\u65e5\u671f', spot.visitedDate!));
    }
    if (spot.plannedDate != null) {
      items.add(
          _infoRow(context, Icons.event, '\u8ba1\u5212\u65e5\u671f', spot.plannedDate!));
    }

    addClean(Icons.emoji_emotions, '心情', spot.mood);

    if (spot.editedByBoth) {
      items.add(_infoRow(context, Icons.favorite_rounded, '共同编辑', '我们都编辑过这个地点'));
    }

    addClean(Icons.person_outline_rounded, '标记人', spot.creatorNickname);

    if (spot.rating != null && spot.rating! > 0) {
      items.add(_infoRow(context, Icons.star, '\u8bc4\u5206', '${spot.rating}/5'));
    }

    addClean(Icons.edit_note, '游记', spot.diary);

    addClean(Icons.favorite, '理由', spot.reason);

    addClean(Icons.map, '行程', spot.itinerary);

    addClean(Icons.directions_rounded, '交通方式', spot.transportation);

    if (spot.budget != null && spot.budget! > 0) {
      items.add(_infoRow(context, Icons.account_balance_wallet, '\u9884\u7b97',
          '\u00a5${spot.budget!.toStringAsFixed(0)}'));
    }

    addClean(Icons.store_mall_directory_outlined, '周边提示', spot.nearby);

    addClean(Icons.lightbulb_outline_rounded, '小提醒', spot.tips);

    addClean(Icons.schedule_rounded, '营业时间', spot.businessHours);

    addClean(Icons.person_rounded, '我的备注', spot.noteMine);

    addClean(Icons.favorite_border_rounded, '她的备注', spot.noteHer);

    addClean(Icons.note, '备注', spot.note);

    if (items.isEmpty) return const SizedBox.shrink();

    return LovePaper(
      padding: const EdgeInsets.all(14),
      elevated: false,
      child: Column(
        children: items
            .expand((w) => [w, if (w != items.last) const SizedBox(height: 10)])
            .toList(),
      ),
    );
  }

  Widget _infoRow(BuildContext context, IconData icon, String label,
      String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.lgTextMuted),
        SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(
                fontSize: 13, color: context.lgTextSecondary)),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 13, color: context.lgTextPrimary)),
        ),
      ],
    );
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'visited':
        return const Color(0xFF4CAF50);
      case 'wish':
        return const Color(0xFFFF9800);
      case 'planned':
        return const Color(0xFF9C27B0);
      default:
        return context.lgInk;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'visited':
        return '\u5df2\u6253\u5361';
      case 'wish':
        return '\u5fc3\u613f\u5355';
      case 'planned':
        return '\u8ba1\u5212\u4e2d';
      default:
        return status;
    }
  }
}

/// 顺序箭头层：按 routeDay/routeOrder 把地点串成"顺序表"，弓形虚线 + 箭头

/// 图标形变切换钮：旋转+缩放过渡，切换不丢位置感
class _MorphIconButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _MorphIconButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: active
                ? context.lgInk.withAlpha(28)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween(begin: -0.35, end: 0.0).animate(anim),
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 21,
                color: active
                    ? context.lgInk
                    : context.lgTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// 旅行页底部悬浮 tab：地图 / 清单 / 票根
class _TravelViewTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _TravelViewTabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.map_rounded, '地图'),
      (Icons.list_alt_rounded, '清单'),
      (Icons.confirmation_number_rounded, '票根'),
    ];
    return Center(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: context.lgInk.withAlpha(242),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: index == i
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 17,
                        color: index == i
                            ? LoveGirlTheme.primary
                            : Colors.white.withAlpha(210),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: index == i
                              ? LoveGirlTheme.primary
                              : Colors.white.withAlpha(210),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
