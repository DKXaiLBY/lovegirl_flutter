import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/wardrobe.dart';
import '../services/api_service.dart';

/// 筛选状态（P10）：会话内保留，退出衣柜模块重置（决策 D6）
class WardrobeFilter {
  String? temperature;
  String? category;
  String? color;
  final Set<String> occasions = {};
  final Set<String> styles = {};

  /// 状态多选；默认只看"在柜"，勾选"退役"才出现（v1.0 两态）
  final Set<String> statuses = {'在柜'};

  /// 搜索词（MIROIR 化：品牌/类别文字模糊匹配）
  String query = '';

  bool get isDefault =>
      temperature == null &&
      category == null &&
      color == null &&
      occasions.isEmpty &&
      styles.isEmpty &&
      statuses.length == 1 &&
      statuses.contains('在柜') &&
      query.isEmpty;

  void reset() {
    temperature = null;
    category = null;
    color = null;
    occasions.clear();
    styles.clear();
    statuses
      ..clear()
      ..add('在柜');
    query = '';
  }
}

class WardrobeProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<WardrobeItem> items = [];
  List<WardrobeOutfit> outfits = [];
  List<WardrobeAvatar> avatars = [];
  bool loading = false;
  String? error;
  final WardrobeFilter filter = WardrobeFilter();

  /// 「今天」胶囊数据（天气取不到则两者皆 null → 隐藏，决策 Q6）
  String? todayTemp;
  String? todayBand;

  /// 抠图能力位（M2a）：person=形象抠图；object=衣服抠图（换装白板前置）
  bool bgEnabled = false;
  bool bgPerson = false;
  bool bgObject = false;

  /// 新增成功后滚动定位目标
  int? focusItemId;

  String? lastCategory;

  static const _prefCity = 'weather_city';
  static const _prefLastCategory = 'wn_last_category';

  String get todayStr {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    await _loadPrefs();
    await Future.wait(
        [_loadItems(), _loadOutfits(), _loadAvatars(), _loadBg(), _loadWeather()]);
    loading = false;
    notifyListeners();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lastCategory = prefs.getString(_prefLastCategory);
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    try {
      final res = await _api.getWardrobeItems();
      final data = res.data?['data'];
      items = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => WardrobeItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [];
    } catch (e) {
      error = '衣柜加载失败，下拉重试';
    }
  }

  Future<void> _loadOutfits() async {
    try {
      final res = await _api.getWardrobeOutfits();
      final data = res.data?['data'];
      outfits = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => WardrobeOutfit.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [];
    } catch (_) {}
  }

  Future<void> _loadBg() async {
    try {
      final res = await _api.getWardrobeBgStatus();
      final data = res.data?['data'];
      bgEnabled = data is Map && data['enabled'] == true;
      bgPerson = data is Map && data['person'] == true;
      bgObject = data is Map && data['object'] == true;
    } catch (_) {
      bgEnabled = false;
      bgPerson = false;
      bgObject = false;
    }
  }

  Future<void> _loadAvatars() async {
    try {
      final res = await _api.getWardrobeAvatars();
      final data = res.data?['data'];
      avatars = (data is List)
          ? data
              .whereType<Map>()
              .map((e) => WardrobeAvatar.fromJson(e.cast<String, dynamic>()))
              .toList()
          : [];
    } catch (_) {}
  }

  WardrobeAvatar? get defaultAvatar {
    for (final a in avatars) {
      if (a.isDefault) return a;
    }
    return avatars.isEmpty ? null : avatars.first;
  }

  Future<String?> addAvatar(String filePath) async {
    try {
      await _api.createWardrobeAvatar(filePath);
      await _loadAvatars();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '上传失败，再试一次');
    }
  }

  /// 上传后自动人像抠图并回写；失败返回 null（不阻断，可重试）
  Future<String?> cutoutAvatar(int id, String filePath) async {
    try {
      final res = await _api.removeWardrobeBg(filePath, 'person');
      final cutoutUrl = res.data?['data']?['cutoutUrl']?.toString();
      if (cutoutUrl != null && cutoutUrl.isNotEmpty) {
        await _api.saveWardrobeAvatarCutout(id, cutoutUrl);
        await _loadAvatars();
        notifyListeners();
      }
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '抠图失败了，稍后可在形象页重试');
    }
  }

  /// 对服务器已有形象原图直接抠图（avatarId 模式，服务端自动回写）
  Future<String?> cutoutAvatarFromExisting(WardrobeAvatar a) async {
    try {
      await _api.cutoutWardrobeAvatar(a.id);
      await _loadAvatars();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '抠图失败了，稍后重试一次');
    }
  }

  /// 单品抠图（object 能力位）：保存后自动补抠/详情页手动补抠。
  /// 返回 null=成功；失败返回错误文案（自动补抠调用方忽略返回值即保持静默）
  Future<String?> cutoutItem(int itemId) async {
    if (!bgObject) return '衣服抠图服务不可用';
    try {
      await _api.cutoutWardrobeItem(itemId);
      await _loadItems();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '抠图失败了，稍后重试一次');
    }
  }

  bool _layoutSaving = false;
  final Map<int, String> _layoutPending = {}; // itemId -> 最新 payload（在飞合并）

  /// 白板位置记忆（W1）：就地更新内存副本（P1-5 会话内立即对位），
  /// 在飞请求合并去重（同件只留最新，防旧覆盖新）；服务器 404/失败静默
  Future<void> saveItemLayout(int itemId, String layoutJson) async {
    final parsed = WardrobeItemLayout.parse(layoutJson);
    final i = items.indexWhere((e) => e.id == itemId);
    if (i >= 0) {
      items[i] = items[i].copyWith(itemLayout: parsed);
      notifyListeners();
    }
    _layoutPending[itemId] = layoutJson;
    if (_layoutSaving) return;
    _layoutSaving = true;
    try {
      while (_layoutPending.isNotEmpty) {
        final batch = Map.of(_layoutPending);
        _layoutPending.clear();
        for (final e in batch.entries) {
          try {
            await _api.saveWardrobeItemLayout(e.key, e.value);
          } catch (_) {} // 静默：位置记忆是增强能力
        }
      }
    } finally {
      _layoutSaving = false;
    }
  }

  Future<String?> setAvatarDefault(int id) async {
    try {
      await _api.setWardrobeAvatarDefault(id);
      await _loadAvatars();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '操作失败，再试一次');
    }
  }

  Future<String?> deleteAvatar(int id) async {
    try {
      await _api.deleteWardrobeAvatar(id);
      await _loadAvatars();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '删除失败，再试一次');
    }
  }

  Future<void> _loadWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final city = prefs.getString(_prefCity);
      if (city == null || city.isEmpty) return;
      final res = await _api.getTodayWeather(city);
      final data = res.data?['data'];
      if (data is Map) {
        final t = data['temperature'] ?? data['temp'];
        final cond = data['weather'] ?? data['condition'];
        final tempNum = num.tryParse(t?.toString() ?? '');
        if (tempNum != null) {
          todayTemp = tempNum.round().toString();
          todayBand = WardrobeTax.tempToBand(tempNum);
        }
        if (cond != null && todayBand == null) {
          // 没有温度时按天气现象粗略兜底
          final s = cond.toString();
          todayBand = s.contains('雨') || s.contains('雪') || s.contains('冷')
              ? '凉爽'
              : s.contains('晴') || s.contains('热')
                  ? '温暖'
                  : null;
        }
      }
    } catch (_) {}
  }

  // ---------- 筛选与分组 ----------

  bool _match(WardrobeItem it) {
    if (!filter.statuses.contains(it.status)) return false;
    if (filter.category != null && it.category != filter.category) return false;
    if (filter.temperature != null && it.temperature != filter.temperature) {
      return false;
    }
    if (filter.color != null && it.color != filter.color) return false;
    if (filter.occasions.isNotEmpty &&
        !filter.occasions.every(it.occasions.contains)) {
      return false;
    }
    if (filter.styles.isNotEmpty && !filter.styles.every(it.styles.contains)) {
      return false;
    }
    // MIROIR 化搜索：品牌/类别/颜色文字模糊匹配
    final q = filter.query.toLowerCase();
    if (q.isNotEmpty) {
      final inBrand = (it.brand ?? '').toLowerCase().contains(q);
      final inCategory = it.category.contains(filter.query);
      final inColor = (it.color ?? '').contains(filter.query);
      if (!inBrand && !inCategory && !inColor) return false;
    }
    return true;
  }

  List<WardrobeItem> get filteredItems =>
      items.where(_match).toList(growable: false);

  /// 筛选结果为 0（有单品但被筛光）→ P1 显示"没有匹配的衣服"
  bool get anyVisible => filteredItems.isNotEmpty;

  /// 8 类固定顺序、空节隐藏、节内添加时间倒序（服务器已倒序）
  Map<String, List<WardrobeItem>> get groupedItems {
    final map = <String, List<WardrobeItem>>{};
    for (final cat in WardrobeTax.categories) {
      final list = filteredItems.where((e) => e.category == cat).toList();
      if (list.isNotEmpty) map[cat] = list;
    }
    return map;
  }

  bool get hasAnyItem => items.isNotEmpty;

  List<WardrobeItem> get inCabItems =>
      items.where((e) => !e.retired).toList(growable: false);

  List<TimelineGroup> get timeline => groupOutfits(outfits, DateTime.now());

  void applyFilter() => notifyListeners();

  WardrobeItem? itemById(int id) {
    for (final it in items) {
      if (it.id == id) return it;
    }
    return null;
  }

  /// P3 关联穿搭列表：按 outfits.itemIds 客户端推导（M1 方案，不加接口）
  List<WardrobeOutfit> outfitsOfItem(int itemId) =>
      outfits.where((o) => o.itemIds.contains(itemId)).toList();

  // ---------- 单品动作 ----------

  Map<String, String> _itemFields({
    required String category,
    String? temperature,
    String? color,
    required List<String> occasions,
    required List<String> styles,
    String? brand,
    String? price,
  }) =>
      {
        'category': category,
        'temperature': temperature ?? '',
        'color': color ?? '',
        'occasions': jsonEncode(occasions),
        'styles': jsonEncode(styles),
        'brand': brand ?? '',
        'price': price ?? '',
      };

  Future<String?> addItem({
    required String filePath,
    required String category,
    String? temperature,
    String? color,
    List<String> occasions = const [],
    List<String> styles = const [],
    String? brand,
    String? price,
  }) async {
    try {
      final res = await _api.saveWardrobeItem(
          filePath,
          _itemFields(
            category: category,
            temperature: temperature,
            color: color,
            occasions: occasions,
            styles: styles,
            brand: brand,
            price: price,
          ));
      final id = (res.data?['data']?['id'] as num?)?.toInt();
      focusItemId = id;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefLastCategory, category);
      } catch (_) {}
      await _loadItems();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '保存失败，再试一次');
    }
  }

  Future<String?> updateItem(
    int id, {
    String? filePath,
    required String category,
    String? temperature,
    String? color,
    List<String> occasions = const [],
    List<String> styles = const [],
    String? brand,
    String? price,
  }) async {
    try {
      if (filePath != null) {
        await _api.saveWardrobeItem(
            filePath,
            _itemFields(
              category: category,
              temperature: temperature,
              color: color,
              occasions: occasions,
              styles: styles,
              brand: brand,
              price: price,
            ),
            id: id);
      } else {
        await _api.updateWardrobeItemFields(
            id,
            _itemFields(
              category: category,
              temperature: temperature,
              color: color,
              occasions: occasions,
              styles: styles,
              brand: brand,
              price: price,
            ));
      }
      await _loadItems();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '保存失败，再试一次');
    }
  }

  Future<String?> setItemStatus(int id, String status) async {
    try {
      await _api.setWardrobeItemStatus(id, status);
      await _loadItems();
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '操作失败，再试一次');
    }
  }

  Future<String?> deleteItem(int id) async {
    try {
      await _api.deleteWardrobeItem(id);
      await Future.wait([_loadItems(), _loadOutfits()]);
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '删除失败，再试一次');
    }
  }

  // ---------- 穿搭动作 ----------

  Future<String?> createOutfit({
    String? filePath,
    required String source,
    required String wornDate,
    List<int> itemIds = const [],
    String? note,
  }) async {
    try {
      await _api.createWardrobeOutfit({
        'source': source,
        'wornDate': wornDate,
        'note': note ?? '',
        'itemIds': jsonEncode(itemIds),
      }, filePath: filePath);
      await Future.wait([_loadItems(), _loadOutfits()]);
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '保存失败，再试一次');
    }
  }

  Future<String?> updateOutfit(
    int id, {
    String? filePath,
    required String wornDate,
    List<int>? itemIds,
    String? note,
  }) async {
    try {
      await _api.updateWardrobeOutfit(id, {
        'wornDate': wornDate,
        'note': note ?? '',
        if (itemIds != null) 'itemIds': jsonEncode(itemIds),
      }, filePath: filePath);
      await Future.wait([_loadItems(), _loadOutfits()]);
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '保存失败，再试一次');
    }
  }

  Future<String?> setOutfitStatus(int id, String status) async {
    try {
      await _api.setWardrobeOutfitStatus(id, status);
      await Future.wait([_loadItems(), _loadOutfits()]);
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '操作失败，再试一次');
    }
  }

  Future<String?> deleteOutfit(int id) async {
    try {
      await _api.deleteWardrobeOutfit(id);
      await Future.wait([_loadItems(), _loadOutfits()]);
      notifyListeners();
      return null;
    } catch (e) {
      return extractServerMessage(e, fallback: '删除失败，再试一次');
    }
  }

  /// 退出模块时重置筛选（决策 D6）
  void resetOnExit() {
    filter.reset();
    focusItemId = null;
  }
}
