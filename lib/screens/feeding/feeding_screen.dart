import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';

/// 投喂站 v2 — 外卖风格的情侣送礼系统
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
  bool _loading = true;
  bool _showingOrders = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // 分别请求，单个失败不影响其他
    try {
      final shopRes = await _api.get('/api/feeding/shops').timeout(const Duration(seconds: 10));
      final shopData = shopRes.data?['data'];
      _shops = shopData is List
          ? shopData.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      LogService().error('Feeding', '加载店铺失败: $e');
      _shops = [];
    }

    try {
      final statsRes = await _api.getFeedingStats().timeout(const Duration(seconds: 10));
      final statsData = statsRes.data?['data'];
      _stats = statsData is Map<String, dynamic> ? statsData : {};
    } catch (e) {
      LogService().error('Feeding', '加载统计失败: $e');
      _stats = {};
    }

    try {
      final orderRes = await _api.getFeedingOrders().timeout(const Duration(seconds: 10));
      final orderData = orderRes.data?['data'];
      List rawOrders = orderData is List
          ? orderData
          : (orderData is Map ? (orderData['list'] ?? []) : []);
      _recentOrders =
          rawOrders.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      LogService().error('Feeding', '加载订单失败: $e');
      _recentOrders = [];
    }

    // 如果三个全部失败才显示错误
    if (_shops.isEmpty && _stats.isEmpty && _recentOrders.isEmpty) {
      setState(() => _error = '加载失败，请检查网络后重试');
    }

    LogService().info('Feeding',
        '加载店铺${_shops.length}个, 订单${_recentOrders.length}条');
    setState(() => _loading = false);
  }

  void _openShop(Map<String, dynamic> shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          shop: shop,
          onOrderCreated: _loadData,
        ),
      ),
    );
  }

  void _showOrderDetail(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderDetailSheet(
        order: order,
        onStatusChanged: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: Text(_showingOrders ? '投喂记录' : '投喂站'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_showingOrders) {
              setState(() => _showingOrders = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_showingOrders ? Icons.store : Icons.receipt_long),
            onPressed: () => setState(() => _showingOrders = !_showingOrders),
            tooltip: _showingOrders ? '返回店铺' : '投喂记录',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: _buildError(),
                      )
                    ],
                  ),
                )
              : _showingOrders
                  ? _buildOrderList()
                  : _buildShopList(),
    );
  }

  // ==================== 店铺列表 ====================
  Widget _buildShopList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _buildStatsHeader(),
          const SizedBox(height: 20),
          _buildSectionTitle('🏪 精选店铺'),
          const SizedBox(height: 12),
          ..._shops.map((shop) => _buildShopCard(shop)),
        ],
      ),
    );
  }

  // ==================== 统计卡片 ====================
  Widget _buildStatsHeader() {
    final totalSent = _stats['total_sent'] ?? 0;
    final totalReceived = _stats['total_received'] ?? 0;
    final pendingOrders = _stats['pending_orders'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: LoveGirlTheme.gradientSunset,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        boxShadow: LoveGirlTheme.cardShadow(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildStatItem(
                      Icons.favorite_rounded, '已送出', totalSent, '件')),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withAlpha(60)),
              Expanded(
                  child: _buildStatItem(
                      Icons.card_giftcard, '收到', totalReceived, '件')),
              Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withAlpha(60)),
              Expanded(
                  child: _buildStatItem(
                      Icons.pending_actions, '待处理', pendingOrders, '单')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String label, dynamic value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  height: 1),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(unit,
                  style:
                      const TextStyle(fontSize: 10, color: Colors.white70)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  // ==================== 店铺卡片 ====================
  Widget _buildShopCard(Map<String, dynamic> shop) {
    final name = shop['name'] ?? '';
    final icon = shop['icon'] ?? '🏪';
    final description = shop['description'] ?? '';
    final category = shop['category'] ?? 'food';
    final bannerColor = _parseColor(shop['banner_color'], LoveGirlTheme.primary);

    return GestureDetector(
      onTap: () => _openShop(shop),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Row(
          children: [
            // 左侧店铺图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: bannerColor.withAlpha(25),
                borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(width: 14),
            // 右侧信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: LoveGirlTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: bannerColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _categoryLabel(category),
                            style: TextStyle(
                              fontSize: 10,
                              color: bannerColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: LoveGirlTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward_ios,
                            size: 12, color: bannerColor),
                        const SizedBox(width: 4),
                        Text(
                          '进店看看',
                          style: TextStyle(
                            fontSize: 12,
                            color: bannerColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  // ==================== 订单列表 ====================
  Widget _buildOrderList() {
    if (_recentOrders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _buildEmptyOrders(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _recentOrders.length,
        itemBuilder: (ctx, i) => _buildOrderCard(_recentOrders[i]),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final productName = order['product_name'] ?? '礼物';
    final senderName = order['sender_name'] ?? '我';
    final quantity = order['quantity'] ?? 1;
    final totalPrice = order['total_price'] ?? order['product_price'] ?? 0;
    final status = order['status'] ?? 'pending';
    final isMine = order['is_mine'] == true;
    final shopName = order['shop_name'] ?? '';
    final shopIcon = order['shop_icon'] ?? '🏪';
    final urgeCount = order['urge_count'] ?? 0;
    final time = order['created_at'] ?? '';

    String timeStr = '';
    try {
      timeStr = time.toString().substring(5, 16);
    } catch (_) {
      timeStr = time.toString();
    }

    final statusInfo = _statusInfo(status);

    return GestureDetector(
      onTap: () => _showOrderDetail(order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：店铺+状态
            Row(
              children: [
                Text(shopIcon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  shopName.isNotEmpty ? shopName : '投喂站',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: LoveGirlTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusInfo.$2.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusInfo.$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusInfo.$2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 商品信息
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.card_giftcard,
                      color: LoveGirlTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: LoveGirlTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'x$quantity  ·  $totalPrice 爱心豆',
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
            // 底部：时间+催单
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: LoveGirlTheme.textMuted,
                  ),
                ),
                if (urgeCount > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.notifications_active,
                      size: 14, color: LoveGirlTheme.orange),
                  const SizedBox(width: 2),
                  Text(
                    '已催单$urgeCount次',
                    style: TextStyle(
                      fontSize: 11,
                      color: LoveGirlTheme.orange,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  isMine ? '我送出的' : 'TA送给我的',
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine
                        ? LoveGirlTheme.primary
                        : LoveGirlTheme.pink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 辅助方法 ====================
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: LoveGirlTheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: LoveGirlTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!,
              style: const TextStyle(color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty,
              size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          const Text('还没有投喂记录',
              style: TextStyle(
                  fontSize: 16, color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 4),
          const Text('去店铺选一份惊喜吧!',
              style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
        ],
      ),
    );
  }

  Color _parseColor(dynamic colorStr, Color fallback) {
    if (colorStr is String && colorStr.startsWith('#')) {
      try {
        return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return fallback;
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'drink':
        return '饮品';
      case 'food':
        return '美食';
      case 'flower':
        return '鲜花';
      case 'gift':
        return '礼物';
      default:
        return '其他';
    }
  }

  (String, Color) _statusInfo(String status) {
    switch (status) {
      case 'pending':
        return ('待接单', LoveGirlTheme.orange);
      case 'accepted':
        return ('已接单', const Color(0xFF2196F3));
      case 'preparing':
        return ('准备中', const Color(0xFF9C27B0));
      case 'delivering':
        return ('配送中', const Color(0xFF00BCD4));
      case 'completed':
        return ('已完成', const Color(0xFF4CAF50));
      case 'cancelled':
        return ('已取消', LoveGirlTheme.textMuted);
      default:
        return (status, LoveGirlTheme.textMuted);
    }
  }
}

// ==================== 店铺详情页 ====================
class ShopDetailScreen extends StatefulWidget {
  final Map<String, dynamic> shop;
  final VoidCallback? onOrderCreated;

  const ShopDetailScreen({super.key, required this.shop, this.onOrderCreated});

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
      final shopId = widget.shop['id'];
      final res = await _api.get('/api/feeding/shops/$shopId/products');
      final data = res.data?['data'];
      _products = data is List
          ? data.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    } catch (e) {
      LogService().error('Feeding', '加载商品失败: $e');
    }
    setState(() => _loading = false);
  }

  void _showSendSheet(Map<String, dynamic> product) {
    int quantity = 1;
    final msgCtrl = TextEditingController();
    final price = (product['price'] ?? 0) as num;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: LoveGirlTheme.cardLight,
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
              const SizedBox(height: 20),
              // 商品信息
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: LoveGirlTheme.gradientSunset,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.card_giftcard,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                product['name'] ?? '',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LoveGirlTheme.textPrimary),
              ),
              if ((product['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  product['description'] ?? '',
                  style: const TextStyle(
                      fontSize: 13, color: LoveGirlTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              // 数量选择
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _qtyBtn(Icons.remove, () {
                    if (quantity > 1) setSheetState(() => quantity--);
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('$quantity',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: LoveGirlTheme.textPrimary)),
                  ),
                  _qtyBtn(Icons.add, () {
                    if (quantity < 99) setSheetState(() => quantity++);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // 悄悄话
              TextField(
                controller: msgCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '写一句悄悄话...',
                  prefixIcon: const Icon(Icons.edit_note,
                      color: LoveGirlTheme.primary),
                  filled: true,
                  fillColor: LoveGirlTheme.bgLight,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 下单按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _api.createFeedingOrder({
                        'product_id': product['id'],
                        'shop_id': widget.shop['id'],
                        'quantity': quantity,
                        'message': msgCtrl.text.trim(),
                      });
                      LogService().userAction(
                          '送出礼物:${product['name']} x$quantity');
                      if (ctx.mounted) Navigator.pop(ctx);
                      widget.onOrderCreated?.call();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已下单! TA会收到通知哦~'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      LogService().error('Feeding', '下单失败: $e');
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('下单失败，请检查网络'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LoveGirlTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    '确认下单 (${(price * quantity).toStringAsFixed(0)} 爱心豆)',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: LoveGirlTheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: LoveGirlTheme.primary, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shopName = widget.shop['name'] ?? '';
    final shopIcon = widget.shop['icon'] ?? '🏪';
    final shopDesc = widget.shop['description'] ?? '';
    final bannerColor =
        _parseColor(widget.shop['banner_color'], LoveGirlTheme.primary);

    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: CustomScrollView(
        slivers: [
          // 店铺头部
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: bannerColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bannerColor, bannerColor.withAlpha(180)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(shopIcon, style: const TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (shopDesc.isNotEmpty)
                        Text(
                          shopDesc,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 商品列表
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_products.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 48, color: LoveGirlTheme.textMuted),
                    const SizedBox(height: 8),
                    const Text('该店铺暂无商品',
                        style: TextStyle(color: LoveGirlTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildProductCard(_products[i]),
                  childCount: _products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? '';
    final description = product['description'] ?? '';
    final price = product['price'] ?? 0;

    return GestureDetector(
      onTap: () => _showSendSheet(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
          boxShadow: LoveGirlTheme.cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: LoveGirlTheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.card_giftcard,
                  color: LoveGirlTheme.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$price',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: LoveGirlTheme.primary,
                  ),
                ),
                const Text(
                  '爱心豆',
                  style:
                      TextStyle(fontSize: 10, color: LoveGirlTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(dynamic colorStr, Color fallback) {
    if (colorStr is String && colorStr.startsWith('#')) {
      try {
        return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return fallback;
  }
}

// ==================== 订单详情弹窗 ====================
class OrderDetailSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onStatusChanged;

  const OrderDetailSheet({super.key, required this.order, this.onStatusChanged});

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  final ApiService _api = ApiService();
  bool _updating = false;

  Map<String, dynamic> get order => widget.order;
  bool get isMine => order['is_mine'] == true;
  bool get isReceived => order['is_received'] == true;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    try {
      await _api.put('/api/feeding/orders/${order['id']}/status',
          data: {'status': newStatus});
      widget.onStatusChanged?.call();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('订单已${_statusLabel(newStatus)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      LogService().error('Feeding', '更新订单状态失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('操作失败，请重试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _updating = false);
  }

  Future<void> _urge() async {
    try {
      await _api.post('/api/feeding/orders/${order['id']}/urge');
      widget.onStatusChanged?.call();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已催单! TA会收到提醒~'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      LogService().error('Feeding', '催单失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'pending';
    final productName = order['product_name'] ?? '礼物';
    final quantity = order['quantity'] ?? 1;
    final totalPrice = order['total_price'] ?? 0;
    final message = order['message'] ?? '';
    final shopName = order['shop_name'] ?? '投喂站';
    final shopIcon = order['shop_icon'] ?? '🏪';
    final urgeCount = order['urge_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: const BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
          // 订单标题
          Row(
            children: [
              Text(shopIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: LoveGirlTheme.textPrimary,
                      ),
                    ),
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
                '$totalPrice 爱心豆',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: LoveGirlTheme.primary,
                ),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LoveGirlTheme.bgLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '💌 $message',
                style: const TextStyle(
                  fontSize: 14,
                  color: LoveGirlTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // 状态时间线
          _buildStatusTimeline(status),
          const SizedBox(height: 20),
          // 操作按钮
          if (isReceived) ...[
            // 接收者的操作
            if (status == 'pending')
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _updating ? null : () => _updateStatus('accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('接单'),
                ),
              ),
            if (status == 'accepted')
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed:
                      _updating ? null : () => _updateStatus('preparing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('开始准备'),
                ),
              ),
            if (status == 'preparing')
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed:
                      _updating ? null : () => _updateStatus('delivering'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('开始配送'),
                ),
              ),
            if (status == 'delivering')
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed:
                      _updating ? null : () => _updateStatus('completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('确认送达'),
                ),
              ),
          ],
          if (isMine && ['pending', 'accepted', 'preparing'].contains(status))
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _urge,
                icon: const Icon(Icons.notifications_active),
                label: Text('催单${urgeCount > 0 ? ' (已催$urgeCount次)' : ''}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LoveGirlTheme.orange,
                  side: const BorderSide(color: LoveGirlTheme.orange),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (isMine && status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: _updating ? null : () => _updateStatus('cancelled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LoveGirlTheme.textMuted,
                    side: BorderSide(color: LoveGirlTheme.separator),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('取消订单'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final steps = [
      ('pending', '待接单', Icons.pending_actions),
      ('accepted', '已接单', Icons.check_circle_outline),
      ('preparing', '准备中', Icons.restaurant),
      ('delivering', '配送中', Icons.delivery_dining),
      ('completed', '已完成', Icons.check_circle),
    ];

    final currentIndex =
        steps.indexWhere((s) => s.$1 == currentStatus);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isActive = i <= currentIndex;
        final isCurrent = i == currentIndex;

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
                          isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i < currentIndex
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

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return '接单';
      case 'preparing':
        return '开始准备';
      case 'delivering':
        return '开始配送';
      case 'completed':
        return '确认送达';
      case 'cancelled':
        return '取消';
      default:
        return status;
    }
  }
}
