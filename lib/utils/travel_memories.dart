import '../models/travel.dart';

String memoryCityKey(String city) =>
    city.trim().replaceAll(RegExp(r'\s+'), '').replaceFirst(RegExp(r'市$'), '');

int visitedMemoryCityCount(Iterable<TravelSpot> spots) => spots
    .where((spot) => spot.status == 'visited')
    .map((spot) => memoryCityKey(spot.city))
    .where((city) => city.isNotEmpty)
    .toSet()
    .length;

/// 按城市分组、日期倒序；同日多地点保留，未知日期排最后。
Map<String, List<TravelSpot>> groupTravelMemories(Iterable<TravelSpot> spots) {
  final sorted = spots.where((spot) => spot.status == 'visited').toList()
    ..sort((a, b) {
      final aDate = DateTime.tryParse(a.visitedDate ?? '');
      final bDate = DateTime.tryParse(b.visitedDate ?? '');
      if (aDate == null && bDate != null) return 1;
      if (aDate != null && bDate == null) return -1;
      final order = aDate == null ? 0 : bDate!.compareTo(aDate);
      return order == 0 ? b.id.compareTo(a.id) : order;
    });
  final groups = <String, List<TravelSpot>>{};
  for (final spot in sorted) {
    final key = memoryCityKey(spot.city);
    (groups[key.isEmpty ? '未填写城市' : key] ??= []).add(spot);
  }
  return groups;
}
