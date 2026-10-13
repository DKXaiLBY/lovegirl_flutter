import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// 中国省份地图数据层（W6 弹药库：map-for-love 交互规格，Dart 自研实现）。
/// 数据源：assets/data/china_geo.json（省份轮廓 GeoJSON，35 feature 含九段线）
/// + assets/data/china_provinces.json（34 省 adcode/name 映射）。
/// 坐标系：WGS84 经纬度 → Web 墨卡托归一 → fitExtent 线性映射到画布。

class GeoRing {
  final List<Offset> points; // 经纬度
  const GeoRing(this.points);
}

class GeoShape {
  final int adcode;
  final String name;
  // 每多边形 = [外环, 内洞...]（河北环抱京津等洞形边界需要分组才能正确判定/填充）
  final List<List<GeoRing>> polygons;
  const GeoShape(this.adcode, this.name, this.polygons);

  /// 偶奇射线跨越判定（x=经度, y=纬度），跨所有环计数，洞自动扣除
  bool containsPoint(double x, double y) {
    for (final poly in polygons) {
      var inside = false;
      for (final ring in poly) {
        final pts = ring.points;
        for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
          final yi = pts[i].dy;
          final yj = pts[j].dy;
          if ((yi > y) != (yj > y)) {
            final xi = pts[i].dx;
            final xj = pts[j].dx;
            if (x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
          }
        }
      }
      if (inside) return true;
    }
    return false;
  }
}

class ChinaGeoData {
  final List<GeoShape> provinces; // 34 省
  final GeoShape? dashLine; // 南海诸岛九段线（adcode "100000_JD"）
  final Map<int, String> adcodeName; // adcode → 省名

  const ChinaGeoData(this.provinces, this.dashLine, this.adcodeName);
}

const String jdAdcode = '100000_JD';

ChinaGeoData? _cached;

Future<ChinaGeoData> loadChinaGeo() async {
  final cached = _cached;
  if (cached != null) return cached;

  final geoStr = await rootBundle.loadString('assets/data/china_geo.json');
  final provStr =
      await rootBundle.loadString('assets/data/china_provinces.json');
  final geoRoot = jsonDecode(geoStr) as Map<String, dynamic>;
  final provList = (jsonDecode(provStr) as List).cast<Map<String, dynamic>>();

  final adcodeName = <int, String>{};
  for (final p in provList) {
    adcodeName[(p['adcode'] as num).toInt()] = p['name'] as String;
  }

  final shapes = <GeoShape>[];
  GeoShape? dashLine;
  for (final f in (geoRoot['features'] as List).cast<Map>()) {
    final props = (f['properties'] ?? const {}) as Map;
    final adcodeRaw = props['adcode']?.toString();
    if (adcodeRaw == null) continue;
    final name = (props['name'] ?? '').toString();
    final geom = (f['geometry'] ?? const {}) as Map;
    final type = geom['type'] as String? ?? '';

    // coordinates: Polygon=[[ring]] / MultiPolygon=[[ring]]（ring=点列）
    List ringsRaw;
    if (type == 'MultiPolygon') {
      ringsRaw = geom['coordinates'] as List;
    } else if (type == 'Polygon') {
      ringsRaw = [geom['coordinates'] as List];
    } else {
      continue;
    }

    final polygons = <List<GeoRing>>[];
    for (final poly in ringsRaw) {
      final rings = <GeoRing>[];
      for (final ring in poly as List) {
        final pts = <Offset>[];
        for (final pt in ring as List) {
          final pair = (pt as List).cast<num>();
          pts.add(Offset(pair[0].toDouble(), pair[1].toDouble()));
        }
        if (pts.length >= 3) rings.add(GeoRing(pts));
      }
      if (rings.isNotEmpty) polygons.add(rings);
    }
    if (polygons.isEmpty) continue;

    final shape = GeoShape(int.tryParse(adcodeRaw) ?? 0, name, polygons);
    if (adcodeRaw == jdAdcode) {
      dashLine = shape;
      continue;
    }
    if (!adcodeName.containsKey(shape.adcode)) continue;
    shapes.add(shape);
  }

  _cached = ChinaGeoData(shapes, dashLine, adcodeName);
  return _cached!;
}

/// Web 墨卡托 y 归一（经纬度 → 可线性映射的 y）
double mercatorY(double latDeg) {
  final rad = latDeg * math.pi / 180;
  final clamped = rad.clamp(-1.4844, 1.4844); // ±85.05°
  return math.log(math.tan(math.pi / 4 + clamped / 2)) * 180 / math.pi;
}

/// 反投影：mercatorY 的 y 值 → 纬度（画布点击还原地理坐标用）
double inverseMercatorY(double y) {
  final rad = 2 * math.atan(math.exp(y * math.pi / 180)) - math.pi / 2;
  return rad * 180 / math.pi;
}

/// fitExtent：把经纬度包围盒线性映射进画布可用区域（保持纵横比、居中）。
/// 返回 [scale, offsetX, offsetY]——投影坐标 × scale + offset。
List<double> geoFitExtent({
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
  required double width,
  required double height,
  double padding = 8,
}) {
  final availW = math.max(1.0, width - padding * 2);
  final availH = math.max(1.0, height - padding * 2);
  final spanX = math.max(1e-9, maxX - minX);
  final spanY = math.max(1e-9, maxY - minY);
  final scale = math.min(availW / spanX, availH / spanY);
  final offsetX = padding + (availW - spanX * scale) / 2;
  final offsetY = padding + (availH - spanY * scale) / 2;
  return [scale, offsetX, offsetY];
}
