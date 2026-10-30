import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:lovegirl_flutter/providers/home_provider.dart';
import 'package:lovegirl_flutter/providers/notification_provider.dart';
import 'package:lovegirl_flutter/screens/memories/memories_screen.dart';
import 'package:lovegirl_flutter/screens/notifications/notification_center_screen.dart';
import 'package:lovegirl_flutter/screens/profile/profile_screen.dart';
import 'package:lovegirl_flutter/screens/report/annual_report_screen.dart';
import 'package:lovegirl_flutter/screens/report/monthly_report_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _Api implements ApiService {
  final calls = <Symbol>[];
  Future<Response> response(dynamic data) async => Response(
      requestOptions: RequestOptions(), data: {'code': 200, 'data': data});
  @override
  Future<Response> getTodos() => response([{'id': 17, 'title': '真实待办', 'completed': 0}]);
  @override
  Future<Response> getHomeToday() => response({'loveDays': 333});
  @override
  Future<Response> getFinanceStats(String month, {String? source}) => response({'expense': 29});
  @override
  Future<Response> getLoveReport({int? year}) => response({
    'travel': {'spots': 2, 'cities': 1}, 'kitchen': {'orders': 1},
    'dailyDays': 199, 'beansEarned': 9999, 'letters': 44,
    'photos': 3, 'timelineEvents': 5});
  @override
  Future<Response> getMonthlyReport(int year, int month) => response({
    'dailyDays': 199, 'beansEarned': 9999, 'beansSpent': 111,
    'letters': 44, 'photos': 3, 'timelineEvents': 5});
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation.memberName);
    return response([#getAchievements, #getAnniversaries, #getTravelTrips,
      #getTravelRoutes, #getTravelSpots].contains(invocation.memberName) ? [] : {});
  }
}

class _Auth extends AuthProvider {
  @override
  Map<String, dynamic> get user => {'id': 71, 'nickname': 'QA', 'role': 'boy'};
  @override
  int get loveDays => 333;
}

class _Notifications extends NotificationProvider {
  _Notifications(String type) {
    items = [NotificationItem(id: 7, type: type, title: '旧通知', content: '历史内容',
        payload: const {'order_id': 99, 'letter_id': 88}, createdAt: DateTime(2026, 10, 1))];
  }
  @override
  Future<void> refresh() async {}
  @override
  Future<void> markRead(NotificationItem item) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (_) async => null);
  });

  Widget app(Widget page) => ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Auth(), child: MaterialApp(theme: LoveGirlTheme.lightTheme, home: page));

  test('home no longer requests retired check-in while keeping todo parsing', () async {
    final api = _Api();
    final home = HomeProvider(api: api);
    await home.refresh();
    expect(api.calls, isNot(contains(#getBeanCheckInStatus)));
    expect(home.today!['todo']['active'], 1);
    home.dispose();
  });

  testWidgets('memory hub retains useful entries without questions or letters', (tester) async {
    await tester.pumpWidget(app(const MemoriesScreen()));
    expect(find.text('每日一问'), findsNothing);
    expect(find.text('慢信'), findsNothing);
    expect(find.text('相册'), findsOneWidget);
    expect(find.text('美食手账'), findsOneWidget);
  });

  testWidgets('profile stops loading and exposing reward features', (tester) async {
    final api = _Api();
    await tester.pumpWidget(app(ProfileScreen(api: api)));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains(#getBeanBalance)));
    expect(api.calls, isNot(contains(#getAchievements)));
    for (final text in ['爱心豆', '签到', '成就', '愿望兑换券']) {
      expect(find.textContaining(text), findsNothing);
    }
    expect(find.text('纪念日'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  for (final type in ['daily_question', 'slow_letter', 'achievement']) {
    testWidgets('old $type notification cannot reopen a retired feature', (tester) async {
      await tester.pumpWidget(ChangeNotifierProvider<NotificationProvider>(
          create: (_) => _Notifications(type),
          child: app(const NotificationCenterScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旧通知'));
      await tester.pumpAndSettle();
      expect(find.text('该功能已停用，历史记录已保留'), findsOneWidget);
      expect(find.byType(NotificationCenterScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final yearly in [true, false]) {
    testWidgets('${yearly ? 'annual' : 'monthly'} report excludes retired counters in legacy payloads', (tester) async {
      await tester.pumpWidget(app(yearly ? AnnualReportScreen(api: _Api()) : MonthlyReportScreen(api: _Api())));
      await tester.pumpAndSettle();
      for (final text in ['每日一问', '慢信', '爱心豆']) {
        expect(find.textContaining(text), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
