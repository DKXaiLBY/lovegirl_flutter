import 'package:flutter/material.dart';

import 'study_book_theme.dart';
import 'study_coach.dart';
import 'study_editor.dart';
import 'study_pdf.dart';
import 'study_review.dart';
import 'study_workspace.dart';

class StudyLesson extends StatelessWidget {
  const StudyLesson({super.key, required this.workspace, required this.lesson});

  final StudyWorkspace workspace;
  final StudyCard lesson;

  @override
  Widget build(BuildContext context) => StudyBookTheme(
          child: ListenableBuilder(
        listenable: workspace,
        builder: (context, _) {
          final card = workspace.cards
              .firstWhere((card) => card.id == lesson.id, orElse: () => lesson);
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          final hasPractice = card.questions.isNotEmpty;
          final enabled =
              workspace.ready && !workspace.loading && !workspace.saving;
          final sections = card.notes.trim().split(RegExp(r'\n[ \t]*\n+'));
          return Scaffold(
            appBar: AppBar(title: const Text('阅读考点')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Divider(height: 1, color: colors.primary),
                const SizedBox(height: 22),
                Text(card.subject.label,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 10),
                Text(card.title.replaceFirst(' · ', '\n'),
                    style:
                        theme.textTheme.headlineMedium?.copyWith(height: 1.22)),
                const SizedBox(height: 22),
                const Divider(height: 1),
                const SizedBox(height: 22),
                SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, text) in sections.indexed) ...[
                        if (index > 0) const SizedBox(height: 20),
                        _paragraph(theme, text),
                      ],
                    ],
                  ),
                ),
                if (card.reference.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(card.reference,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant)),
                ],
                if (card.questions.firstOrNull?.answerPage case final page?
                    when StudyPdf.available && workspace.account != null)
                  TextButton(
                    onPressed: () =>
                        openStudyPage(context, page, workspace.account!),
                    child: Text('PDF 第 ${page.page} 页'),
                  ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: !enabled
                      ? null
                      : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => hasPractice
                                    ? StudyReview(
                                        workspace: workspace,
                                        cards: [card],
                                        returnLabel: '返回讲义')
                                    : StudyBookTheme(
                                        child: StudyEditor(
                                            workspace: workspace, card: card))),
                          ),
                  child: Text(hasPractice
                      ? '练习本节 · ${card.questions.length} 题'
                      : '添加练习题'),
                ),
                if (workspace.coachAvailable)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                StudyCoach(workspace: workspace, card: card))),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('问 AI'),
                  ),
              ],
            ),
          );
        },
      ));

  Widget _paragraph(ThemeData theme, String text) {
    final style = studySerif(theme.textTheme.bodyLarge).copyWith(height: 1.65);
    final lineBreak = text.indexOf('\n');
    if (lineBreak < 1 || lineBreak > 18) return Text(text, style: style);
    final firstLine = text.substring(0, lineBreak);
    if (RegExp(r'[。？！，；：]').hasMatch(firstLine)) {
      return Text(text, style: style);
    }
    return Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$firstLine\n',
              style: studySerif(style, weight: FontWeight.w700)),
          TextSpan(text: text.substring(lineBreak + 1)),
        ]),
        style: style);
  }
}
