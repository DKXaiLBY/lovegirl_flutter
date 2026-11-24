import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/features/study/study_book_theme.dart';
import 'package:lovegirl_flutter/features/study/study_ocr_compare.dart';
import 'package:lovegirl_flutter/features/study/study_pdf.dart';
import 'package:lovegirl_flutter/features/study/study_workspace.dart';
import 'package:lovegirl_flutter/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class _Account extends AuthProvider {
  @override
  int? get userId => 12;
}

class _Pdf extends StudyPdf {
  const _Pdf() : super(12);

  @override
  Future<Uint8List?> preview(StudyPageReference page,
      {bool forOcr = false}) async {
    return forOcr ? Uint8List.fromList([255, 216, 255, 217]) : null;
  }
}

class _Workspace extends StudyWorkspace {
  _Workspace() : super(12) {
    ocrAvailable = true;
    ocrProvider = '识别测试服务';
  }

  int requests = 0;

  @override
  Future<String> recognizePage(StudyOcrRole role, Uint8List jpeg) async {
    expect(role, StudyOcrRole.answer);
    requests++;
    if (requests == 1) throw StateError('服务超时');
    return '单项选择题\n1. B\n2. C';
  }
}

void main() {
  testWidgets(
      'page comparison waits for consent, retains local text on failure and returns reviewed text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 660));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workspace = _Workspace();
    addTearDown(workspace.dispose);
    String? adopted;
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
      create: (_) => _Account(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Builder(builder: (context) {
          return Scaffold(
            body: TextButton(
              onPressed: () async {
                adopted = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => StudyBookTheme(
                      child: StudyOcrCompare(
                        page: const StudyPdfText(
                          StudyPageReference('doc', '第一章答案.pdf', 3),
                          '单项选择题\n1. A\n2. C',
                        ),
                        pdf: const _Pdf(),
                        workspace: workspace,
                        role: StudyOcrRole.answer,
                      ),
                    ),
                  ),
                );
              },
              child: const Text('打开校对'),
            ),
          );
        }),
      ),
    ));

    await tester.tap(find.text('打开校对'));
    await tester.pumpAndSettle();
    expect(find.text('核对第 3 页'), findsOneWidget);
    await tester.tap(find.text('用 AI 重识别本页'));
    await tester.pumpAndSettle();
    expect(workspace.requests, 0);
    expect(find.textContaining('识别测试服务'), findsOneWidget);
    await tester.tap(find.text('识别本页'));
    await tester.pumpAndSettle();
    expect(workspace.requests, 1);
    expect(find.text('AI 暂未读出这一页，本地结果仍在'), findsOneWidget);
    await tester.tap(find.text('本地'));
    await tester.pumpAndSettle();
    expect(find.text('单项选择题\n1. A\n2. C'), findsOneWidget);

    await tester.tap(find.text('用 AI 重识别本页'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('识别本页'));
    await tester.pumpAndSettle();
    expect(workspace.requests, 2);
    final editor = find.byKey(const ValueKey('study-ocr-draft'));
    expect(
        tester.widget<TextField>(editor).controller!.text, '单项选择题\n1. B\n2. C');
    expect(find.text('1 行 AI 文字与本地结果不同'), findsOneWidget);
    await tester.enterText(editor, '单项选择题\n1. D\n2. C');
    expect(adopted, isNull);
    await tester.tap(find.text('采用校对后的文字'));
    await tester.pumpAndSettle();
    expect(adopted, '单项选择题\n1. D\n2. C');
    expect(tester.takeException(), isNull);
  });
}
