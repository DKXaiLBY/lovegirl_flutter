import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';

String _safeText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _feedingDisplayText(Object? value, {String fallback = ''}) {
  final text = _safeText(value, fallback: fallback);
  if (text.isEmpty) return fallback;

  const displayMap = {
    'hot noodles': '热汤面',
    'warm meal': '热乎乎的一餐',
    'rice bowl': '盖饭套餐',
    'simple lunch': '简单午餐',
  };
  final mapped = displayMap[text.toLowerCase()];
  if (mapped != null) return mapped;

  if (text.contains('\uFFFD')) return fallback;
  final questionCount = RegExp(r'[\?？]').allMatches(text).length;
  if (questionCount >= 3 && questionCount >= text.runes.length / 2) {
    return fallback;
  }

  return text;
}

int _safeInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _safeDouble(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _money(Object? value) {
  final amount = _safeDouble(value);
  if (amount % 1 == 0) return amount.toInt().toString();
  return amount.toStringAsFixed(2);
}

Color _ticketColor(Object? raw, Color fallback) {
  final text = raw?.toString() ?? '';
  if (!text.startsWith('#')) return fallback;
  try {
    return Color(int.parse(text.replaceFirst('#', '0xFF')));
  } catch (_) {
    return fallback;
  }
}

String _categoryLabel(String category) {
  switch (category) {
    case 'drink':
      return '\u996e\u54c1';
    case 'food':
      return '\u5c0f\u5403';
    case 'flower':
      return '\u9c9c\u82b1';
    case 'gift':
      return '\u793c\u7269';
    default:
      return '\u5176\u4ed6';
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'drink':
      return Icons.local_cafe_rounded;
    case 'food':
      return Icons.ramen_dining_rounded;
    case 'flower':
      return Icons.local_florist_rounded;
    case 'gift':
      return Icons.redeem_rounded;
    default:
      return Icons.favorite_border_rounded;
  }
}

(String label, Color color, IconData icon) _statusMeta(String status) {
  switch (status) {
    case 'pending':
      return (
        '\u5f85\u63a5\u5355',
        LoveGirlTheme.orange,
        Icons.pending_actions_rounded
      );
    case 'accepted':
      return (
        '\u5df2\u63a5\u5355',
        const Color(0xFF4A8DFF),
        Icons.check_circle_outline
      );
    case 'preparing':
      return (
        '\u51c6\u5907\u4e2d',
        const Color(0xFF8C63D9),
        Icons.restaurant_rounded
      );
    case 'delivering':
      return (
        '\u914d\u9001\u4e2d',
        const Color(0xFF2EA8A8),
        Icons.delivery_dining_rounded
      );
    case 'completed':
      return (
        '\u5df2\u5b8c\u6210',
        const Color(0xFF4CAF50),
        Icons.check_circle_rounded
      );
    case 'cancelled':
      return (
        '\u5df2\u53d6\u6d88',
        LoveGirlTheme.textMuted,
        Icons.cancel_outlined
      );
    default:
      return (status, LoveGirlTheme.textMuted, Icons.more_horiz_rounded);
  }
}

String _statusActionLabel(String status) {
  switch (status) {
    case 'accepted':
      return '\u5df2\u63a5\u5355';
    case 'preparing':
      return '\u51c6\u5907\u4e2d';
    case 'delivering':
      return '\u914d\u9001\u4e2d';
    case 'completed':
      return '\u5df2\u5b8c\u6210';
    case 'cancelled':
      return '\u5df2\u53d6\u6d88';
    default:
      return status;
  }
}

String _orderTime(Object? value) {
  final text = value?.toString() ?? '';
  if (text.length >= 16) return text.substring(5, 16);
  return text;
}

String _orderRoleLabel(bool isMine) {
  return isMine
      ? '\u6211\u66ff\u5979\u4e0b\u7684'
      : '\u5979\u70b9\u7ed9\u6211\u7684';
}

class FeedingScreen extends StatefulWidget {
  const FeedingScreen({super.key});

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _shops = [];
  List<Map<String, dynamic>> _recentOrders = [];
  Map<String, dynamic> _stats = {};
  final Map<int, int> _urgeSnapshot = {};
  Timer? _pollTimer;

  bool _loading = true;
  bool _showingOrders = false;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshOrdersSilently(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _api.getFeedingShops().timeout(const Duration(seconds: 10)),
        _api.getFeedingStats().timeout(const Duration(seconds: 10)),
        _api.getFeedingOrders().timeout(const Duration(seconds: 10)),
      ]);

      final shopsData = results[0].data?['data'];
      final statsData = results[1].data?['data'];
      final ordersData = results[2].data?['data'];

      final shops = shopsData is List
          ? shopsData.map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      final stats = statsData is Map<String, dynamic>
          ? Map<String, dynamic>.from(statsData)
          : <String, dynamic>{};
      final rawOrders = ordersData is List
          ? ordersData
          : (ordersData is Map ? (ordersData['list'] ?? const []) : const []);
      final orders = rawOrders
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();

      for (final order in orders) {
        final id = _safeInt(order['id'], fallback: -1);
        if (id > 0) {
          _urgeSnapshot[id] = _safeInt(order['urge_count']);
        }
      }

      if (!mounted) return;
      setState(() {
        _shops = shops;
        _stats = stats;
        _recentOrders = orders;
        _loading = false;
        _error = (shops.isEmpty && stats.isEmpty && orders.isEmpty)
            ? '\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u91cd\u8bd5'
            : null;
      });
    } catch (e) {
      LogService()
          .error('Feeding', '\u52a0\u8f7d\u6295\u5582\u7ad9\u5931\u8d25: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            '\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u91cd\u8bd5';
      });
    }
  }

  Future<void> _refreshOrdersSilently() async {
    if (_loading || !mounted) return;
    try {
      final orderRes =
          await _api.getFeedingOrders().timeout(const Duration(seconds: 10));
      final statsRes =
          await _api.getFeedingStats().timeout(const Duration(seconds: 10));

      final rawOrders = orderRes.data?['data'];
      final nextOrders = (rawOrders is List
              ? rawOrders
              : (rawOrders is Map ? (rawOrders['list'] ?? const []) : const []))
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();
      final nextStats = statsRes.data?['data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(statsRes.data!['data'])
          : _stats;

      String? notice;
      for (final order in nextOrders) {
        final id = _safeInt(order['id'], fallback: -1);
        if (id <= 0) continue;
        final nextUrges = _safeInt(order['urge_count']);
        final previousUrges = _urgeSnapshot[id] ?? nextUrges;
        final isReceived =
            order['is_received'] == true || order['order_role'] == 'received';
        if (isReceived && nextUrges > previousUrges) {
          notice =
              '${_feedingDisplayText(order['product_name'], fallback: '投喂订单')} 收到新的催单提醒';
        }
        _urgeSnapshot[id] = nextUrges;
      }

      if (!mounted) return;
      setState(() {
        _recentOrders = nextOrders;
        _stats = nextStats;
      });

      if (notice != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice)),
        );
      }
    } catch (e) {
      LogService().error('Feeding',
          '\u9759\u9ed8\u5237\u65b0\u6295\u5582\u8ba2\u5355\u5931\u8d25: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredShops {
    final keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return _shops;
    return _shops.where((shop) {
      final text = [
        _safeText(shop['name']),
        _safeText(shop['description']),
        _safeText(shop['category']),
      ].join(' ').toLowerCase();
      return text.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: LovePage(
        padding: EdgeInsets.zero,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 12),
                        if (_showingOrders) ...[
                          _buildOrdersView(),
                        ] else ...[
                          _buildStatsCard(),
                          const SizedBox(height: 14),
                          _buildSearchBar(),
                          const SizedBox(height: 18),
                          _buildShopsView(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return LoveTicketCard(
      color: LoveGirlTheme.paperWarm,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.of(context).canPop()) ...[
                LoveIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: '\u8fd4\u56de',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
              ],
              LoveStickerIcon(
                icon: _showingOrders
                    ? Icons.receipt_long_rounded
                    : Icons.room_service_rounded,
                color: LoveGirlTheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showingOrders
                          ? '\u6295\u5582\u8bb0\u5f55'
                          : '\u6295\u5582\u7ad9',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _showingOrders
                          ? '\u6bcf\u4e00\u6b21\u6295\u5582\uff0c\u90fd\u4f1a\u7559\u4e0b\u88ab\u8ba4\u771f\u7167\u987e\u8fc7\u7684\u75d5\u8ff9\u3002'
                          : '\u5979\u70b9\u4e0b\u53bb\u7684\u65f6\u5019\uff0c\u8981\u771f\u7684\u50cf\u5728\u53eb\u4f60\u7ed9\u5979\u4e70\u4e1c\u897f\u3002',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: LoveGirlTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              LoveIconButton(
                icon: _showingOrders
                    ? Icons.storefront_rounded
                    : Icons.receipt_long_rounded,
                tooltip: _showingOrders
                    ? '\u8fd4\u56de\u83dc\u5355'
                    : '\u6295\u5582\u8bb0\u5f55',
                isActive: _showingOrders,
                onTap: () => setState(() => _showingOrders = !_showingOrders),
              ),
            ],
          ),
          if (!_showingOrders) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                LovePill(
                  text: '\u4e13\u5c5e\u83dc\u5355',
                  icon: Icons.menu_book_rounded,
                  color: LoveGirlTheme.primary,
                ),
                SizedBox(width: 8),
                LovePill(
                  text: '\u771f\u5b9e\u5c65\u7ea6',
                  icon: Icons.delivery_dining_rounded,
                  color: LoveGirlTheme.secondary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return LoveTicketCard(
      color: const Color(0xFFFFFAF6),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u5979\u7684\u4e13\u5c5e\u83dc\u5355',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '\u5e38\u70b9\u7684\u5148\u914d\u597d\uff0c\u4e34\u65f6\u60f3\u5403\u7684\u4e5f\u80fd\u968f\u624b\u52a0\u8fdb\u6765\uff0c\u8ba9\u6bcf\u6b21\u70b9\u5355\u90fd\u50cf\u771f\u7684\u5728\u53eb\u4f60\u3002',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: LoveGirlTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              LovePill(
                text: '\u771f\u5b9e\u4e0b\u5355',
                icon: Icons.favorite_rounded,
                color: LoveGirlTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.favorite_rounded,
                  label: '\u5df2\u9001\u51fa',
                  value: _safeInt(_stats['total_sent']).toString(),
                  unit: '\u4ef6',
                ),
              ),
              Container(width: 1, height: 44, color: LoveGirlTheme.separator),
              Expanded(
                child: _StatTile(
                  icon: Icons.card_giftcard_rounded,
                  label: '\u6536\u5230',
                  value: _safeInt(_stats['total_received']).toString(),
                  unit: '\u4ef6',
                ),
              ),
              Container(width: 1, height: 44, color: LoveGirlTheme.separator),
              Expanded(
                child: _StatTile(
                  icon: Icons.pending_actions_rounded,
                  label: '\u5f85\u5904\u7406',
                  value: _safeInt(_stats['pending_orders']).toString(),
                  unit: '\u5355',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return LovePaper(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      elevated: false,
      child: TextField(
        onChanged: (value) => setState(() => _query = value),
        decoration: const InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, color: LoveGirlTheme.primary),
          hintText:
              '\u641c\u5e97\u94fa\u6216\u5979\u60f3\u5403\u7684\u4e1c\u897f',
          hintStyle: TextStyle(color: LoveGirlTheme.textMuted),
        ),
      ),
    );
  }

  Widget _buildShopsView() {
    final shops = _filteredShops;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LoveSectionTitle(title: '\u4e13\u5c5e\u83dc\u5355'),
        const SizedBox(height: 12),
        if (shops.isEmpty)
          const _EmptyState(
            icon: Icons.search_off_rounded,
            title:
                '\u6ca1\u6709\u627e\u5230\u76f8\u5173\u5e97\u94fa\u6216\u83dc\u5355',
            subtitle:
                '\u6362\u4e2a\u5173\u952e\u8bcd\u8bd5\u8bd5\uff0c\u6216\u8005\u5148\u628a\u5979\u4e34\u65f6\u60f3\u5403\u7684\u4e1c\u897f\u8bb0\u8fdb\u6765\u3002',
          )
        else
          ...shops.map(_buildShopCard),
      ],
    );
  }

  Widget _buildOrdersView() {
    if (_recentOrders.isEmpty) {
      return const _EmptyState(
        icon: Icons.hourglass_empty_rounded,
        title: '\u8fd8\u6ca1\u6709\u6295\u5582\u8bb0\u5f55',
        subtitle:
            '\u4e0b\u5355\u4e4b\u540e\uff0c\u8fd9\u91cc\u4f1a\u6162\u6162\u957f\u51fa\u4f60\u4eec\u7684\u8bb0\u5f55\u3002',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LoveSectionTitle(title: '\u6295\u5582\u8bb0\u5f55'),
        const SizedBox(height: 12),
        ..._recentOrders.map(_buildOrderCard),
      ],
    );
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    final bannerColor =
        _ticketColor(shop['banner_color'], LoveGirlTheme.primary);
    final name = _safeText(shop['name']);
    final icon = _safeText(shop['icon']);
    final description = _safeText(shop['description']);
    final displayName = name.isEmpty ? '\u672a\u547d\u540d\u5e97\u94fa' : name;
    final displayIcon = icon.isEmpty ? '\ud83c\udf7d' : icon;
    final categoryKey = _safeText(shop['category'], fallback: 'food');
    final category = _categoryLabel(categoryKey);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShopDetailScreen(
            shop: shop,
            onOrderCreated: _loadData,
          ),
        ),
      ),
      child: LoveTicketCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 94,
              decoration: BoxDecoration(
                color: bannerColor.withAlpha(14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: bannerColor.withAlpha(30)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(displayIcon, style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 8),
                  Icon(
                    _categoryIcon(categoryKey),
                    size: 16,
                    color: bannerColor,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 0, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: LoveGirlTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        LovePill(
                          text: category,
                          color: bannerColor,
                          background: bannerColor.withAlpha(18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description.isNotEmpty
                          ? description
                          : '\u63d0\u524d\u628a\u5979\u5e38\u70b9\u7684\u914d\u597d\uff0c\u4e34\u65f6\u60f3\u5403\u7684\u4e5f\u80fd\u7ee7\u7eed\u5f80\u91cc\u52a0\u3002',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: LoveGirlTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: LoveGirlTheme.paperWarm,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: LoveGirlTheme.separator),
                          ),
                          child: const Text(
                            '\u4e3a\u5979\u5907\u597d',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: LoveGirlTheme.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: bannerColor.withAlpha(14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: bannerColor.withAlpha(36),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                size: 14,
                                color: bannerColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '\u67e5\u770b\u83dc\u5355',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: bannerColor,
                                ),
                              ),
                            ],
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
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final productName =
        _feedingDisplayText(order['product_name'], fallback: '投喂订单');
    final shopName =
        _safeText(order['shop_name'], fallback: '\u6295\u5582\u7ad9');
    final shopIcon = _safeText(order['shop_icon']).isEmpty
        ? '\ud83c\udf7d'
        : _safeText(order['shop_icon']);
    final quantity = _safeInt(order['quantity'], fallback: 1);
    final totalPrice = order['total_price'] ?? order['product_price'] ?? 0;
    final status = _safeText(order['status'], fallback: 'pending');
    final urgeCount = _safeInt(order['urge_count']);
    final isMine = order['is_mine'] == true;
    final meta = _statusMeta(status);

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => OrderDetailSheet(
          order: order,
          onStatusChanged: _loadData,
        ),
      ),
      child: LoveTicketCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(shopIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LoveGirlTheme.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: meta.$2.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meta.$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: meta.$2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: LoveGirlTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: LoveGirlTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'x$quantity · 合计 ¥${_money(totalPrice)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: LoveGirlTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  _orderTime(order['created_at']),
                  style: const TextStyle(
                    fontSize: 11,
                    color: LoveGirlTheme.textMuted,
                  ),
                ),
                if (urgeCount > 0) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.notifications_active_rounded,
                    size: 14,
                    color: LoveGirlTheme.orange,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '\u50ac\u5355 $urgeCount \u6b21',
                    style: const TextStyle(
                      fontSize: 11,
                      color: LoveGirlTheme.orange,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _orderRoleLabel(isMine),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isMine
                        ? LoveGirlTheme.primary
                        : LoveGirlTheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: LoveTicketCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: LoveGirlTheme.textMuted,
              ),
              const SizedBox(height: 12),
              Text(
                _error ??
                    '\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: LoveGirlTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              LovePrimaryButton(
                text: '\u91cd\u65b0\u52a0\u8f7d',
                icon: Icons.refresh_rounded,
                onPressed: _loadData,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShopDetailScreen extends StatefulWidget {
  final Map<String, dynamic> shop;
  final VoidCallback? onOrderCreated;

  const ShopDetailScreen({
    super.key,
    required this.shop,
    this.onOrderCreated,
  });

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final shopId = _safeInt(widget.shop['id']);
      final res = await _api
          .getFeedingShopProducts(shopId)
          .timeout(const Duration(seconds: 10));
      final data = res.data?['data'];
      _products = data is List
          ? data.map((item) => Map<String, dynamic>.from(item)).toList()
          : [];
    } catch (e) {
      LogService().error('Feeding', '\u52a0\u8f7d\u5546\u54c1\u5931\u8d25: $e');
      _products = [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _showSendSheet(Map<String, dynamic> product) async {
    int quantity = 1;
    final messageController = TextEditingController();
    final price = _safeDouble(product['price']);
    final productName = _feedingDisplayText(product['name'], fallback: '未命名商品');

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: LoveGirlTheme.paperWarm,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.textMuted.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: LoveGirlTheme.primary.withAlpha(28),
                    ),
                  ),
                  child: Icon(
                    _categoryIcon(
                      _safeText(widget.shop['category'], fallback: 'food'),
                    ),
                    color: LoveGirlTheme.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                if (_feedingDisplayText(product['description']).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _feedingDisplayText(product['description']),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: LoveGirlTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        if (quantity > 1) {
                          setSheetState(() => quantity -= 1);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: LoveGirlTheme.textPrimary,
                        ),
                      ),
                    ),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        if (quantity < 99) {
                          setSheetState(() => quantity += 1);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        '\u7ed9\u8fd9\u6b21\u6295\u5582\u7559\u4e00\u53e5\u8bdd\uff0c\u6bd4\u5982\u53e3\u5473\u3001\u5907\u6ce8\uff0c\u6216\u8005\u4e00\u53e5\u53ea\u5c5e\u4e8e\u4f60\u4eec\u7684\u5c0f\u7eb8\u6761\u3002',
                    prefixIcon: Icon(
                      Icons.edit_note_rounded,
                      color: LoveGirlTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      '\u9884\u8ba1\u5408\u8ba1 \u00a5${_money(price * quantity)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    const LovePill(
                      text: '\u5979\u60f3\u5403\u7684',
                      icon: Icons.favorite_rounded,
                      color: LoveGirlTheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(this.context);
                      try {
                        await _api.createFeedingOrder({
                          'product_id': product['id'],
                          'shop_id': widget.shop['id'],
                          'quantity': quantity,
                          'message': messageController.text.trim(),
                        });
                        LogService().userAction(
                          '创建投喂订单: $productName x$quantity',
                        );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        widget.onOrderCreated?.call();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                '\u4e0b\u5355\u6210\u529f\uff0c\u5df2\u7ecf\u628a\u8fd9\u4efd\u5fc3\u610f\u653e\u8fdb\u6295\u5582\u8bb0\u5f55\u91cc\u4e86\u3002',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        LogService().error('Feeding',
                            '\u521b\u5efa\u6295\u5582\u8ba2\u5355\u5931\u8d25: $e');
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '\u4e0b\u5355\u5931\u8d25\u4e86\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    child: Text(
                      '\u786e\u8ba4\u6295\u5582 \u00a5${_money(price * quantity)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      messageController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopName =
        _safeText(widget.shop['name'], fallback: '\u6295\u5582\u7ad9');
    final shopIcon = _safeText(widget.shop['icon']).isEmpty
        ? '\ud83c\udf7d'
        : _safeText(widget.shop['icon']);
    final shopDesc = _safeText(widget.shop['description']);
    final bannerColor =
        _ticketColor(widget.shop['banner_color'], LoveGirlTheme.primary);

    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: LovePage(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            LoveTicketCard(
              color: bannerColor.withAlpha(24),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      LoveIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: '\u8fd4\u56de',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Text(shopIcon,
                                style: const TextStyle(fontSize: 30)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    shopName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: LoveGirlTheme.textPrimary,
                                    ),
                                  ),
                                  if (shopDesc.isNotEmpty)
                                    Text(
                                      shopDesc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: LoveGirlTheme.textSecondary,
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      LovePill(
                        text: '\u63d0\u524d\u914d\u597d\u7684\u83dc\u5355',
                        icon: Icons.menu_book_rounded,
                        color: bannerColor,
                        background: bannerColor.withAlpha(18),
                      ),
                      const SizedBox(width: 8),
                      const LovePill(
                        text: '\u771f\u5b9e\u5c65\u7ea6',
                        icon: Icons.delivery_dining_rounded,
                        color: LoveGirlTheme.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? const _EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title:
                              '\u8fd9\u5bb6\u5e97\u8fd8\u6ca1\u6709\u914d\u7f6e\u5546\u54c1',
                          subtitle:
                              '\u5148\u52a0\u4e00\u4e9b\u5979\u5e38\u70b9\u7684\uff0c\u6d4f\u89c8\u8d77\u6765\u4f1a\u66f4\u50cf\u4e00\u4efd\u4e13\u5c5e\u83dc\u5355\u3002',
                        )
                      : ListView(
                          children: [
                            LoveSectionTitle(
                              title: '\u53ef\u9009\u83dc\u5355',
                              action: '${_products.length} \u9879',
                            ),
                            const SizedBox(height: 12),
                            ..._products.map(_buildProductCard),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = _feedingDisplayText(product['name']);
    final description = _feedingDisplayText(product['description']);
    final price = _safeDouble(product['price']);
    final isWish = product['is_custom'] == true || product['is_wish'] == true;
    final displayName = name.isEmpty ? '未命名商品' : name;
    final category = _safeText(widget.shop['category'], fallback: 'food');

    return GestureDetector(
      onTap: () => _showSendSheet(product),
      child: LoveTicketCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: LoveGirlTheme.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: LoveGirlTheme.primary.withAlpha(24),
                ),
              ),
              child: Icon(
                _categoryIcon(category),
                color: LoveGirlTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: LoveGirlTheme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isWish) ...[
                        const LovePill(
                          text: '\u5979\u70b9\u540d\u60f3\u5403',
                          icon: Icons.favorite_rounded,
                          color: LoveGirlTheme.primary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      const LovePill(
                        text: '\u771f\u5b9e\u5c65\u7ea6',
                        icon: Icons.delivery_dining_rounded,
                        color: LoveGirlTheme.secondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\u00a5${_money(price)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: LoveGirlTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '\u53c2\u8003\u4ef7\u683c',
                  style: TextStyle(
                    fontSize: 10,
                    color: LoveGirlTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: LoveGirlTheme.primary.withAlpha(28),
                    ),
                  ),
                  child: TextButton.icon(
                    onPressed: () => _showSendSheet(product),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('\u9009\u8fd9\u4efd'),
                    style: TextButton.styleFrom(
                      foregroundColor: LoveGirlTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OrderDetailSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onStatusChanged;

  const OrderDetailSheet({
    super.key,
    required this.order,
    this.onStatusChanged,
  });

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  final ApiService _api = ApiService();
  bool _updating = false;

  Map<String, dynamic> get order => widget.order;
  bool get isMine => order['is_mine'] == true;
  bool get isReceived => order['is_received'] == true;

  Future<void> _updateStatus(String newStatus, {Map? extra}) async {
    setState(() => _updating = true);
    try {
      await _api.updateFeedingOrderStatus(
        _safeInt(order['id']),
        newStatus,
        extra: extra?.cast<String, dynamic>(),
      );
      order['status'] = newStatus;
      if (extra != null) {
        order.addAll(extra.cast<String, dynamic>());
      }
      widget.onStatusChanged?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '\u8ba2\u5355\u72b6\u6001\u5df2\u66f4\u65b0\u4e3a ${_statusActionLabel(newStatus)}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      LogService().error(
          'Feeding', '\u66f4\u65b0\u8ba2\u5355\u72b6\u6001\u5931\u8d25: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\u66f4\u65b0\u72b6\u6001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _urge() async {
    setState(() => _updating = true);
    try {
      await _api.urgeFeedingOrder(_safeInt(order['id']));
      widget.onStatusChanged?.call();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '\u5df2\u7ecf\u66ff\u4f60\u53d1\u51fa\u50ac\u5355\u63d0\u9192\u4e86\u3002'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      LogService().error('Feeding', '\u50ac\u5355\u5931\u8d25: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\u50ac\u5355\u63d0\u9192\u53d1\u9001\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _showFulfillDialog() async {
    final amountController = TextEditingController(
      text: _safeText(order['actual_amount']),
    );
    final orderIdController = TextEditingController(
      text: _safeText(order['platform_order_id']),
    );
    final noteController = TextEditingController(
      text: _safeText(order['note']),
    );
    String platform = _safeText(order['platform'], fallback: '\u7f8e\u56e2');
    const platforms = [
      '\u7f8e\u56e2',
      '\u6dd8\u5b9d\u95ea\u8d2d',
      '\u4eac\u4e1c\u5916\u5356',
      '\u997f\u4e86\u4e48',
      '\u5176\u4ed6'
    ];

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Text('\u5b8c\u6210\u5c65\u7ea6\u5e76\u8865\u5145\u4fe1\u606f'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '\u8bb0\u5f55\u8fd9\u6b21\u771f\u5b9e\u4e0b\u5355\u7684\u5e73\u53f0\u548c\u91d1\u989d\uff0c\u540e\u9762\u5c31\u80fd\u5728\u8ba2\u5355\u8be6\u60c5\u91cc\u76f4\u63a5\u770b\u5230\u3002',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: platforms.map((item) {
                      final selected = platform == item;
                      return ChoiceChip(
                        label: Text(item),
                        selected: selected,
                        selectedColor: LoveGirlTheme.primary.withAlpha(28),
                        onSelected: (_) =>
                            setDialogState(() => platform = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '\u5b9e\u9645\u82b1\u8d39\u91d1\u989d',
                      prefixIcon:
                          Icon(Icons.monetization_on_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: orderIdController,
                    decoration: const InputDecoration(
                      labelText: '\u5e73\u53f0\u8ba2\u5355\u53f7',
                      prefixIcon: Icon(Icons.receipt_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '\u5907\u6ce8',
                      prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('\u53d6\u6d88'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final amountText = amountController.text.trim();
                  final amount =
                      amountText.isEmpty ? null : double.tryParse(amountText);
                  if (amountText.isNotEmpty && (amount == null || amount < 0)) {
                    return;
                  }
                  await _api.fulfillFeedingOrder(_safeInt(order['id']), {
                    'platform': platform,
                    'actual_amount': amount,
                    'platform_order_id': orderIdController.text.trim(),
                    'note': noteController.text.trim(),
                  });
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(true);
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('\u5b8c\u6210\u5e76\u4fdd\u5b58'),
              ),
            ],
          ),
        ),
      );

      if (saved == true) {
        order['status'] = 'completed';
        order['platform'] = platform;
        order['actual_amount'] = amountController.text.trim();
        order['platform_order_id'] = orderIdController.text.trim();
        order['note'] = noteController.text.trim();
        widget.onStatusChanged?.call();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '\u8fd9\u6b21\u771f\u5b9e\u4e0b\u5355\u7684\u4fe1\u606f\u5df2\u7ecf\u8bb0\u8fdb\u8ba2\u5355\u91cc\u4e86\u3002'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      LogService().error('Feeding', '\u5b8c\u6210\u5c65\u7ea6\u5931\u8d25: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '\u4fdd\u5b58\u5c65\u7ea6\u4fe1\u606f\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      amountController.dispose();
      orderIdController.dispose();
      noteController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _safeText(order['status'], fallback: 'pending');
    final productName =
        _feedingDisplayText(order['product_name'], fallback: '投喂订单');
    final quantity = _safeInt(order['quantity'], fallback: 1);
    final totalPrice = order['total_price'] ?? 0;
    final message = _safeText(order['message']);
    final shopName =
        _safeText(order['shop_name'], fallback: '\u6295\u5582\u7ad9');
    final shopIcon = _safeText(order['shop_icon']).isEmpty
        ? '\ud83c\udf7d'
        : _safeText(order['shop_icon']);
    final urgeCount = _safeInt(order['urge_count']);
    final platform = _safeText(order['platform']);
    final actualAmount = _safeText(order['actual_amount']);
    final platformOrderId = _safeText(order['platform_order_id']);
    final note = _safeText(order['note']);
    final hasFulfillInfo = platform.isNotEmpty ||
        actualAmount.isNotEmpty ||
        platformOrderId.isNotEmpty;
    final meta = _statusMeta(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: const BoxDecoration(
        color: LoveGirlTheme.paperWarm,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.textMuted.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  LovePill(
                    text: meta.$1,
                    icon: meta.$3,
                    color: meta.$2,
                    background: meta.$2.withAlpha(18),
                  ),
                  LovePill(
                    text: _orderRoleLabel(isMine),
                    icon: isMine
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isMine
                        ? LoveGirlTheme.primary
                        : LoveGirlTheme.secondary,
                    background: isMine
                        ? LoveGirlTheme.primary.withAlpha(14)
                        : LoveGirlTheme.secondary.withAlpha(14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LovePaper(
                padding: const EdgeInsets.all(14),
                elevated: false,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: LoveGirlTheme.primary.withAlpha(16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child:
                          Text(shopIcon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: LoveGirlTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$productName x$quantity',
                            style: const TextStyle(
                              fontSize: 13,
                              color: LoveGirlTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\u00a5${_money(totalPrice)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: LoveGirlTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                LovePaper(
                  padding: const EdgeInsets.all(12),
                  elevated: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: LoveGirlTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: LoveGirlTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasFulfillInfo) ...[
                const SizedBox(height: 12),
                LovePaper(
                  padding: const EdgeInsets.all(12),
                  elevated: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '\u771f\u5b9e\u4e0b\u5355\u4fe1\u606f',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: LoveGirlTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (platform.isNotEmpty)
                        Text(
                          '\u4e0b\u5355\u5e73\u53f0: $platform',
                          style: const TextStyle(
                              color: LoveGirlTheme.textSecondary),
                        ),
                      if (actualAmount.isNotEmpty)
                        Text(
                          '\u5b9e\u9645\u91d1\u989d: \u00a5$actualAmount',
                          style: const TextStyle(
                              color: LoveGirlTheme.textSecondary),
                        ),
                      if (platformOrderId.isNotEmpty)
                        Text(
                          '\u5e73\u53f0\u8ba2\u5355\u53f7: $platformOrderId',
                          style: const TextStyle(
                              color: LoveGirlTheme.textSecondary),
                        ),
                      if (note.isNotEmpty)
                        Text(
                          '\u5907\u6ce8: $note',
                          style: const TextStyle(
                            color: LoveGirlTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              LovePaper(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                elevated: false,
                child: _StatusTimeline(currentStatus: status),
              ),
              const SizedBox(height: 20),
              if (isReceived) ...[
                if (status == 'pending')
                  _ActionButton(
                    label: '\u63a5\u5355',
                    color: const Color(0xFF4CAF50),
                    busy: _updating,
                    onPressed: () => _updateStatus('accepted'),
                  ),
                if (status == 'accepted')
                  _ActionButton(
                    label: '\u8fdb\u5165\u51c6\u5907\u4e2d',
                    color: const Color(0xFF8C63D9),
                    busy: _updating,
                    onPressed: () => _updateStatus('preparing'),
                  ),
                if (status == 'preparing')
                  _ActionButton(
                    label: '\u5207\u5230\u914d\u9001\u4e2d',
                    color: const Color(0xFF2EA8A8),
                    busy: _updating,
                    onPressed: () => _updateStatus('delivering'),
                  ),
                if (status == 'delivering')
                  _ActionButton(
                    label:
                        '\u5b8c\u6210\u5c65\u7ea6\u5e76\u8bb0\u5f55\u771f\u5b9e\u4fe1\u606f',
                    color: const Color(0xFF4CAF50),
                    busy: _updating,
                    onPressed: _showFulfillDialog,
                  ),
                if (!const ['completed', 'cancelled', 'delivering']
                    .contains(status)) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _updating ? null : _showFulfillDialog,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text(
                          '\u76f4\u63a5\u5b8c\u6210\u5e76\u8865\u5145\u771f\u5b9e\u5e73\u53f0\u4fe1\u606f'),
                      style: FilledButton.styleFrom(
                        backgroundColor: LoveGirlTheme.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
              if (isMine &&
                  const ['pending', 'accepted', 'preparing']
                      .contains(status)) ...[
                if (isReceived) const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _updating ? null : _urge,
                    icon: const Icon(Icons.notifications_active_rounded),
                    label: Text(
                      urgeCount > 0
                          ? '\u50ac\u5355 ($urgeCount)'
                          : '\u50ac\u5355\u63d0\u9192',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LoveGirlTheme.orange,
                      side: const BorderSide(color: LoveGirlTheme.orange),
                    ),
                  ),
                ),
              ],
              if (isMine && status == 'pending') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed:
                        _updating ? null : () => _updateStatus('cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LoveGirlTheme.textMuted,
                      side: const BorderSide(color: LoveGirlTheme.separator),
                    ),
                    child: const Text('\u53d6\u6d88\u8ba2\u5355'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: LoveGirlTheme.primary.withAlpha(16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: LoveGirlTheme.primary, size: 18),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: LoveGirlTheme.primary, size: 20),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: LoveGirlTheme.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: LoveGirlTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: LoveGirlTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return LoveTicketCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 42, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: LoveGirlTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
        ),
        child: Text(label),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String currentStatus;

  const _StatusTimeline({required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final steps = <(String, String, IconData)>[
      ('pending', '\u5f85\u63a5\u5355', Icons.pending_actions_rounded),
      ('accepted', '\u5df2\u63a5\u5355', Icons.check_circle_outline),
      ('preparing', '\u51c6\u5907\u4e2d', Icons.restaurant_rounded),
      ('delivering', '\u914d\u9001\u4e2d', Icons.delivery_dining_rounded),
      ('completed', '\u5df2\u5b8c\u6210', Icons.check_circle_rounded),
    ];

    final currentIndex =
        steps.indexWhere((step) => step.$1 == currentStatus).clamp(-1, 999);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isActive = currentIndex >= 0 && index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? LoveGirlTheme.primary
                          : LoveGirlTheme.separator,
                    ),
                    child: Icon(
                      step.$3,
                      size: 14,
                      color: isActive ? Colors.white : LoveGirlTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.$2,
                    style: TextStyle(
                      fontSize: 9,
                      color: isActive
                          ? LoveGirlTheme.primary
                          : LoveGirlTheme.textMuted,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (index < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index < currentIndex
                        ? LoveGirlTheme.primary
                        : LoveGirlTheme.separator,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
