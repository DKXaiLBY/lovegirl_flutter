import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/features/study/study_workspace.dart';

void main() {
  const notes = '计划：确定组织的目标，并选择达成目标的行动方案。';
  final draft = draftFromNotes('计划', notes);
  final card = StudyCard(
    id: 'card-one',
    subject: StudySubject.management,
    title: '计划',
    reference: '讲义第 2 页',
    notes: notes,
    questions: draft,
  );

  test('drafts quote the supplied text and are valid before confirmation', () {
    expect(draft.map((question) => question.kind),
        [StudyQuestionKind.recall, StudyQuestionKind.blank]);
    for (final question in draft) {
      expect(notes, contains(question.source));
      expect(question.validate(notes), isNull);
      expect(question.validate('另一页'), isNotNull);
    }
  });

  test('review adjusts the due date and exporting clears progress', () {
    final day = DateTime(2026, 12, 31);
    expect(card.isDue(day), isTrue);
    final correct = card.afterReview(true, day);
    expect(correct.dueOn, '2027-01-03');
    expect(correct.isDue(DateTime(2027, 1, 2)), isFalse);
    final missed = correct.afterReview(false, DateTime(2027, 1, 3));
    expect(missed.attempts, 2);
    expect(missed.level, 0);
    expect(missed.dueOn, '2027-01-04');
    final copied = StudyCard.fromJson(missed.copied().toJson());
    expect(copied.id, isNot(card.id));
    expect(copied.attempts, 0);
    expect(copied.dueOn, isNull);
    expect(copied.reference, card.reference);
  });

  test('journal checks debit, credit and numeric amount individually', () {
    const entry = StudyQuestion(
      kind: StudyQuestionKind.journal,
      prompt: '记录收到的现金',
      source: '收到现金 100 元',
      answer: '库存现金\n实收资本\n100.00',
    );
    expect(entry.validate('收到现金 100 元'), isNull);
    expect(entry.checkJournal(['库存现金', '实收资本', '100']), isEmpty);
    expect(entry.checkJournal(['银行存款', '实收资本', '50']), ['借方科目', '金额']);
  });
}
