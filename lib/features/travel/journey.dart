import '../../models/travel.dart';

int _int(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

class JourneyStop {
  final String key;
  final int spotId;
  final int? day;
  final String mode;
  final String note;
  final TravelSpot? place;
  const JourneyStop(
      {required this.key,
      required this.spotId,
      this.day,
      this.mode = 'driving',
      this.note = '',
      this.place});
  JourneyStop copyWith(
          {int? day,
          bool unplanned = false,
          String? mode,
          String? note,
          TravelSpot? place}) =>
      JourneyStop(
        key: key,
        spotId: spotId,
        day: unplanned ? null : day ?? this.day,
        mode: mode ?? this.mode,
        note: note ?? this.note,
        place: place ?? this.place,
      );
  Map<String, dynamic> toJson() => {
        'key': key,
        'spotId': spotId,
        'day': day,
        'mode': mode,
        'note': note,
      };
  factory JourneyStop.fromJson(Map<String, dynamic> data) => JourneyStop(
        key: data['key'].toString(),
        spotId: _int(data['spotId']),
        day: data['day'] == null ? null : _int(data['day']),
        mode: data['mode']?.toString() ?? 'driving',
        note: data['note']?.toString() ?? '',
        place: data['place'] is Map
            ? TravelSpot.fromJson(Map<String, dynamic>.from(data['place']))
            : null,
      );
}

class Journey {
  final int? id;
  final String clientId;
  final int revision;
  final int? ownerId;
  final String title;
  final String city;
  final String description;
  final String? startDate;
  final String? endDate;
  final int days;
  final List<JourneyStop> stops;
  const Journey(
      {this.id,
      this.clientId = '',
      this.revision = 0,
      this.ownerId,
      required this.title,
      this.city = '',
      this.description = '',
      this.startDate,
      this.endDate,
      this.days = 1,
      this.stops = const []});

  List<JourneyStop> dayStops(int? day) =>
      stops.where((stop) => stop.day == day).toList(growable: false);
  Journey copyWith(
          {String? title,
          String? city,
          String? description,
          String? startDate,
          String? endDate,
          bool clearDates = false,
          int? days,
          int? revision,
          List<JourneyStop>? stops}) =>
      Journey(
        id: id,
        clientId: clientId,
        ownerId: ownerId,
        revision: revision ?? this.revision,
        title: title ?? this.title,
        city: city ?? this.city,
        description: description ?? this.description,
        startDate: clearDates ? null : startDate ?? this.startDate,
        endDate: clearDates ? null : endDate ?? this.endDate,
        days: days ?? this.days,
        stops: stops ?? this.stops,
      );
  Journey move(Set<String> keys, int? day) => copyWith(stops: [
        ...stops.where((stop) => !keys.contains(stop.key)),
        ...stops
            .where((stop) => keys.contains(stop.key))
            .map((stop) => stop.copyWith(day: day, unplanned: day == null)),
      ]);
  Journey remove(Set<String> keys) =>
      copyWith(stops: stops.where((stop) => !keys.contains(stop.key)).toList());
  Journey reorder(int? day, int oldIndex, int newIndex) {
    final selected = dayStops(day).toList();
    if (newIndex > oldIndex) newIndex--;
    selected.insert(newIndex, selected.removeAt(oldIndex));
    var index = 0;
    return copyWith(
        stops: stops
            .map((stop) => stop.day == day ? selected[index++] : stop)
            .toList());
  }

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'revision': revision,
        'title': title,
        'city': city,
        'description': description,
        'startDate': startDate,
        'endDate': endDate,
        'days': days,
        'stops': stops.map((stop) => stop.toJson()).toList(),
      };
  factory Journey.fromJson(Map<String, dynamic> data) => Journey(
        id: data['id'] == null ? null : _int(data['id']),
        clientId: data['clientId']?.toString() ?? '',
        revision: _int(data['revision']),
        ownerId: _int(data['ownerId']),
        title: data['title']?.toString() ?? '',
        city: data['city']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        startDate: data['startDate']?.toString(),
        endDate: data['endDate']?.toString(),
        days: _int(data['days'], 1),
        stops: (data['stops'] as List)
            .map((value) =>
                JourneyStop.fromJson(Map<String, dynamic>.from(value)))
            .toList(growable: false),
      );
}
