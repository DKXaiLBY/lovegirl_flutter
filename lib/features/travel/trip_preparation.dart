const packingCategories = {
  'clothes': '衣物',
  'toiletries': '洗护',
  'documents': '证件',
  'electronics': '电子设备',
  'other': '其他',
};

class PackingItem {
  final String key;
  final String label;
  final String category;
  final bool packed;
  final int? assigneeId;

  const PackingItem({
    required this.key,
    required this.label,
    required this.category,
    this.packed = false,
    this.assigneeId,
  });

  factory PackingItem.fromJson(Map data) => PackingItem(
        key: data['key'] as String,
        label: data['label'] as String,
        category: data['category'] as String,
        packed: data['packed'] == true,
        assigneeId: data['assigneeId'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'category': category,
        'packed': packed,
        'assigneeId': assigneeId,
      };
}

class PreparationOutfit {
  final int day;
  final int? outfitId;
  final List<int> itemIds;
  final String label;
  final String? imageUrl;
  final bool available;
  final List<({String label, String? imageUrl, bool available})> pieces;

  const PreparationOutfit({
    required this.day,
    this.outfitId,
    this.itemIds = const [],
    this.label = '',
    this.imageUrl,
    this.available = true,
    this.pieces = const [],
  });

  factory PreparationOutfit.fromJson(Map data) => PreparationOutfit(
        day: data['day'] as int,
        outfitId: data['outfitId'] as int?,
        itemIds: (data['itemIds'] as List).cast<int>(),
        label: data['label'] as String,
        imageUrl: data['imageUrl'] as String?,
        available: data['available'] == true,
        pieces: [
          for (final piece in data['items'] as List)
            (
              label: piece['label'] as String,
              imageUrl: piece['imageUrl'] as String?,
              available: piece['available'] == true,
            ),
        ],
      );

  Map<String, dynamic> toJson() =>
      {'day': day, 'outfitId': outfitId, 'itemIds': itemIds};
}

class PreparationList {
  final int revision;
  final List<PackingItem> items;
  final List<PreparationOutfit> outfits;

  const PreparationList(this.revision, this.items, this.outfits);

  factory PreparationList.fromJson(Map data) => PreparationList(
        data['revision'] as int,
        (data['items'] as List).cast<Map>().map(PackingItem.fromJson).toList(),
        (data['outfits'] as List)
            .cast<Map>()
            .map(PreparationOutfit.fromJson)
            .toList(),
      );

  int get packed => items.where((item) => item.packed).length;
}

class TripPreparation {
  final String title;
  final DateTime? start;
  final int days;
  final bool archived;
  final String? relationshipKey;
  final Map<int, String> people;
  final PreparationList mine;
  final PreparationList? shared;

  const TripPreparation({
    required this.title,
    required this.start,
    required this.days,
    required this.archived,
    required this.relationshipKey,
    required this.people,
    required this.mine,
    required this.shared,
  });

  factory TripPreparation.fromJson(Map data) {
    final trip = data['trip'] as Map;
    return TripPreparation(
      title: trip['title'] as String,
      start: DateTime.tryParse(trip['startDate']?.toString() ?? ''),
      days: trip['days'] as int,
      archived: data['archived'] == true,
      relationshipKey: data['relationshipKey'] as String?,
      people: {
        for (final person in data['people'] as List)
          person['id'] as int: person['nickname']?.toString() ?? '',
      },
      mine: PreparationList.fromJson(data['mine'] as Map),
      shared: data['shared'] == null
          ? null
          : PreparationList.fromJson(data['shared'] as Map),
    );
  }

  TripPreparation update(PreparationList list, {required bool isShared}) =>
      TripPreparation(
        title: title,
        start: start,
        days: days,
        archived: archived,
        relationshipKey: relationshipKey,
        people: people,
        mine: isShared ? mine : list,
        shared: isShared ? list : shared,
      );
}
