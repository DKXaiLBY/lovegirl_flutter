DateTime? resolveLoveStartDate({
  String? explicitDate,
  Iterable<Map<String, dynamic>> anniversaries = const [],
}) {
  final direct = _parseDate(explicitDate);
  if (direct != null) return direct;

  DateTime? match;
  for (final item in anniversaries) {
    final type = (item['type'] ?? '').toString().toLowerCase();
    final title = (item['title'] ?? '').toString();
    final isLoveAnniversary =
        type == 'love' || title.contains('恋爱') || title.contains('在一起');
    if (!isLoveAnniversary) continue;
    final parsed = _parseDate(
      item['eventDate'] ?? item['event_date'] ?? item['date'],
    );
    if (parsed == null) continue;
    if (match == null || parsed.isBefore(match)) {
      match = parsed;
    }
  }
  return match;
}

int resolveLoveDays({
  String? explicitDate,
  Iterable<Map<String, dynamic>> anniversaries = const [],
  int fallbackDays = 1,
  DateTime? now,
}) {
  final start = resolveLoveStartDate(
    explicitDate: explicitDate,
    anniversaries: anniversaries,
  );
  if (start == null) return fallbackDays < 1 ? 1 : fallbackDays;

  final today = now ?? DateTime.now();
  final startDay = DateTime(start.year, start.month, start.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  final diff = todayDay.difference(startDay).inDays + 1;
  return diff < 1 ? 1 : diff;
}

DateTime? _parseDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

Map<String, dynamic>? upcomingAnniversary(
  Iterable<Map<String, dynamic>> items, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime.utc(current.year, current.month, current.day);
  Map<String, dynamic>? result;
  for (final item in items) {
    if (item['is_lunar'] == true || item['is_lunar'] == 1) continue;
    final base = _parseDate(item['eventDate'] ?? item['event_date']);
    if (base == null) continue;
    final first = DateTime.utc(base.year, base.month, base.day);
    final repeat = item['repeat_type'] ?? item['repeatType'] ?? 'yearly';
    DateTime next = first;
    if (!first.isAfter(today) && repeat != 'once') {
      final month = repeat == 'monthly' ? today.month : base.month;
      next = _anniversaryDate(today.year, month, base.day);
      if (next.isBefore(today)) {
        next = repeat == 'monthly'
            ? _anniversaryDate(today.year, today.month + 1, base.day)
            : _anniversaryDate(today.year + 1, base.month, base.day);
      }
    }
    final days = next.difference(today).inDays;
    if (days < 0 || days > 7) continue;
    if (result == null || days < (result['days'] as int)) {
      result = {'title': item['title'] ?? '纪念日', 'days': days};
    }
  }
  return result;
}

DateTime _anniversaryDate(int year, int month, int day) {
  final first = DateTime.utc(year, month);
  final maxDay = DateTime.utc(first.year, first.month + 1, 0).day;
  return DateTime.utc(first.year, first.month, day.clamp(1, maxDay));
}
