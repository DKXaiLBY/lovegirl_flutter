import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/screens/life/widgets/todo_list.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _TodoApi implements ApiService {
  final today = DateUtils.dateOnly(DateTime.now());
  late final tasks = <Map<String, Object>>[
    {
      'id': 1,
      'title': '今天买菜',
      'due_date': today.toIso8601String(),
      'category': 'daily'
    },
    {
      'id': 2,
      'title': '未来学习',
      'due_date': today.add(const Duration(days: 12)).toIso8601String(),
      'category': 'study'
    },
    {'id': 3, 'title': '未设日期', 'category': 'daily', 'completed': true},
  ];
  bool failDelete = true;
  int deletes = 0;

  @override
  Future<Response<dynamic>> getTodos() async =>
      Response(requestOptions: RequestOptions(), data: {
        'data': [...tasks]
      });

  @override
  Future<Response<dynamic>> deleteTodo(int id) async {
    deletes++;
    if (failDelete) throw StateError('offline');
    tasks.removeWhere((todo) => todo['id'] == id);
    return Response(requestOptions: RequestOptions(), data: {'code': 200});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> show(WidgetTester tester, _TodoApi api) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: LoveGirlTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: Scaffold(body: TodoListWidget(api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('date and category filters count the same visible real tasks',
      (tester) async {
    final api = _TodoApi();
    await show(tester, api);
    expect(find.text('待完成 2 件'), findsOneWidget);
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('今天买菜'), findsOneWidget);
    expect(find.text('未来学习'), findsNothing);
    expect(find.text('待完成 1 件'), findsOneWidget);
    await tester.tap(find.text('学习').first);
    await tester.pumpAndSettle();
    expect(find.text('这个范围没有待办'), findsOneWidget);
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('未来学习'), findsOneWidget);
    expect(find.text('今天买菜'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed swipe delete leaves the row available for retry',
      (tester) async {
    final api = _TodoApi();
    await show(tester, api);
    final row = find.byKey(const Key('todo_1'));
    await tester.drag(row, const Offset(-325, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    expect(api.deletes, 1);

    api.failDelete = false;
    await tester.tap(find.byTooltip('删除 今天买菜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(row, findsNothing);
    expect(api.deletes, 2);
    expect(tester.takeException(), isNull);
  });
}
