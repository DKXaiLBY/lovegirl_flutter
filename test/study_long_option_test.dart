import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/features/study/study_editor.dart';
import 'package:lovegirl_flutter/features/study/study_review.dart';
import 'package:lovegirl_flutter/features/study/study_screen.dart';
import 'package:lovegirl_flutter/features/study/study_workspace.dart';
import 'package:provider/provider.dart';

const _longOption = '第一次国内革命战争时期关于新民主主义革命的基本思想、'
    '早期探索的现实背景、实践基础及其历史意义，需要结合教材原文完整阅读。';
const _question = StudyQuestion(
    kind: StudyQuestionKind.choice,
    prompt: '下列哪项与讲义的表述一致？',
    answer: _longOption,
    source: '阅读样本',
    options: [_longOption, '另一个选项']);

Widget _phone(Widget page) => MaterialApp(
    builder: (context, child) => MediaQuery(
        data:
            MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.7)),
        child: child!),
    home: page);

class _Workspace extends StudyWorkspace {
  _Workspace(List<StudyCard> lessons) : super(null) {
    cards = lessons;
  }

  @override
  bool get ready => true;

  @override
  Future<void> saveCard(StudyCard card) async {
    cards = [for (final old in cards) old.id == card.id ? card : old];
    notifyListeners();
  }
}

void main() {
  testWidgets('PDF verification makes a long choice wrap inside its field',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_phone(Builder(builder: (context) {
      return Scaffold(
          body: TextButton(
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const StudyQuestionEditor(
                      notes: '阅读样本', question: _question, allowJournal: false)),
              child: const Text('打开核对')));
    })));
    await tester.tap(find.text('打开核对'));
    await tester.pumpAndSettle();

    final editable = find.byWidgetPredicate((widget) =>
        widget is EditableText && widget.controller.text == _longOption);
    final field = tester.state<EditableTextState>(editable);
    final render = field.renderEditable;
    final text = field.widget.controller.text;
    final first = render.getLocalRectForCaret(const TextPosition(offset: 0));
    final last = render.getLocalRectForCaret(TextPosition(offset: text.length));
    expect(last.top, greaterThan(first.top));
    expect(last.bottom, lessThanOrEqualTo(render.size.height + 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a long choice fits and can be selected at large text on narrow screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workspace = StudyWorkspace(null);
    addTearDown(workspace.dispose);
    final card = StudyCard(
        id: 'chapter-test',
        subject: StudySubject.politics,
        title: '毛概第一章',
        reference: '',
        notes: '阅读样本',
        questions: const [_question]);
    await tester
        .pumpWidget(_phone(StudyReview(workspace: workspace, cards: [card])));

    final choice = find.text(_longOption);
    final render = tester.renderObject<RenderParagraph>(choice);
    final last = render
        .getBoxesForSelection(TextSelection(
            baseOffset: _longOption.length - 1,
            extentOffset: _longOption.length))
        .single;
    final first = render
        .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1))
        .single;
    expect(last.top, greaterThan(first.top));
    expect(last.right, lessThanOrEqualTo(render.size.width + 1));
    expect(last.bottom, lessThanOrEqualTo(render.size.height + 1));
    await tester.tap(choice);
    await tester.scrollUntilVisible(find.text('提交答案').hitTestable(), 180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交答案'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('回答正确').hitTestable(), 180);
    expect(find.text('回答正确'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lesson opens its notes before its own practice',
      (tester) async {
    final workspace = _Workspace([
      const StudyCard(
          id: 'chapter-one',
          subject: StudySubject.politics,
          title: '第一章',
          reference: '讲义第 1 页',
          notes: '先阅读这一节的考点。',
          questions: [_question]),
      const StudyCard(
          id: 'lecture-only',
          subject: StudySubject.politics,
          title: '第二章',
          reference: '讲义第 2 页',
          notes: '这一节暂时只有原文。',
          questions: []),
    ]);
    addTearDown(workspace.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<StudyWorkspace>.value(
            value: workspace, child: const StudyScreen())));

    await tester.tap(find.text('开始阅读'));
    await tester.pumpAndSettle();
    expect(find.text('先阅读这一节的考点。'), findsOneWidget);
    expect(find.text('讲义第 1 页'), findsOneWidget);
    await tester.tap(find.text('练习本节 · 1 题'));
    await tester.pumpAndSettle();
    expect(find.text(_question.prompt), findsOneWidget);
    expect(tester.widget<Text>(find.text(_question.prompt)).style?.fontFamily,
        'StudyBookSerif');
    await tester.tap(find.text(_longOption));
    await tester.scrollUntilVisible(find.text('提交答案').hitTestable(), 180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交答案'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('继续').hitTestable(), 180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回讲义'));
    await tester.pumpAndSettle();
    expect(find.text('先阅读这一节的考点。'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('继续阅读'), findsOneWidget);

    await tester.tap(find.text('第二章'));
    await tester.pumpAndSettle();
    expect(find.text('这一节暂时只有原文。'), findsOneWidget);
    expect(find.text('添加练习题'), findsOneWidget);
    expect(find.byType(StudyEditor), findsNothing);
  });

  testWidgets('today review opens the due lesson without opening its reader',
      (tester) async {
    final workspace = _Workspace(const [
      StudyCard(
          id: 'chapter-new',
          subject: StudySubject.politics,
          title: '未学新章',
          reference: '',
          notes: '首次阅读',
          questions: [_question]),
      StudyCard(
          id: 'chapter-due',
          subject: StudySubject.politics,
          title: '已到期的章节',
          reference: '',
          notes: '已经读过',
          questions: [_question],
          dueOn: '2000-01-01',
          attempts: 1),
    ]);
    addTearDown(workspace.dispose);
    await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<StudyWorkspace>.value(
            value: workspace, child: const StudyScreen())));
    expect(find.text('1 个考点待练习'), findsOneWidget);
    await tester.tap(find.text('今日复习'));
    await tester.pumpAndSettle();
    final review = tester.widget<StudyReview>(find.byType(StudyReview));
    expect(review.cards.map((card) => card.id), ['chapter-due']);
    expect(find.text('阅读考点'), findsNothing);
  });
}
