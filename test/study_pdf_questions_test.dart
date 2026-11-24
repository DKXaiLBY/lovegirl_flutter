import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/features/study/study_pdf.dart';
import 'package:lovegirl_flutter/features/study/study_pdf_questions.dart';
import 'package:lovegirl_flutter/features/study/study_workspace.dart';

StudyPdfText page(String text,
        {int page = 1,
        String file = '练习.pdf',
        List<StudyPdfLine> lines = const []}) =>
    StudyPdfText(
        StudyPageReference('319c911b-e26e-47fa-be17-ea07aeb81281', file, page),
        text,
        lines: lines);

const quiz = '''第一章
单选题
1. 应采用哪项职能？
A. 计划  B. 组织
C. 领导  D. 控制
多选题
1. 下列哪些属于管理职能？
A. 计划
B. 无关选项
C. 领导
D. 另一无关选项''';

void main() {
  test('scanned answer rows preserve positions and chapter/type scope', () {
    final keys = page('', page: 7, file: '答案.pdf', lines: const [
      StudyPdfLine('第1章 答案速查', 5, 20, 20),
      StudyPdfLine('单选', 5, 50, 20),
      StudyPdfLine('2', 90, 82, 14),
      StudyPdfLine('1', 10, 80, 14),
      StudyPdfLine('A', 90, 109, 14),
      StudyPdfLine('D', 10, 110, 14),
      StudyPdfLine('多选', 10, 138, 20),
      StudyPdfLine('1', 10, 170, 14),
      StudyPdfLine('A、C', 10, 195, 14),
      StudyPdfLine('第二章', 5, 230, 19),
      StudyPdfLine('1. B', 5, 260, 14),
    ]);
    final result =
        matchStudyPdfQuestions([page(quiz, page: 6)], [keys], chapter: '选定章节');
    expect(
        result.map((question) => question.label), ['第1章 · 单选 1', '第1章 · 多选 1']);
    expect(result[0].suggested, ['控制']);
    expect(result[1].suggested, ['计划', '领导']);
    final saved = result[1].toCard(StudySubject.management)!;
    final restored = StudyCard.fromJson(saved.toJson()).questions.single;
    expect(restored.questionPage?.page, 6);
    expect(restored.answerPage?.page, 7);
    expect(restored.checkMultiChoice({'领导', '计划'}), isTrue);
    expect(restored.checkMultiChoice({'计划'}), isFalse);
  });

  test(
      'repeated question ids or incompatible visible editions keep answers unassigned',
      () {
    const question = '1. 问题？\nA. 甲\nB. 乙\nC. 丙\nD. 丁';
    final duplicate = matchStudyPdfQuestions(
        [page('$question\n$question')], [page('单选\n1. A')],
        chapter: '第一章');
    expect(duplicate, hasLength(2));
    expect(duplicate.every((entry) => entry.suggested.isEmpty), isTrue);
    final differentEdition = matchStudyPdfQuestions([
      page(question, file: '2027Mayi 试题.pdf')
    ], [
      page('单选\n1. A', file: '2026Mayi 答案.pdf')
    ], chapter: '第一章');
    expect(differentEdition.single.suggested, isEmpty);
    final conflictingAnswers = matchStudyPdfQuestions(
        [page(question)], [page('单选\n1. A\n1. C')],
        chapter: '第一章');
    expect(conflictingAnswers.single.suggested, isEmpty);
  });

  test('multi-blank answers retain the blank order and an independent page',
      () {
    final result = matchStudyPdfQuestions([
      page('导论\n填空题\n（1）管理包括____和____。', page: 4)
    ], [
      page('导论\n填空答案\n（1） 计划；控制', page: 8)
    ], chapter: '导论');
    final question =
        result.single.toCard(StudySubject.management)!.questions.single;
    expect(question.kind, StudyQuestionKind.multiBlank);
    expect(question.answerParts, ['计划', '控制']);
    expect(question.checkMultiBlank(['计划。', '控制']), isTrue);
    expect(question.checkMultiBlank(['控制', '计划']), isFalse);
    expect(question.answerPage?.page, 8);
  });

  test('a question can continue onto another page with an explicit inline key',
      () {
    final result = matchStudyPdfQuestions([
      page('第1章\n1. 属于哪项？\nA. 甲\nB. 乙', page: 3),
      page('C. 丙\nD. 丁\n【正确答案】 B', page: 4),
    ], [], chapter: '第一章');
    expect(result.single.suggested, ['乙']);
    expect(result.single.page.page, 3);
    expect(result.single.answerPage?.page, 4);
  });
}
