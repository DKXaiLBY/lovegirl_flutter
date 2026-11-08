import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/screens/health/widgets/period_tracker.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _Periods implements ApiService {
  final DateTime month;
  _Periods(this.month);

  Response<dynamic> _response(Object? data) =>
      Response(requestOptions: RequestOptions(), data: {'data': data});

  @override
  Future<Response> getPeriodStatus() async => _response({
        'phase': {'phaseKey': 'safe'},
        'daysUntilNext': 9,
      });

  @override
  Future<Response> getPeriodAnalysis() async =>
      _response({'avgCycle': 30, 'avgDuration': 4, 'cycleCount': 1});

  @override
  Future<Response> getPeriods() async => _response([
        {
          'startDate': DateTime(month.year, month.month, 8).toIso8601String(),
          'endDate': DateTime(month.year, month.month, 10).toIso8601String(),
        }
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('calendar distinguishes recorded days and neutral cycle copy',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    await tester.pumpWidget(MaterialApp(
      theme: LoveGirlTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: Scaffold(body: PeriodTracker(api: _Periods(previous))),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    expect(find.text('${previous.month}月8日 · 已记录经期'), findsOneWidget);
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    expect(find.text('${previous.month}月7日 · 当天暂无记录'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('周期记录'), findsOneWidget);
    expect(find.text('安全期'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
