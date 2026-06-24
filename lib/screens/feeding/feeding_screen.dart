import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';

/// 投喂站 —— 情侣虚拟送礼系统
class FeedingScreen extends StatefulWidget {
  const FeedingScreen({super.key});

  @override
  State<FeedingScreen> createState() => _FeedingScreenState();
}

class _FeedingScreenState extends State<FeedingScreen> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _categories = [];
  int _selectedCategoryId = 0; // 0 = 全部
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _recentOrders = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _productsLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getFeedingCategories(),
        _api.getFeedingStats(),
        _api.getFeedingOrders(),
      ]);

      final catData = results[0].data?['data'];
      List rawCats = catData is List ? catData : [];
      _categories = rawCats.map((e) => Map<String, dynamic>.from(e)).toList();

      final statsData = results[1].data?['data'];
      _stats = statsData is Map<String, dynamic> ? statsData : {};

      final orderData = results[2].data?['data'];
      List rawOrders = orderData is List ? orderData : (orderData is Map ? (orderData['list'] ?? []) : []);
      _recentOrders = rawOrders.map((e) => Map<String, dynamic>.from(e)).toList();

      // 首次加载全部商品
      if (_categories.isNotEmpty) {
        await _loadProducts();
      } else {
        _products = [];
      }

      LogService().info('Feeding', '加载分类${_categories.length}个, 商品${_products.length}个, 订单${_recentOrders.length}条');
    } catch (e) {
      setState(() => _error = '加载失败');
      LogService().error('Feeding', '加载失败: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _loadProducts() async {
    setState(() => _productsLoading = true);
    try {
      Response? res;
      if (_selectedCategoryId > 0) {
        res = await _api.getFeedingProducts(_selectedCategoryId);
      } else {
        // 加载全部：并行请求全部分类商品
        final futures = <Future<List<Map<String, dynamic>>>>[];
        for (final cat in _categories) {
          final id = cat['id'];
          if (id == null) continue;
          futures.add(Future<List<Map<String, dynamic>>>(() async {
            try {
              final r = await _api.getFeedingProducts(id);
              final d = r.data?['data'];
              if (d is List) {
                return d.map((e) => Map<String, dynamic>.from(e)).toList();
              }
            } catch (_) {}
            return <Map<String, dynamic>>[];
          }));
        }
        final results = await Future.wait(futures);
        _products = results.expand((list) => list).toList();
        setState(() => _productsLoading = false);
        return;
      }
      final data = res?.data?['data'];
      List raw = data is List ? data : (data is Map ? (data['list'] ?? []) : []);
      _products = raw.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      LogService().error('Feeding', '加载商品失败: $e');
    }
    setState(() => _productsLoading = false);
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
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.textMuted.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 商品图标
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: LoveGirlTheme.gradientSunset,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                product['name'] ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: LoveGirlTheme.textPrimary),
              ),
              if ((product['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  product['description'] ?? '',
                  style: const TextStyle(fontSize: 14, color: LoveGirlTheme.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              // 数量选择器
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildQtyBtn(Icons.remove, () {
                    if (quantity > 1) setSheetState(() => quantity--);
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: LoveGirlTheme.textPrimary),
                    ),
                  ),
                  _buildQtyBtn(Icons.add, () {
                    if (quantity < 99) setSheetState(() => quantity++);
                  }),
                ],
              ),
              const SizedBox(height: 16),
              // 悄悄话输入框
              TextField(
                controller: msgCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '写一句悄悄话...',
                  prefixIcon: const Icon(Icons.edit_note, color: LoveGirlTheme.primary),
                  filled: true,
                  fillColor: LoveGirlTheme.bgLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 确认送出按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _api.createFeedingOrder({
                        'product_id': product['id'],
                        'quantity': quantity,
                        'message': msgCtrl.text.trim(),
                      });
                      LogService().userAction('送出礼物:${product['name']} x$quantity');
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已送出! TA会收到通知哦~'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      LogService().error('Feeding', '送出失败: $e');
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('送出失败，请检查网络后重试'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LoveGirlTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    '确认送出 (${(price * quantity).toStringAsFixed(0)} 爱心豆)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: LoveGirlTheme.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: LoveGirlTheme.primary, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('投喂站'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: _buildError())],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      _buildStatsHeader(),
                      const SizedBox(height: 20),
                      if (_categories.isNotEmpty) ...[
                        _buildCategoryChips(),
                        const SizedBox(height: 16),
                      ],
                      _buildProductGrid(),
                      const SizedBox(height: 24),
                      _buildRecentOrdersSection(),
                    ],
                  ),
                ),
    );
  }

  // ==================== 统计卡片 ====================
  Widget _buildStatsHeader() {
    final totalSent = _stats['total_sent'] ?? 0;
    final totalReceived = _stats['total_received'] ?? 0;
    final lastTime = _stats['last_feeding_time'] ?? '';

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
              Expanded(child: _buildStatItem(Icons.favorite_rounded, '已送出', totalSent, '件')),
              Container(width: 1, height: 40, color: Colors.white.withAlpha(60)),
              Expanded(child: _buildStatItem(Icons.card_giftcard, '收到礼物', totalReceived, '件')),
            ],
          ),
          if (lastTime.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '最近一次投喂: $lastTime',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, dynamic value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: Colors.white, height: 1),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(unit, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  // ==================== 分类胶囊 ====================
  Widget _buildCategoryChips() {
    final allCats = <Map<String, dynamic>>[
      {'id': 0, 'name': '全部', 'icon': '🎁'},
      ..._categories,
    ];

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allCats.length,
        itemBuilder: (ctx, i) {
          final cat = allCats[i];
          final selected = cat['id'] == _selectedCategoryId;
          return Padding(
            padding: EdgeInsets.only(right: 10, left: i == 0 ? 0 : 0),
            child: GestureDetector(
              onTap: () {
                if (_selectedCategoryId == cat['id']) return;
                setState(() => _selectedCategoryId = cat['id'] as int);
                _loadProducts();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? LoveGirlTheme.primary : LoveGirlTheme.primarySoft,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: selected
                      ? [BoxShadow(color: LoveGirlTheme.primary.withAlpha(40), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Text(
                  '${cat['icon'] ?? ''} ${cat['name'] ?? ''}'.trim(),
                  style: TextStyle(
                    color: selected ? Colors.white : LoveGirlTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 商品网格 ====================
  Widget _buildProductGrid() {
    if (_productsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: LoveGirlTheme.textMuted),
              const SizedBox(height: 8),
              const Text('该分类下暂无商品', style: TextStyle(color: LoveGirlTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _products.length,
      itemBuilder: (ctx, i) {
        final p = _products[i];
        return GestureDetector(
          onTap: () => _showSendSheet(p),
          child: Container(
            decoration: BoxDecoration(
              color: LoveGirlTheme.cardLight,
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              boxShadow: LoveGirlTheme.cardShadow(),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: LoveGirlTheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _productIcon(p['name'] ?? ''),
                    color: LoveGirlTheme.primary,
                    size: 26,
                  ),
                ),
                const Spacer(),
                Text(
                  p['name'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LoveGirlTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p['price'] ?? 0} 爱心豆',
                  style: const TextStyle(fontSize: 11, color: LoveGirlTheme.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== 投喂记录 ====================
  Widget _buildRecentOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(color: LoveGirlTheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              const Text('投喂记录', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LoveGirlTheme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_recentOrders.isEmpty)
          _buildEmptyOrders()
        else
          ...List.generate(_recentOrders.length > 5 ? 5 : _recentOrders.length, (i) {
            return _buildOrderCard(_recentOrders[i], i == (_recentOrders.length > 5 ? 4 : _recentOrders.length - 1));
          }),
      ],
    );
  }

  Widget _buildEmptyOrders() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.hourglass_empty, size: 40, color: LoveGirlTheme.textMuted),
            const SizedBox(height: 8),
            const Text('还没有投喂记录哦~', style: TextStyle(color: LoveGirlTheme.textSecondary)),
            const SizedBox(height: 2),
            const Text('快去选一份惊喜吧!', style: TextStyle(fontSize: 12, color: LoveGirlTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isLast) {
    final product = order['product'] is Map ? Map<String, dynamic>.from(order['product']) : <String, dynamic>{};
    final productName = product['name'] ?? order['product_name'] ?? '礼物';
    final senderName = order['sender_name'] ?? order['sender']?['nickname'] ?? '我';
    final time = order['created_at'] ?? '';
    final message = order['message'] ?? '';
    final quantity = order['quantity'] ?? 1;

    String timeStr = '';
    try {
      timeStr = time.toString().substring(5, 16);
    } catch (_) {
      timeStr = time.toString();
    }

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: LoveGirlTheme.pink.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.card_giftcard, color: LoveGirlTheme.pink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: LoveGirlTheme.textPrimary),
                    children: [
                      TextSpan(
                        text: senderName,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: LoveGirlTheme.primary),
                      ),
                      TextSpan(
                        text: ' 送出了 $productName',
                      ),
                      if (quantity is int && quantity > 1)
                        TextSpan(text: ' x$quantity'),
                    ],
                  ),
                ),
                if (message.toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.toString(),
                    style: const TextStyle(fontSize: 12, color: LoveGirlTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(timeStr, style: const TextStyle(fontSize: 11, color: LoveGirlTheme.textMuted)),
        ],
      ),
    );
  }

  // ==================== 错误状态 ====================
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: LoveGirlTheme.textSecondary)),
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

  /// 根据商品名称返回合适的图标
  IconData _productIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('蛋糕') || n.contains('甜品') || n.contains('甜点') || n.contains('糖') || n.contains('巧克力')) {
      return Icons.cake_rounded;
    }
    if (n.contains('奶茶') || n.contains('咖啡') || n.contains('茶') || n.contains('饮') || n.contains('喝')) {
      return Icons.local_cafe_rounded;
    }
    if (n.contains('花') || n.contains('玫瑰') || n.contains('鲜')) {
      return Icons.local_florist_rounded;
    }
    if (n.contains('饭') || n.contains('食') || n.contains('餐') || n.contains('面') || n.contains('饭')) {
      return Icons.restaurant_rounded;
    }
    if (n.contains('熊') || n.contains('玩偶') || n.contains('公仔') || n.contains('娃娃')) {
      return Icons.toys_rounded;
    }
    if (n.contains('电影') || n.contains('票') || n.contains('券')) {
      return Icons.local_movies_rounded;
    }
    if (n.contains('音乐') || n.contains('歌') || n.contains('曲')) {
      return Icons.music_note_rounded;
    }
    if (n.contains('戒指') || n.contains('项链') || n.contains('首饰') || n.contains('珠宝')) {
      return Icons.diamond_rounded;
    }
    if (n.contains('书') || n.contains('读')) {
      return Icons.menu_book_rounded;
    }
    return Icons.card_giftcard;
  }
}
