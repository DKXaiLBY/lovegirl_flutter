import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/screens/life/widgets/schedule_list.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _CourseApi implements ApiService {
  final day = DateTime.now().weekday;
  bool offline = false;

  @override
  Future<Response<dynamic>> getCourses(String term) async {
    if (offline) throw StateError('offline');
    return Response(requestOptions: RequestOptions(), data: {
      'data': [
        {
          'id': 1,
          'courseName': '建筑设计导论',
          'dayOfWeek': day,
          'startTime': '09:20:00',
          'endTime': '10:50:00',
          'classroom': '教学楼很长的教室名称 301',
          'teacher': '任课老师',
          'weekType': 'odd',
          'startWeek': 2,
          'endWeek': 16,
        },
        {'id': 2, 'courseName': '摄影', 'dayOfWeek': day % 7 + 1},
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('today and whole week use real courses at large text size',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _CourseApi();
    await tester.pumpWidget(MaterialApp(
      theme: LoveGirlTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: Scaffold(body: ScheduleListWidget(api: api)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('今天课表有 1 门课'), findsOneWidget);
    expect(find.text('建筑设计导论'), findsOneWidget);
    expect(find.textContaining('单周 · 第 2–16 周'), findsOneWidget);
    expect(find.text('摄影'), findsNothing);
    expect(find.text('1–2 节'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('查看整周'));
    await tester.pumpAndSettle();
    expect(find.text('本周课表'), findsOneWidget);
    expect(find.text('查看单日'), findsOneWidget);
    final refresh =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    api.offline = true;
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('暂未更新，仍显示上次读取的课程'), findsOneWidget);
    api.offline = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('暂未更新，仍显示上次读取的课程'), findsNothing);
  });
}
