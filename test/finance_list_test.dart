import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lovegirl_flutter/screens/life/widgets/finance_list.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class _FinanceApi implements ApiService {
  final month = DateFormat('yyyy-MM').format(DateTime.now());
  Completer<Response>? older;
  bool failEdit = true;
  bool includeTravel = false;
  Map? edited;

  Response response(Object data) =>
      Response(requestOptions: RequestOptions(), data: {'data': data});

  @override
  Future<Response> getFinanceRecords(String month, {String? source}) async {
    if (month != this.month && older != null) return older!.future;
    return response(month != this.month
        ? []
        : [
            {
              'id': 7,
              'type': 'expense',
              'amount': '2360.50',
              'category': '餐饮',
              'description': '原备注',
              'recordDate': '${this.month}-04T00:00:00.000Z',
            },
            if (includeTravel)
              {
                'id': 8,
                'type': 'expense',
                'amount': '20',
                'category': 'travel',
                'description': '海边车费',
                'recordDate': '${this.month}-03',
              },
          ]);
  }

  @override
  Future<Response> getFinanceStats(String month, {String? source}) async =>
      response({
        'totalIncome': '0',
        'totalExpense': month == this.month ? '2360.50' : '0'
      });

  @override
  Future<Response> put(String path, {dynamic data}) async {
    expect(path, '/api/finance/7');
    edited = data as Map;
    if (failEdit) throw StateError('offline');
    return response({});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> show(WidgetTester tester, _FinanceApi api) async {
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
      home: Scaffold(body: FinanceListWidget(api: api)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'legacy records and totals stay readable and stale months are ignored',
      (tester) async {
    final api = _FinanceApi()..older = Completer<Response>();
    await show(tester, api);
    expect(find.text('¥2360.50'), findsOneWidget);
    expect(find.textContaining('4日 周'), findsOneWidget);
    expect(find.text('旅行花费'), findsNothing);
    await tester.tap(find.bySemanticsLabel('上个月'));
    await tester.pump();
    expect(find.text('¥2360.50'), findsNothing);
    await tester.tap(find.bySemanticsLabel('下个月'));
    await tester.pumpAndSettle();
    api.older!.complete(api.response([]));
    await tester.pumpAndSettle();
    expect(find.text('¥2360.50'), findsOneWidget);
    expect(find.textContaining('原备注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit keeps the amount and typed note after a failed save',
      (tester) async {
    final api = _FinanceApi();
    await show(tester, api);
    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();
    final note = find.widgetWithText(TextField, '原备注');
    await tester.ensureVisible(note);
    await tester.enterText(note, '修改后重试');
    final save = find.text('保存账单');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('保存失败，输入已保留'), findsOneWidget);
    expect(find.text('修改后重试'), findsOneWidget);
    expect(api.edited!['amount'], 2360.50);
    expect(api.edited!['recordDate'], '${api.month}-04');
    api.failEdit = false;
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('编辑账单'), findsNothing);
    expect(api.edited!['description'], '修改后重试');
  });

  testWidgets('old travel category filters without relying on server source',
      (tester) async {
    await show(tester, _FinanceApi()..includeTravel = true);
    await tester.tap(find.widgetWithText(ChoiceChip, '旅行花费'));
    await tester.pumpAndSettle();
    expect(find.textContaining('原备注'), findsNothing);
    expect(find.textContaining('海边车费'), findsOneWidget);
    expect(find.text('¥20.00'), findsOneWidget);
  });
}
