import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

/// 拼接厨房图片完整地址
String kitchenPhotoUrl(String path, String baseUrl) =>
    path.startsWith('http') ? path : '$baseUrl$path';

/// 情侣厨房菜品
class KitchenDish {
  final int id;
  final int userId;
  final String name;
  final String category;
  final String emoji;
  final String? photoUrl;
  final int price;
  final String? description;

  const KitchenDish({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.emoji,
    this.photoUrl,
    required this.price,
    this.description,
  });

  factory KitchenDish.fromJson(Map<String, dynamic> json) => KitchenDish(
        id: (json['id'] as num?)?.toInt() ?? 0,
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
        category: (json['category'] ?? '家常菜').toString(),
        emoji: (json['emoji'] ?? '🍳').toString(),
        photoUrl: json['photo_url']?.toString(),
        price: (json['price'] as num?)?.toInt() ?? 0,
        description: json['description']?.toString(),
      );
}

/// 订单里的单品快照
class KitchenOrderItem {
  final int dishId;
  final String name;
  final String emoji;
  final int price;
  final int quantity;

  const KitchenOrderItem({
    required this.dishId,
    required this.name,
    required this.emoji,
    required this.price,
    required this.quantity,
  });

  factory KitchenOrderItem.fromJson(Map<String, dynamic> json) =>
      KitchenOrderItem(
        dishId: (json['dish_id'] as num?)?.toInt() ?? 0,
        name: (json['name'] ?? '').toString(),
        emoji: (json['emoji'] ?? '🍳').toString(),
        price: (json['price'] as num?)?.toInt() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toMap() => {
        'dish_id': dishId,
        'quantity': quantity,
      };
}

/// 情侣厨房订单
class KitchenOrder {
  final int id;
  final int ordererId;
  final int cookId;
  final List<KitchenOrderItem> items;
  final int totalPrice;
  final String? note;
  final String status; // placed / accepted / done / cancelled
  final String? photoUrl;
  final bool beansAwarded;
  final String? createdAt;
  final String? doneAt;

  const KitchenOrder({
    required this.id,
    required this.ordererId,
    required this.cookId,
    required this.items,
    required this.totalPrice,
    this.note,
    required this.status,
    this.photoUrl,
    required this.beansAwarded,
    this.createdAt,
    this.doneAt,
  });

  bool get isActive => status == 'placed' || status == 'accepted';

  factory KitchenOrder.fromJson(Map<String, dynamic> json) => KitchenOrder(
        id: (json['id'] as num?)?.toInt() ?? 0,
        ordererId: (json['orderer_id'] as num?)?.toInt() ?? 0,
        cookId: (json['cook_id'] as num?)?.toInt() ?? 0,
        items: json['items'] is List
            ? (json['items'] as List)
                .map((e) =>
                    KitchenOrderItem.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : const [],
        totalPrice: (json['total_price'] as num?)?.toInt() ?? 0,
        note: json['note']?.toString(),
        status: (json['status'] ?? 'placed').toString(),
        photoUrl: json['photo_url']?.toString(),
        beansAwarded:
            json['beans_awarded'] == true || json['beans_awarded'] == 1,
        createdAt: json['created_at']?.toString(),
        doneAt: json['done_at']?.toString(),
      );
}

/// 情侣厨房状态
class KitchenProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool bound = false;
  String? partnerName;
  List<KitchenDish> mine = [];
  List<KitchenDish> partnerDishes = [];
  List<KitchenOrder> incoming = [];
  List<KitchenOrder> outgoing = [];
  int incomingNew = 0;
  int outgoingActive = 0;

  bool loading = false;
  bool ordersLoading = false;
  String? error;

  /// 购物车：dishId -> 数量（只针对对方菜品）
  final Map<int, int> cart = {};

  List<KitchenDish> get cartDishes => cart.keys
      .map((id) => partnerDishes.firstWhere(
            (d) => d.id == id,
            orElse: () => const KitchenDish(
                id: -1, userId: -1, name: '', category: '', emoji: '', price: 0),
          ))
      .where((d) => d.id > 0)
      .toList(growable: false);

  int get cartTotal =>
      cartDishes.fold(0, (sum, d) => sum + d.price * (cart[d.id] ?? 0));

  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  String? _serverMessage(Object err) {
    final data = (err as dynamic).response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return null;
  }

  Future<void> loadMenu({bool silent = false}) async {
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      final res = await _api.getKitchenMenu();
      final data = res.data?['data'];
      if (data is Map) {
        bound = data['bound'] == true;
        final partner = data['partner'];
        partnerName = partner is Map ? partner['nickname']?.toString() : null;
        mine = data['mine'] is List
            ? (data['mine'] as List)
                .map((e) => KitchenDish.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : [];
        partnerDishes = data['partner_dishes'] is List
            ? (data['partner_dishes'] as List)
                .map((e) => KitchenDish.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : [];
        // 清掉购物车里已下架的菜
        cart.removeWhere((id, _) =>
            partnerDishes.every((d) => d.id != id));
        error = null;
      }
    } catch (e) {
      error = _serverMessage(e) ?? '菜单加载失败，请稍后再试';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> loadOrders({bool silent = false}) async {
    if (!silent) {
      ordersLoading = true;
      notifyListeners();
    }
    try {
      final res = await _api.getKitchenOrders();
      final data = res.data?['data'];
      if (data is Map) {
        incoming = data['incoming'] is List
            ? (data['incoming'] as List)
                .map((e) => KitchenOrder.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : [];
        outgoing = data['outgoing'] is List
            ? (data['outgoing'] as List)
                .map((e) => KitchenOrder.fromJson(Map<String, dynamic>.from(e)))
                .toList(growable: false)
            : [];
      }
    } catch (e) {
      error = _serverMessage(e) ?? '订单加载失败，请稍后再试';
    }
    ordersLoading = false;
    notifyListeners();
  }

  Future<void> loadSummary() async {
    try {
      final res = await _api.getKitchenSummary();
      final data = res.data?['data'];
      if (data is Map) {
        bound = data['bound'] == true;
        incomingNew = (data['incoming_new'] as num?)?.toInt() ?? 0;
        outgoingActive = (data['outgoing_active'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    } catch (_) {
      // 静默失败：红点不显示即可
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([loadMenu(silent: true), loadOrders(silent: true)]);
    await loadSummary();
  }

  // ---------- 购物车 ----------
  void addToCart(int dishId) {
    cart[dishId] = (cart[dishId] ?? 0) + 1;
    notifyListeners();
  }

  void removeFromCart(int dishId) {
    final current = cart[dishId] ?? 0;
    if (current <= 1) {
      cart.remove(dishId);
    } else {
      cart[dishId] = current - 1;
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  // ---------- 菜品 ----------
  Future<String?> createDish(Map data) async {
    try {
      await _api.createKitchenDish(data);
      await loadMenu(silent: true);
      return null;
    } catch (e) {
      return _serverMessage(e) ?? '菜品保存失败，请稍后再试';
    }
  }

  Future<String?> updateDish(int id, Map data) async {
    try {
      await _api.updateKitchenDish(id, data);
      await loadMenu(silent: true);
      return null;
    } catch (e) {
      return _serverMessage(e) ?? '菜品保存失败，请稍后再试';
    }
  }

  Future<String?> deleteDish(int id) async {
    try {
      await _api.deleteKitchenDish(id);
      cart.remove(id);
      await loadMenu(silent: true);
      return null;
    } catch (e) {
      return _serverMessage(e) ?? '菜品下架失败，请稍后再试';
    }
  }

  // ---------- 订单 ----------
  Future<String?> placeOrder(String? note) async {
    if (cart.isEmpty) return '购物车是空的';
    try {
      await _api.createKitchenOrder({
        'items': cart.entries
            .map((e) => {'dish_id': e.key, 'quantity': e.value})
            .toList(),
        if (note != null && note.isNotEmpty) 'note': note,
      });
      clearCart();
      await refreshAll();
      return null;
    } catch (e) {
      return _serverMessage(e) ?? '下单失败，请稍后再试';
    }
  }

  Future<String?> updateOrderStatus(int id, String status,
      {Map? extra}) async {
    try {
      await _api.updateKitchenOrderStatus(id, status, extra: extra);
      await refreshAll();
      return null;
    } catch (e) {
      return _serverMessage(e) ?? '操作失败，请稍后再试';
    }
  }

  Future<(String? url, String? error)> uploadPhoto(String filePath) async {
    try {
      final res = await _api.uploadKitchenPhoto(filePath);
      final data = res.data?['data'];
      if (data is Map && data['url'] != null) {
        return (data['url'].toString(), null);
      }
      return (null, '上传失败，请稍后再试');
    } catch (e) {
      return (null, _serverMessage(e) ?? '上传失败，请稍后再试');
    }
  }
}
