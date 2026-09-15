import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';

class AdminFeedingScreen extends StatefulWidget {
  const AdminFeedingScreen({super.key});

  @override
  State<AdminFeedingScreen> createState() => _AdminFeedingScreenState();
}

class _AdminFeedingScreenState extends State<AdminFeedingScreen> {
  final ApiService _api = ApiService();
  bool _loadingShops = true;
  bool _loadingProducts = false;
  String? _error;
  List<Map<String, dynamic>> _shops = const [];
  List<Map<String, dynamic>> _products = const [];
  int? _selectedShopId;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _loadingShops = true;
      _error = null;
    });
    try {
      final res = await _api.getAdminShops(includeInactive: true);
      final shops = _listFromData(res.data?['data']);
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _selectedShopId = shops.any((s) => _idOf(s) == _selectedShopId)
            ? _selectedShopId
            : (shops.isEmpty ? null : _idOf(shops.first));
        _loadingShops = false;
      });
      if (_selectedShopId != null) {
        await _loadProducts(_selectedShopId!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '店铺加载失败';
        _loadingShops = false;
      });
    }
  }

  Future<void> _loadProducts(int shopId) async {
    setState(() {
      _loadingProducts = true;
      _error = null;
    });
    try {
      final res = await _api.getAdminProducts(shopId, includeInactive: true);
      if (!mounted) return;
      setState(() {
        _products = _listFromData(res.data?['data']);
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '商品加载失败';
        _loadingProducts = false;
      });
    }
  }

  List<Map<String, dynamic>> _listFromData(dynamic data) {
    final list = data is Map ? data['list'] : data;
    return list is List
        ? list
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
  }

  int _idOf(Map<String, dynamic> item) =>
      int.tryParse('${item['id'] ?? 0}') ?? 0;

  Future<void> _saveShop([Map<String, dynamic>? shop]) async {
    final name = TextEditingController(text: shop?['name']?.toString() ?? '');
    final icon = TextEditingController(text: shop?['icon']?.toString() ?? '');
    final description =
        TextEditingController(text: shop?['description']?.toString() ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(shop == null ? '新增店铺' : '编辑店铺'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '店铺名称'),
                ),
                TextField(
                  controller: icon,
                  decoration: const InputDecoration(labelText: '图标'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: '描述'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final payload = {
                  'name': name.text.trim(),
                  if (icon.text.trim().isNotEmpty) 'icon': icon.text.trim(),
                  if (description.text.trim().isNotEmpty)
                    'description': description.text.trim(),
                };
                if (shop == null) {
                  await _api.createAdminShop(payload);
                } else {
                  await _api.updateAdminShop(_idOf(shop), payload);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (saved == true) await _loadShops();
    } finally {
      name.dispose();
      icon.dispose();
      description.dispose();
    }
  }

  Future<void> _saveProduct([Map<String, dynamic>? product]) async {
    final shopId = _selectedShopId;
    if (shopId == null) return;
    final name =
        TextEditingController(text: product?['name']?.toString() ?? '');
    final price =
        TextEditingController(text: product?['price']?.toString() ?? '');
    final category =
        TextEditingController(text: product?['category']?.toString() ?? '');
    final imageUrl =
        TextEditingController(text: product?['image_url']?.toString() ?? '');
    final description =
        TextEditingController(text: product?['description']?.toString() ?? '');
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(product == null ? '新增商品' : '编辑商品'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '商品名称'),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '价格'),
                ),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: '分类'),
                ),
                TextField(
                  controller: imageUrl,
                  decoration: const InputDecoration(labelText: '图片地址'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: '描述'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(price.text.trim());
                if (name.text.trim().isEmpty || amount == null || amount < 0) {
                  return;
                }
                final payload = {
                  'name': name.text.trim(),
                  'price': amount,
                  if (category.text.trim().isNotEmpty)
                    'category': category.text.trim(),
                  if (imageUrl.text.trim().isNotEmpty)
                    'image_url': imageUrl.text.trim(),
                  if (description.text.trim().isNotEmpty)
                    'description': description.text.trim(),
                };
                if (product == null) {
                  await _api.createAdminProduct(shopId, payload);
                } else {
                  await _api.updateAdminProduct(_idOf(product), payload);
                }
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (saved == true) await _loadProducts(shopId);
    } finally {
      name.dispose();
      price.dispose();
      category.dispose();
      imageUrl.dispose();
      description.dispose();
    }
  }

  Future<void> _disableShop(Map<String, dynamic> shop) async {
    await _api.deleteAdminShop(_idOf(shop));
    await _loadShops();
  }

  Future<void> _toggleProduct(Map<String, dynamic> product) async {
    final shopId = _selectedShopId;
    if (shopId == null) return;
    final active = product['is_active'] == true || product['is_active'] == 1;
    await _api.toggleAdminProduct(_idOf(product), isActive: !active);
    await _loadProducts(shopId);
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final shopId = _selectedShopId;
    if (shopId == null) return;
    await _api.deleteAdminProduct(_idOf(product));
    await _loadProducts(shopId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedShop = _shops
        .where((shop) => _idOf(shop) == _selectedShopId)
        .cast<Map<String, dynamic>?>()
        .firstOrNull;

    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('商品管理'),
        backgroundColor: LoveGirlTheme.bgLight,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loadingShops ? null : _loadShops,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _selectedShopId == null ? _saveShop : _saveProduct,
        child: Icon(_selectedShopId == null ? Icons.storefront : Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadShops,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          children: [
            if (_error != null) ...[
              LovePaper(
                child: Text(
                  _error!,
                  style: const TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Expanded(
                  child: LoveSectionTitle(title: '店铺'),
                ),
                TextButton.icon(
                  onPressed: () => _saveShop(),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('新增'),
                ),
              ],
            ),
            if (_loadingShops)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_shops.isEmpty)
              const LovePaper(
                child: Text(
                  '暂无店铺，请先新增店铺',
                  style: TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _shops.map((shop) {
                  final id = _idOf(shop);
                  final active =
                      shop['is_active'] == true || shop['is_active'] == 1;
                  return ChoiceChip(
                    label: Text(
                      '${shop['name'] ?? '未命名'}${active ? '' : '（停用）'}',
                    ),
                    selected: id == _selectedShopId,
                    onSelected: (_) {
                      setState(() => _selectedShopId = id);
                      _loadProducts(id);
                    },
                  );
                }).toList(),
              ),
            if (selectedShop != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _saveShop(selectedShop),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑店铺'),
                  ),
                  TextButton.icon(
                    onPressed: () => _disableShop(selectedShop),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('停用店铺'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: LoveSectionTitle(title: '商品'),
                ),
                TextButton.icon(
                  onPressed:
                      _selectedShopId == null ? null : () => _saveProduct(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新增'),
                ),
              ],
            ),
            if (_loadingProducts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_selectedShopId == null)
              const LovePaper(
                child: Text(
                  '请选择店铺',
                  style: TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              )
            else if (_products.isEmpty)
              const LovePaper(
                child: Text(
                  '暂无商品',
                  style: TextStyle(color: LoveGirlTheme.textSecondary),
                ),
              )
            else
              ..._products.map(_productTile),
          ],
        ),
      ),
    );
  }

  Widget _productTile(Map<String, dynamic> product) {
    final active = product['is_active'] == true || product['is_active'] == 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LovePaper(
        elevated: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? '未命名商品',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LoveGirlTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product['category'] ?? '默认'} · ${product['price'] ?? 0} · ${active ? '上架' : '下架'}',
                    style: const TextStyle(color: LoveGirlTheme.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '编辑',
              onPressed: () => _saveProduct(product),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: active ? '下架' : '上架',
              onPressed: () => _toggleProduct(product),
              icon: Icon(active
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
            ),
            IconButton(
              tooltip: '停用',
              onPressed: () => _deleteProduct(product),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
