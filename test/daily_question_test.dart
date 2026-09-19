import 'package:flutter_test/flutter_test.dart';

import 'package:lovegirl_flutter/providers/daily_provider.dart';

void main() {
  test('DailyToday.fromJson 三态字段解析', () {
    final unanswered = DailyToday.fromJson({
      'date': '2026-09-20',
      'question': '如果明天可以一起去一个地方，你想去哪？',
      'hasPartner': true,
      'partnerName': '小美',
      'myAnswer': null,
      'partnerAnswer': null,
      'bothAnswered': false,
      'streak': {'current': 3, 'longest': 10, 'total': 15},
    });
    expect(unanswered.myAnswer, isNull);
    expect(unanswered.waitingPartner, isFalse); // 还没答，不算等待
    expect(unanswered.streakCurrent, 3);

    final waiting = DailyToday.fromJson({
      'date': '2026-09-20',
      'question': 'q',
      'myAnswer': '海边',
      'partnerAnswer': null,
      'bothAnswered': false,
      'streak': {'current': 0, 'longest': 0, 'total': 0},
    });
    expect(waiting.waitingPartner, isTrue);

    final revealed = DailyToday.fromJson({
      'date': '2026-09-20',
      'question': 'q',
      'myAnswer': '海边',
      'partnerAnswer': '山里',
      'bothAnswered': true,
      'streak': {'current': 1, 'longest': 1, 'total': 1},
    });
    expect(revealed.bothAnswered, isTrue);
    expect(revealed.streakLongest, 1);
  });

  test('DailyToday.fromJson 缺 streak 字段不崩溃', () {
    final t = DailyToday.fromJson({'date': 'd', 'question': 'q'});
    expect(t.streakCurrent, 0);
    expect(t.hasPartner, isFalse);
  });

  test('DailyHistoryEntry.fromJson', () {
    final e = DailyHistoryEntry.fromJson({
      'date': '2026-09-19',
      'question': 'q',
      'myAnswer': 'a',
      'partnerAnswer': 'b',
    });
    expect(e.date, '2026-09-19');
    expect(e.partnerAnswer, 'b');
  });
}
