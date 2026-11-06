import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

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
  final ApiService _api;
  KitchenProvider({ApiService? api}) : _api = api ?? ApiService();
  int? _accountId;
  bool _accountSet = false;
  int _session = 0;
  int _menuRequest = 0;
  int _ordersRequest = 0;
  int _summaryRequest = 0;
  bool _disposed = false;
  static const _accountChanged = '账号已切换，请在当前账号重新操作';

  bool _current(int session) => !_disposed && session == _session;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setAccount(int? id) {
    if (_disposed || (_accountSet && _accountId == id)) return;
    _accountSet = true;
    _accountId = id;
    _session++;
    bound = false;
    partnerName = null;
    mine = [];
    partnerDishes = [];
    incoming = [];
    outgoing = [];
    incomingNew = outgoingActive = 0;
    loading = ordersLoading = placingOrder = false;
    menuLoaded = ordersLoaded = false;
    menuError = ordersError = null;
    cart.clear();
    _updatingOrders.clear();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _session++;
    super.dispose();
  }

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
  bool menuLoaded = false;
  bool ordersLoaded = false;
  bool placingOrder = false;
  final Set<int> _updatingOrders = {};
  bool isOrderBusy(int id) => _updatingOrders.contains(id);
  String? menuError;
  String? ordersError;
  String? get error => menuError ?? ordersError;

  /// 购物车：dishId -> 数量（只针对对方菜品）
  final Map<int, int> cart = {};

  List<KitchenDish> get cartDishes => cart.keys
      .map((id) => partnerDishes.firstWhere(
            (d) => d.id == id,
            orElse: () => const KitchenDish(
                id: -1,
                userId: -1,
                name: '',
                category: '',
                emoji: '',
                price: 0),
          ))
      .where((d) => d.id > 0)
      .toList(growable: false);

  int get cartTotal =>
      cartDishes.fold(0, (sum, d) => sum + d.price * (cart[d.id] ?? 0));

  int get cartCount => cart.values.fold(0, (a, b) => a + b);

  String? _serverMessage(Object err) {
    final data = err is DioException ? err.response?.data : null;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }

  Future<void> loadMenu({bool silent = false}) async {
    final session = _session;
    final request = ++_menuRequest;
    if (!silent || !menuLoaded) {
      loading = true;
      notifyListeners();
    }
    try {
      final res = await _api.getKitchenMenu();
      if (!_current(session) || request != _menuRequest) return;
      final data = res.data?['data'];
      if (data is! Map) throw const FormatException('Invalid menu');
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
      cart.removeWhere((id, _) => partnerDishes.every((d) => d.id != id));
      menuError = null;
      menuLoaded = true;
    } catch (e) {
      if (!_current(session) || request != _menuRequest) return;
      menuError = _serverMessage(e) ?? '菜单加载失败，请稍后再试';
    }
    if (!_current(session) || request != _menuRequest) return;
    loading = false;
    notifyListeners();
  }

  Future<void> loadOrders({bool silent = false}) async {
    final session = _session;
    final request = ++_ordersRequest;
    if (!silent || !ordersLoaded) {
      ordersLoading = true;
      notifyListeners();
    }
    try {
      final res = await _api.getKitchenOrders();
      if (!_current(session) || request != _ordersRequest) return;
      final data = res.data?['data'];
      if (data is! Map) throw const FormatException('Invalid orders');
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
      ordersError = null;
      ordersLoaded = true;
    } catch (e) {
      if (!_current(session) || request != _ordersRequest) return;
      ordersError = _serverMessage(e) ?? '订单加载失败，请稍后再试';
    }
    if (!_current(session) || request != _ordersRequest) return;
    ordersLoading = false;
    notifyListeners();
  }

  Future<void> loadSummary() async {
    final session = _session;
    final request = ++_summaryRequest;
    try {
      final res = await _api.getKitchenSummary();
      if (!_current(session) || request != _summaryRequest) return;
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
    final session = _session;
    await Future.wait([loadMenu(silent: true), loadOrders(silent: true)]);
    if (!_current(session)) return;
    await loadSummary();
  }

  // ---------- 购物车 ----------
  void addToCart(int dishId) {
    if ((cart[dishId] ?? 0) >= 9 || placingOrder) return;
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
    final session = _session;
    try {
      await _api.createKitchenDish(data);
      if (!_current(session)) return _accountChanged;
      await loadMenu(silent: true);
      return _current(session) ? null : _accountChanged;
    } catch (e) {
      if (!_current(session)) return _accountChanged;
      return _serverMessage(e) ?? '菜品保存失败，请稍后再试';
    }
  }

  Future<String?> updateDish(int id, Map data) async {
    final session = _session;
    try {
      await _api.updateKitchenDish(id, data);
      if (!_current(session)) return _accountChanged;
      await loadMenu(silent: true);
      return _current(session) ? null : _accountChanged;
    } catch (e) {
      if (!_current(session)) return _accountChanged;
      return _serverMessage(e) ?? '菜品保存失败，请稍后再试';
    }
  }

  Future<String?> deleteDish(int id) async {
    final session = _session;
    try {
      await _api.deleteKitchenDish(id);
      if (!_current(session)) return _accountChanged;
      cart.remove(id);
      await loadMenu(silent: true);
      return _current(session) ? null : _accountChanged;
    } catch (e) {
      if (!_current(session)) return _accountChanged;
      return _serverMessage(e) ?? '菜品下架失败，请稍后再试';
    }
  }

  // ---------- 订单 ----------
  Future<String?> placeOrder(String? note) async {
    if (placingOrder) return '正在提交，请稍候';
    if (cart.isEmpty) return '购物车是空的';
    final session = _session;
    placingOrder = true;
    notifyListeners();
    try {
      await _api.createKitchenOrder({
        'items': cart.entries
            .map((e) => {'dish_id': e.key, 'quantity': e.value})
            .toList(),
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (!_current(session)) return _accountChanged;
      clearCart();
      await refreshAll();
      return _current(session) ? null : _accountChanged;
    } catch (e) {
      if (!_current(session)) return _accountChanged;
      return _serverMessage(e) ?? '下单失败，请稍后再试';
    } finally {
      if (_current(session)) {
        placingOrder = false;
        _changed();
      }
    }
  }

  Future<String?> updateOrderStatus(int id, String status, {Map? extra}) async {
    if (!_updatingOrders.add(id)) return '正在处理这一餐，请稍候';
    final session = _session;
    notifyListeners();
    try {
      String? previousStatus;
      for (final order in [...incoming, ...outgoing]) {
        if (order.id == id) {
          previousStatus = order.status;
          break;
        }
      }
      await _api.updateKitchenOrderStatus(id, status, extra: {
        if (previousStatus != null) 'expected_status': previousStatus,
        ...?extra,
      });
      if (!_current(session)) return _accountChanged;
      await refreshAll();
      return _current(session) ? null : _accountChanged;
    } catch (e) {
      if (!_current(session)) return _accountChanged;
      if (e is DioException && e.response?.statusCode == 409) {
        await refreshAll();
      }
      return _serverMessage(e) ?? '操作失败，请稍后再试';
    } finally {
      if (_current(session)) {
        _updatingOrders.remove(id);
        _changed();
      }
    }
  }

  Future<(String? url, String? error)> uploadPhoto(String filePath) async {
    final session = _session;
    try {
      final res = await _api.uploadKitchenPhoto(filePath);
      if (!_current(session)) return (null, _accountChanged);
      final data = res.data?['data'];
      if (data is Map && data['url'] != null) {
        return (data['url'].toString(), null);
      }
      return (null, '上传失败，请稍后再试');
    } catch (e) {
      if (!_current(session)) return (null, _accountChanged);
      return (null, _serverMessage(e) ?? '上传失败，请稍后再试');
    }
  }
}
