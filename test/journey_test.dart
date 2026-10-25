import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/features/travel/journey.dart';

void main() {
  const first = JourneyStop(
      key: 'one', spotId: 37, day: 0, mode: 'walking', note: '先看日落');
  const second = JourneyStop(key: 'two', spotId: 38, day: 0, mode: 'transit');
  const third = JourneyStop(key: 'three', spotId: 37, day: 1);
  const pending = JourneyStop(key: 'pending', spotId: 40);
  const journey = Journey(
      id: 7,
      title: '两日游',
      days: 2,
      revision: 4,
      stops: [first, second, third, pending]);

  test('reordering one day retains stop keys, mode, note and the other days',
      () {
    final changed = journey.reorder(0, 0, 2);
    expect(changed.dayStops(0).map((stop) => stop.key), ['two', 'one']);
    expect(changed.dayStops(0).last.mode, 'walking');
    expect(changed.dayStops(0).last.note, '先看日落');
    expect(changed.dayStops(1).single.key, 'three');
    expect(journey.dayStops(0).first.key, 'one');
  });
  test(
      'cross-day moves append at the destination and retain unplanned status explicitly',
      () {
    final moved = journey.move({'one'}, 1);
    expect(moved.dayStops(0).map((stop) => stop.key), ['two']);
    expect(moved.dayStops(1).map((stop) => stop.key), ['three', 'one']);
    final unplanned = moved.move({'one'}, null);
    expect(
        unplanned.dayStops(null).map((stop) => stop.key), ['pending', 'one']);
  });
  test('removing an occurrence leaves other visits to the same place intact',
      () {
    final changed = journey.remove({'one'});
    expect(changed.stops.any((stop) => stop.key == 'one'), isFalse);
    expect(changed.stops.any((stop) => stop.key == 'three'), isTrue);
  });
  test(
      'API numeric strings and nullable place snapshots parse without losing plan data',
      () {
    final parsed = Journey.fromJson({
      ...journey.toJson(),
      'id': '7',
      'ownerId': '33',
      'revision': '4',
      'days': '2',
      'stops': [
        {
          ...first.toJson(),
          'spotId': '37',
          'place': {'id': '37', 'name': '地点', 'lat': '31.2', 'lng': '121.4'}
        },
        {...pending.toJson(), 'place': null},
      ],
    });
    expect(parsed.revision, 4);
    expect(parsed.stops.first.place!.lat, 31.2);
    expect(parsed.stops.last.day, isNull);
    expect(parsed.stops.last.place, isNull);
  });
}
