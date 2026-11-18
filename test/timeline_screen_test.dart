import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/screens/timeline/timeline_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _TimelineApi implements ApiService {
  bool offline = false;
  String title = '海边散步';

  @override
  Future<Response<dynamic>> getTimeline() async {
    if (offline) throw StateError('offline');
    return Response(requestOptions: RequestOptions(), data: {
      'data': [
        {
          'id': 1,
          'title': title,
          'description': '一起看海',
          'eventDate': '2025-11-17'
        }
      ],
    });
  }

  @override
  Future<Response<dynamic>> createTimeline(Map data) async {
    throw StateError('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('timeline keeps real moments visible when refresh fails',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final api = _TimelineApi();
    await tester.pumpWidget(MaterialApp(
      theme: LoveGirlTheme.darkTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!),
      home: TimelineScreen(api: api),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2025年11月17日'), findsOneWidget);
    api.offline = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('海边散步'), findsOneWidget);
    expect(find.text('时光轴暂未读取，可以重试'), findsOneWidget);
    api.offline = false;
    api.title = '雨后的海边';
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('雨后的海边'), findsOneWidget);
    expect(find.text('海边散步'), findsNothing);
    await tester.tap(find.text('添加时刻'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '新的时刻');
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('新的时刻'), findsOneWidget);
    expect(find.text('保存失败，输入已保留'), findsOneWidget);
  });
}
