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
