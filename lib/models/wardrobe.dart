// 电子衣柜数据模型（M1）— 口径见 docs/wardrobe-interaction.md v1.0
// 单品两态（在柜/退役）；穿搭实拍即已通过、组合 待确认⇄已通过；
// 日期在未来 = 计划（叠加显示，非独立状态）。
import 'dart:convert';

/// 标签枚举（与服务器白名单一致）
class WardrobeTax {
  WardrobeTax._();

  static const List<String> categories = [
    '上装', '裤装', '裙装', '外套', '鞋子', '包袋', '配饰', '连体装',
  ];
  static const List<String> temperatures = ['炎热', '温暖', '凉爽', '寒冷'];
  static const List<String> colors = [
    '红', '橙', '黄', '绿', '蓝', '紫', '粉', '黑白灰', '棕', '杂色',
  ];
  static const List<String> occasions = [
    '日常', '上班', '约会', '运动', '正式', '居家', '旅行',
  ];
  static const List<String> styles = [
    '休闲', '甜美', '简约', '运动', '复古', '正式', '潮酷',
  ];

  /// 温度数值 → 四档（整数℃取档无缝隙，PRD §3.2）
  static String tempToBand(num c) {
    if (c >= 28) return '炎热';
    if (c >= 20) return '温暖';
    if (c >= 10) return '凉爽';
    return '寒冷';
  }
}

/// 服务器图片路径 → 可访问 URL
String wnImgUrl(String? path, {String? baseUrl}) {
  if (path == null || path.isEmpty) return '';
  return path.startsWith('http') ? path : '${baseUrl ?? ''}$path';
}

class WardrobeItem {
  final int id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String category;
  final String? temperature;
  final List<String> occasions;
  final List<String> styles;
  final String? color;
  final String? brand;
  final double? price;
  final String status; // 在柜 / 退役
  final int wearCount;
  final int refCount; // 被多少条穿搭引用（详情接口）
  final bool bgRemoved; // 已抠图（M2a）
  final String? cutoutUrl; // 抠图透明图（M2a）
  final Map<String, WardrobeItemLayout>? itemLayout; // 白板位置记忆 {avatarId: 布局}（W1）
  final DateTime? createdAt;

  const WardrobeItem({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.category,
    this.temperature,
    this.occasions = const [],
    this.styles = const [],
    this.color,
    this.brand,
    this.price,
    required this.status,
    this.wearCount = 0,
    this.refCount = 0,
    this.bgRemoved = false,
    this.cutoutUrl,
    this.itemLayout,
    this.createdAt,
  });

  bool get retired => status == '退役';

  /// 换装白板/透明展示用抠图图
  bool get hasCutout => bgRemoved && (cutoutUrl?.isNotEmpty ?? false);

  factory WardrobeItem.fromJson(Map<String, dynamic> j) => WardrobeItem(
        id: _asInt(j['id']),
        imageUrl: (j['image_url'] ?? '').toString(),
        thumbnailUrl: j['thumbnail_url']?.toString(),
        category: (j['category'] ?? '').toString(),
        temperature: j['temperature']?.toString(),
        occasions: _strList(j['occasions']),
        styles: _strList(j['styles']),
        color: j['color']?.toString(),
        brand: j['brand']?.toString(),
        // DECIMAL 列 mysql2 返回字符串（如 "100.00"），必须 tryParse——
        // as num 会在单个字段上炸掉整个列表解析（v3.35.1 线上事故）
        price: _asDouble(j['price']),
        status: (j['status'] ?? '在柜').toString(),
        wearCount: _asInt(j['wear_count']),
        refCount: _asInt(j['outfit_refs_count']),
        bgRemoved: _asInt(j['bg_removed']) == 1,
        cutoutUrl: j['cutout_url']?.toString(),
        itemLayout: WardrobeItemLayout.parse(j['item_layout']),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );

  /// 白板拖缩后就地更新位置记忆（provider 内存副本用，P1-5）
  WardrobeItem copyWith({Map<String, WardrobeItemLayout>? itemLayout}) =>
      WardrobeItem(
        id: id,
        imageUrl: imageUrl,
        thumbnailUrl: thumbnailUrl,
        category: category,
        temperature: temperature,
        occasions: occasions,
        styles: styles,
        color: color,
        brand: brand,
        price: price,
        status: status,
        wearCount: wearCount,
        refCount: refCount,
        bgRemoved: bgRemoved,
        cutoutUrl: cutoutUrl,
        itemLayout: itemLayout ?? this.itemLayout,
        createdAt: createdAt,
      );

  static int _asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  static List<String> _strList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : <String>[];
}

/// 白板位置记忆（W1）：归一化 0-1，nx/ny=图层中心点，scale=图层宽/画布宽。
/// mysql2 的 JSON 列返回**对象**而非字符串（同 DECIMAL 家族的坑），Map-first 解析。
class WardrobeItemLayout {
  final double nx;
  final double ny;
  final double scale;

  const WardrobeItemLayout({
    required this.nx,
    required this.ny,
    required this.scale,
  });

  static WardrobeItemLayout? _fromEntry(dynamic v) {
    if (v is! Map) return null;
    final nx = _d(v['nx']), ny = _d(v['ny']), sc = _d(v['scale']);
    if (nx == null || ny == null || sc == null) return null;
    return WardrobeItemLayout(nx: nx, ny: ny, scale: sc);
  }

  static double? _d(dynamic v) {
    if (v is num) return v.toDouble();
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  static Map<String, WardrobeItemLayout>? parse(dynamic v) {
    Map map;
    if (v is Map) {
      map = v;
    } else if (v is String && v.isNotEmpty) {
      try {
        final p = jsonDecode(v);
        if (p is Map) {
          map = p;
        } else {
          return null;
        }
      } catch (_) {
        return null;
      }
    } else {
      return null;
    }
    final out = <String, WardrobeItemLayout>{};
    map.forEach((k, val) {
      final e = _fromEntry(val);
      if (e != null) out[k.toString()] = e;
    });
    return out.isEmpty ? null : out;
  }
}

/// 换装白板槽位归类（互斥矩阵口径见 wardrobe-interaction §P13）
String wardrobeSlotOf(String category) => switch (category) {
      '上装' || '连体装' => '上身',
      '裤装' || '裙装' => '下身',
      '外套' => '外套',
      '鞋子' => '鞋',
      '包袋' => '包',
      '配饰' => '配饰',
      _ => '',
    };

/// 图层 z 序（小者底）：形象固定第 0 层
int wardrobeZOf(String category) => switch (category) {
      '裤装' || '裙装' => 1,
      '上装' || '连体装' => 2,
      '外套' => 3,
      '鞋子' => 4,
      '包袋' => 5,
      '配饰' => 6,
      _ => 0,
    };

/// 放入 category 时应从板上移除的既有类别（互斥=替换并 toast）
List<String> wardrobeConflictsOf(String category) => switch (category) {
      '上装' => const ['连体装'],
      '连体装' => const ['上装', '裤装', '裙装'],
      '裤装' => const ['裙装', '连体装'],
      '裙装' => const ['裤装', '连体装'],
      _ => const [],
    };

/// 类别预设锚点 (nx, ny, scale)——无该形象位置记忆时回落；scale 按类别手调
const Map<String, (double, double, double)> wardrobePresetAnchors = {
  '上装': (0.5, 0.32, 0.55),
  '连体装': (0.5, 0.48, 0.62),
  '裤装': (0.5, 0.62, 0.50),
  '裙装': (0.5, 0.55, 0.55),
  '外套': (0.5, 0.30, 0.58),
  '鞋子': (0.5, 0.88, 0.28),
  '包袋': (0.72, 0.55, 0.30),
  '配饰': (0.5, 0.12, 0.18),
};

/// 穿搭里的单品摘要（服务端解析 item_ids；软删条目保留 category 供占位）
class WardrobeItemSummary {
  final int id;
  final bool deleted;
  final String? category;
  final String? brand;
  final String? thumbnailUrl;

  const WardrobeItemSummary({
    required this.id,
    required this.deleted,
    this.category,
    this.brand,
    this.thumbnailUrl,
  });

  factory WardrobeItemSummary.fromJson(Map<String, dynamic> j) =>
      WardrobeItemSummary(
        id: (j['id'] as num?)?.toInt() ?? 0,
        deleted: j['deleted'] == true,
        category: j['category']?.toString(),
        brand: j['brand']?.toString(),
        thumbnailUrl: j['thumbnailUrl']?.toString(),
      );
}

class WardrobeOutfit {
  final int id;
  final String wornDate; // yyyy-MM-dd
  final String source; // 实拍 / 组合
  final String? photoUrl;
  final List<int> itemIds;
  final List<WardrobeItemSummary> items;
  final String status; // 待确认 / 已通过
  final String? note;
  final DateTime? createdAt;

  const WardrobeOutfit({
    required this.id,
    required this.wornDate,
    required this.source,
    this.photoUrl,
    this.itemIds = const [],
    this.items = const [],
    required this.status,
    this.note,
    this.createdAt,
  });

  bool get isCombo => source == '组合';
  bool get approved => status == '已通过';

  /// 日期在未来 = 计划（叠加态优先显示蓝钟，操作按钮仍按真实状态）
  bool isPlanned(String today) => wornDate.compareTo(today) > 0;

  factory WardrobeOutfit.fromJson(Map<String, dynamic> j) => WardrobeOutfit(
        id: (j['id'] as num?)?.toInt() ?? 0,
        wornDate: (j['worn_date'] ?? '').toString().slice0(10),
        source: (j['source'] ?? '').toString(),
        photoUrl: j['photo_url']?.toString(),
        itemIds: (j['itemIds'] as List? ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        items: (j['items'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => WardrobeItemSummary.fromJson(e.cast<String, dynamic>()))
            .toList(),
        status: (j['status'] ?? '待确认').toString(),
        note: j['note']?.toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

/// 我的数字形象（M2a P12）
class WardrobeAvatar {
  final int id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String? cutoutUrl;
  final bool isDefault;
  final DateTime? createdAt;

  const WardrobeAvatar({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    this.cutoutUrl,
    this.isDefault = false,
    this.createdAt,
  });

  /// 换装白板底图优先抠图图（透明人形）
  String get displayImage => cutoutUrl ?? imageUrl;

  factory WardrobeAvatar.fromJson(Map<String, dynamic> j) => WardrobeAvatar(
        id: (j['id'] as num?)?.toInt() ?? 0,
        imageUrl: (j['image_url'] ?? '').toString(),
        thumbnailUrl: j['thumbnail_url']?.toString(),
        cutoutUrl: j['cutout_url']?.toString(),
        isDefault: (j['is_default'] as num?)?.toInt() == 1,
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

extension _StringX on String {
  String slice0(int n) => length <= n ? this : substring(0, n);
}

/// 穿搭时间线分组（P7）：计划中/今天/昨天/本周更早/更早
class TimelineGroup {
  final String label;
  final List<WardrobeOutfit> outfits;
  const TimelineGroup(this.label, this.outfits);
}

List<TimelineGroup> groupOutfits(
  List<WardrobeOutfit> outfits,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final todayStr = fmt(today);
  final yesterdayStr = fmt(today.subtract(const Duration(days: 1)));
  // 周一为一周起点
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekStartStr = fmt(weekStart);

  final planned = <WardrobeOutfit>[];
  final todayList = <WardrobeOutfit>[];
  final yesterdayList = <WardrobeOutfit>[];
  final weekList = <WardrobeOutfit>[];
  final earlier = <WardrobeOutfit>[];

  for (final o in outfits) {
    if (o.isPlanned(todayStr)) {
      planned.add(o);
    } else if (o.wornDate == todayStr) {
      todayList.add(o);
    } else if (o.wornDate == yesterdayStr) {
      yesterdayList.add(o);
    } else if (o.wornDate.compareTo(weekStartStr) >= 0) {
      weekList.add(o);
    } else {
      earlier.add(o);
    }
  }
  // 计划中"最近优先"=日期升序；其余组保持服务器倒序
  planned.sort((a, b) => a.wornDate.compareTo(b.wornDate));
  final groups = <TimelineGroup>[
    if (planned.isNotEmpty) TimelineGroup('计划中', planned),
    if (todayList.isNotEmpty) TimelineGroup('今天', todayList),
    if (yesterdayList.isNotEmpty) TimelineGroup('昨天', yesterdayList),
    if (weekList.isNotEmpty) TimelineGroup('本周更早', weekList),
    if (earlier.isNotEmpty) TimelineGroup('更早', earlier),
  ];
  return groups;
}
