import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/travel_form_screen.dart';
import 'package:lovegirl_flutter/widgets/travel_map_widget.dart';
import 'package:lovegirl_flutter/widgets/travel_photo_grid.dart';
import 'package:lovegirl_flutter/widgets/city_picker.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

/// 旅行主页 — 地图 + 搜索 + 排序 + 长按添加 + 列表
class TravelMainScreen extends StatefulWidget {
  const TravelMainScreen({super.key});

  @override
  State<TravelMainScreen> createState() => _TravelMainScreenState();
}

class _TravelMainScreenState extends State<TravelMainScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<TravelMapWidgetState> _mapKey = GlobalKey();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  bool _showSearch = false;
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

  /// 长按地图添加地点
  void _onMapLongPress(LatLng position) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickAddSheet(
        lat: position.latitude,
        lng: position.longitude,
        onSaved: () {
          context.read<TravelProvider>().refreshAll();
        },
      ),
    );
  }

  /// 点击标记 → 弹出详情
  void _onMarkerTap(TravelSpot spot) {
    _mapKey.currentState?.animateToSpot(spot);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SpotDetailSheet(
        spot: spot,
        onEdit: () async {
          Navigator.pop(ctx);
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TravelFormScreen(spot: spot),
            ),
          );
          if (result == true && mounted) {
            context.read<TravelProvider>().refreshAll();
          }
        },
        onDelete: () async {
          Navigator.pop(ctx);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dCtx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('删除地点'),
              content: Text('确定删除「${spot.name}」吗？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    child: const Text('取消')),
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text('删除',
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

  @override
  Widget build(BuildContext context) {
    return Consumer<TravelProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: LoveGirlTheme.bgLight,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshAll(),
              child: CustomScrollView(
                slivers: [
                  // 标题栏 + 搜索/排序
                  SliverToBoxAdapter(child: _buildHeader(provider)),

                  // 搜索栏（展开时显示）
                  if (_showSearch)
                    SliverToBoxAdapter(child: _buildSearchBar()),

                  // 地图区域
                  SliverToBoxAdapter(child: _buildMapSection(provider)),

                  // 统计卡片
                  SliverToBoxAdapter(child: _buildStats(provider)),

                  // 筛选 + 排序
                  SliverToBoxAdapter(child: _buildFilterAndSort(provider)),

                  // 提示
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        '💡 长按地图可快速添加地点',
                        style: TextStyle(
                            fontSize: 12, color: LoveGirlTheme.textMuted),
                      ),
                    ),
                  ),

                  // 地点列表
                  if (provider.loading && provider.spots.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (provider.filteredSpots.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmpty(provider),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final spot = provider.filteredSpots[index];
                            return _SpotCard(
                              spot: spot,
                              index: index,
                              onTap: () => _onMarkerTap(spot),
                            );
                          },
                          childCount: provider.filteredSpots.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          floatingActionButton: ScaleTransition(
            scale: CurvedAnimation(
              parent: _fabAnimCtrl,
              curve: Curves.elasticOut,
            ),
            child: FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TravelFormScreen(),
                  ),
                );
                if (result == true && mounted) {
                  context.read<TravelProvider>().refreshAll();
                }
              },
              backgroundColor: LoveGirlTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  // ==================== 标题栏 ====================
  Widget _buildHeader(TravelProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          const Text('旅行足迹',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.textPrimary)),
          const Spacer(),
          // 搜索按钮
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search_rounded,
                color: _showSearch
                    ? LoveGirlTheme.primary
                    : LoveGirlTheme.textSecondary),
            onPressed: _toggleSearch,
            tooltip: '搜索',
          ),
          // 排序按钮
          _buildSortMenu(provider),
        ],
      ),
    );
  }

  // ==================== 搜索栏 ====================
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
            hintText: '搜索地点、城市、备注...',
            hintStyle: TextStyle(
                color: LoveGirlTheme.textMuted.withAlpha(150), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: LoveGirlTheme.primary, size: 20),
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
            fillColor: LoveGirlTheme.cardLight,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 排序菜单 ====================
  Widget _buildSortMenu(TravelProvider provider) {
    final sortLabels = {
      'default': '默认',
      'name': '名称',
      'rating': '评分',
      'date': '日期',
      'city': '城市',
    };
    final sortIcons = {
      'default': Icons.sort_rounded,
      'name': Icons.sort_by_alpha_rounded,
      'rating': Icons.star_rounded,
      'date': Icons.calendar_today_rounded,
      'city': Icons.location_city_rounded,
    };

    return PopupMenuButton<String>(
      icon: Icon(
        sortIcons[provider.sortBy] ?? Icons.sort_rounded,
        color: provider.sortBy != 'default'
            ? LoveGirlTheme.primary
            : LoveGirlTheme.textSecondary,
      ),
      tooltip: '排序',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      ? LoveGirlTheme.primary
                      : LoveGirlTheme.textSecondary),
              const SizedBox(width: 10),
              Text(e.value,
                  style: TextStyle(
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? LoveGirlTheme.primary
                        : LoveGirlTheme.textPrimary,
                  )),
              if (isActive) ...[
                const Spacer(),
                const Icon(Icons.check,
                    size: 16, color: LoveGirlTheme.primary),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // ==================== 筛选+排序栏 ====================
  Widget _buildFilterAndSort(TravelProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // 搜索结果提示
          if (provider.searchQuery.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: LoveGirlTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded,
                      size: 14, color: LoveGirlTheme.primary),
                  const SizedBox(width: 4),
                  Text('「${provider.searchQuery}」',
                      style: const TextStyle(
                          fontSize: 12,
                          color: LoveGirlTheme.primary,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Text('${provider.filteredSpots.length}个结果',
                      style: TextStyle(
                          fontSize: 12,
                          color: LoveGirlTheme.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 筛选 chips
          Expanded(child: _buildFilter(provider)),
        ],
      ),
    );
  }

  Widget _buildMapSection(TravelProvider provider) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.35;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: mapHeight,
          child: TravelMapWidget(
            key: _mapKey,
            spots: provider.mapSpots,
            allSpots: provider.spots,
            highlightedId: provider.highlightedId,
            onMarkerTap: _onMarkerTap,
            onLongPress: _onMapLongPress,
          ),
        ),
      ),
    );
  }

  Widget _buildStats(TravelProvider provider) {
    final stats = provider.computedStats;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [LoveGirlTheme.primary, LoveGirlTheme.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: LoveGirlTheme.primary.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('去过', '${stats.visited}', Icons.check_circle,
              'visited', provider),
          _buildStatItem(
              '想去', '${stats.wish}', Icons.star, 'wish', provider),
          _buildStatItem('规划中', '${stats.planned}', Icons.assignment,
              'planned', provider),
          _buildStatItem('城市', '${stats.cities}', Icons.location_city,
              '', provider),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      String status, TravelProvider provider) {
    final isActive =
        status.isNotEmpty && provider.activeStatus == status;
    return GestureDetector(
      onTap: status.isNotEmpty
          ? () => provider.setStatus(isActive ? '' : status)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: isActive
            ? BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilter(TravelProvider provider) {
    final filters = [
      {'key': '', 'label': '全部'},
      {'key': 'visited', 'label': '去过'},
      {'key': 'wish', 'label': '想去'},
      {'key': 'planned', 'label': '规划中'},
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
                    ? LoveGirlTheme.primary
                    : LoveGirlTheme.textSecondary,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(TravelProvider provider) {
    String emoji;
    String msg;
    String hint;

    if (provider.searchQuery.isNotEmpty) {
      emoji = '🔍';
      msg = '没有找到「${provider.searchQuery}」';
      hint = '换个关键词试试';
    } else if (provider.activeStatus == 'visited') {
      emoji = '✈️';
      msg = '还没有去过的地方';
      hint = '去过的地点打卡后会出现在这里';
    } else if (provider.activeStatus == 'wish') {
      emoji = '🌟';
      msg = '还没有想去的地方';
      hint = '标记心愿单，记录想去的远方';
    } else if (provider.activeStatus == 'planned') {
      emoji = '📋';
      msg = '还没有规划中的地方';
      hint = '规划下一次旅行吧';
    } else {
      emoji = '🗺️';
      msg = '还没有旅行足迹';
      hint = '长按地图或点击 + 开始记录';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(msg,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 6),
          Text(hint,
              style: TextStyle(
                  fontSize: 13,
                  color: LoveGirlTheme.textMuted)),
        ],
      ),
    );
  }
}

// ==================== 地点卡片（带动画） ====================
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

    // Staggered delay
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 400));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final color = _statusColor(spot.status);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
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
                    // Emoji / 状态图标
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          spot.emoji.isNotEmpty ? spot.emoji : '📍',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spot.name,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: LoveGirlTheme.textPrimary)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (spot.city.isNotEmpty) ...[
                                Icon(Icons.location_on,
                                    size: 12,
                                    color: LoveGirlTheme.textMuted),
                                const SizedBox(width: 2),
                                Text(spot.city,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: LoveGirlTheme.textMuted)),
                              ],
                              if (spot.rating != null &&
                                  spot.rating! > 0) ...[
                                const SizedBox(width: 8),
                                ...List.generate(
                                    spot.rating!,
                                    (_) => const Icon(Icons.star,
                                        size: 12,
                                        color: Color(0xFFFFB800))),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 状态标签
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_statusLabel(spot.status),
                          style: TextStyle(
                              fontSize: 11,
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

  Color _statusColor(String status) {
    switch (status) {
      case 'visited':
        return const Color(0xFF4CAF50);
      case 'wish':
        return const Color(0xFFFF9800);
      case 'planned':
        return const Color(0xFF9C27B0);
      default:
        return LoveGirlTheme.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'visited':
        return '已打卡';
      case 'wish':
        return '心愿单';
      case 'planned':
        return '计划中';
      default:
        return status;
    }
  }
}

// ==================== 快速添加底部弹窗 ====================
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
        const SnackBar(
            content: Text('请输入地点名称'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_city.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请选择城市'),
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
        'emoji': '📍',
      };
      if (!mounted) return;
      await context.read<TravelProvider>().createSpot(data);
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('添加成功'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败，请重试'),
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
      decoration: const BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('📍 快速添加地点',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // 地点名称
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: '地点名称 *',
              filled: true,
              fillColor: LoveGirlTheme.bgLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),

          // 城市选择
          GestureDetector(
            onTap: _pickCity,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: LoveGirlTheme.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city,
                      size: 20, color: LoveGirlTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _city.isEmpty ? '选择城市 *' : _city,
                      style: TextStyle(
                        fontSize: 15,
                        color: _city.isEmpty
                            ? LoveGirlTheme.textMuted
                            : LoveGirlTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: LoveGirlTheme.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 状态选择
          Row(
            children: [
              _statusChip('visited', '✅ 已打卡', const Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              _statusChip('wish', '⭐ 心愿单', const Color(0xFFFF9800)),
              const SizedBox(width: 8),
              _statusChip('planned', '📋 计划中', const Color(0xFF9C27B0)),
            ],
          ),
          const SizedBox(height: 16),

          // 坐标提示
          Text(
            '📍 ${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}',
            style: TextStyle(
                fontSize: 11, color: LoveGirlTheme.textMuted.withAlpha(150)),
          ),
          const SizedBox(height: 12),

          // 保存按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: LoveGirlTheme.primary,
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
                  : const Text('保存',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
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
          color: active ? color.withAlpha(30) : LoveGirlTheme.bgLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.black.withAlpha(10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? color : LoveGirlTheme.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ==================== 地点详情底部弹窗 ====================
class _SpotDetailSheet extends StatelessWidget {
  final TravelSpot spot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SpotDetailSheet({
    required this.spot,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(spot.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 标题行
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    spot.emoji.isNotEmpty ? spot.emoji : '📍',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    if (spot.city.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 14, color: LoveGirlTheme.textMuted),
                          const SizedBox(width: 2),
                          Text(spot.city,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: LoveGirlTheme.textMuted)),
                        ],
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_statusLabel(spot.status),
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),

          // 详细信息区域
          const SizedBox(height: 16),
          _buildInfoSection(spot),

          // 照片预览
          const SizedBox(height: 16),
          TravelPhotoGrid(
            spotId: spot.id,
            editable: false,
          ),

          const SizedBox(height: 20),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('编辑'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LoveGirlTheme.primary,
                    side: const BorderSide(color: LoveGirlTheme.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LoveGirlTheme.red,
                    side: BorderSide(color: LoveGirlTheme.red.withAlpha(100)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(TravelSpot spot) {
    final items = <Widget>[];

    // 日期
    if (spot.visitedDate != null) {
      items.add(_infoRow(Icons.calendar_today, '日期', spot.visitedDate!));
    }
    if (spot.plannedDate != null) {
      items.add(_infoRow(Icons.event, '计划日期', spot.plannedDate!));
    }

    // 天气+心情
    if (spot.mood != null && spot.mood!.isNotEmpty) {
      items.add(_infoRow(Icons.emoji_emotions, '天气/心情', spot.mood!));
    }

    // 评分
    if (spot.rating != null && spot.rating! > 0) {
      items.add(_infoRow(
          Icons.star, '评分', '${'★' * spot.rating!}${'☆' * (5 - spot.rating!)}'));
    }

    // 游记
    if (spot.diary != null && spot.diary!.isNotEmpty) {
      items.add(_infoRow(Icons.edit_note, '游记', spot.diary!));
    }

    // 去的理由
    if (spot.reason != null && spot.reason!.isNotEmpty) {
      items.add(_infoRow(Icons.favorite, '理由', spot.reason!));
    }

    // 行程
    if (spot.itinerary != null && spot.itinerary!.isNotEmpty) {
      items.add(_infoRow(Icons.map, '行程', spot.itinerary!));
    }

    // 预算
    if (spot.budget != null && spot.budget! > 0) {
      items.add(_infoRow(
          Icons.account_balance_wallet, '预算', '¥${spot.budget!.toStringAsFixed(0)}'));
    }

    // 备注
    if (spot.note != null && spot.note!.isNotEmpty) {
      items.add(_infoRow(Icons.note, '备注', spot.note!));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LoveGirlTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items
            .expand((w) => [w, if (w != items.last) const SizedBox(height: 10)])
            .toList(),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: LoveGirlTheme.textMuted),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, color: LoveGirlTheme.textSecondary)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, color: LoveGirlTheme.textPrimary)),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'visited':
        return const Color(0xFF4CAF50);
      case 'wish':
        return const Color(0xFFFF9800);
      case 'planned':
        return const Color(0xFF9C27B0);
      default:
        return LoveGirlTheme.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'visited':
        return '已打卡';
      case 'wish':
        return '心愿单';
      case 'planned':
        return '计划中';
      default:
        return status;
    }
  }
}
