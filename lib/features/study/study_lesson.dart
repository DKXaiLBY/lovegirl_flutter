import 'package:flutter/material.dart';

import '../../utils/lovegirl_theme.dart';
import 'study_editor.dart';
import 'study_review.dart';
import 'study_workspace.dart';

class StudyLesson extends StatelessWidget {
  const StudyLesson({super.key, required this.workspace, required this.lesson});

  final StudyWorkspace workspace;
  final StudyCard lesson;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: workspace,
        builder: (context, _) {
          final card = workspace.cards
              .firstWhere((card) => card.id == lesson.id, orElse: () => lesson);
          final theme = Theme.of(context);
          final hasPractice = card.questions.isNotEmpty;
          final enabled =
              workspace.ready && !workspace.loading && !workspace.saving;
          final sections = card.notes.trim().split(RegExp(r'\n[ \t]*\n+'));
          return Scaffold(
            appBar: AppBar(title: const Text('阅读考点')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(card.subject.label,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: context.lgTextSecondary)),
                const SizedBox(height: 10),
                Text(card.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, text) in sections.indexed) ...[
                            if (index > 0) const SizedBox(height: 18),
                            _paragraph(theme, text),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (card.reference.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(card.reference,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.lgTextSecondary)),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: !enabled
                      ? null
                      : () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => hasPractice
                                    ? StudyReview(
                                        workspace: workspace, cards: [card])
                                    : StudyEditor(
                                        workspace: workspace, card: card)),
                          ),
                  child: Text(hasPractice
                      ? '练习本节 · ${card.questions.length} 题'
                      : '添加练习题'),
                ),
              ],
            ),
          );
        },
      );

  Widget _paragraph(ThemeData theme, String text) {
    final style = theme.textTheme.bodyLarge?.copyWith(height: 1.6);
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
              style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: text.substring(lineBreak + 1)),
        ]),
        style: style);
  }
}
