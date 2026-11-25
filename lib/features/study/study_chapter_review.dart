import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import 'study_book_theme.dart';
import 'study_editor.dart';
import 'study_pdf.dart';
import 'study_workspace.dart';

typedef ChapterDraft = ({
  String title,
  List<StudyCard> cards,
  Set<String> reviewed
});

String _draftKey(int account) => 'study_chapter_draft_$account';

Future<ChapterDraft?> loadChapterDraft(int account) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_draftKey(account));
  if (raw == null) return null;
  final data = jsonDecode(raw) as Map;
  return (
    title: data['title'] as String,
    cards: (data['cards'] as List)
        .map((item) =>
            StudyCard.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(),
    reviewed: (data['reviewed'] as List).cast<String>().toSet(),
  );
}

Future<void> saveChapterDraft(int account, ChapterDraft draft) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _draftKey(account),
      jsonEncode({
        'title': draft.title,
        'cards': draft.cards.map((card) => card.toJson()).toList(),
        'reviewed': draft.reviewed.toList(),
      }));
}

class StudyChapterReview extends StatefulWidget {
  const StudyChapterReview(
      {super.key, required this.workspace, required this.draft});

  final StudyWorkspace workspace;
  final ChapterDraft draft;

  @override
  State<StudyChapterReview> createState() => _StudyChapterReviewState();
}

class _StudyChapterReviewState extends State<StudyChapterReview> {
  late final _cards = [...widget.draft.cards];
  late final _reviewed = {...widget.draft.reviewed};
  bool _saving = false;
  String? _error;

  String _key(StudyCard card, int index) => '${card.id}:$index';

  Future<void> _persist() => saveChapterDraft(widget.workspace.account!,
      (title: widget.draft.title, cards: _cards, reviewed: _reviewed));

  Future<void> _editCard(int index) async {
    final card = _cards[index];
    final title = TextEditingController(text: card.title);
    final notes = TextEditingController(text: card.notes);
    final changed = await showDialog<StudyCard>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('编辑考点'),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: title,
              maxLength: 120,
              decoration:
                  const InputDecoration(labelText: '标题', counterText: '')),
          TextField(
              controller: notes,
              maxLength: 12000,
              minLines: 4,
              maxLines: 12,
              decoration:
                  const InputDecoration(labelText: '考点与原文', counterText: '')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final updated = notes.text.trim();
              if (title.text.trim().isEmpty ||
                  updated.isEmpty ||
                  card.questions
                      .any((question) => !updated.contains(question.source))) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写考点并保留题目的原文出处')));
                return;
              }
              Navigator.pop(
                  dialog,
                  StudyCard(
                    id: card.id,
                    subject: card.subject,
                    title: title.text.trim(),
                    reference: card.reference,
                    notes: updated,
                    questions: card.questions,
                  ));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    title.dispose();
    notes.dispose();
    if (changed == null || !mounted) return;
    setState(() => _cards[index] = changed);
    await _persist();
  }

  Future<void> _review(int cardIndex, int questionIndex) async {
    final card = _cards[cardIndex];
    final question = card.questions[questionIndex];
    final changed = await showDialog<StudyQuestion>(
      context: context,
      builder: (dialog) => StudyQuestionEditor(
        notes: card.notes,
        question: question,
        allowJournal: card.subject == StudySubject.accounting,
        sourceActions: [
          if (question.answerPage case final page?)
            TextButton(
              onPressed: () =>
                  openStudyPage(dialog, page, widget.workspace.account!),
              child: Text('PDF 第 ${page.page} 页'),
            ),
        ],
      ),
    );
    if (changed == null || !mounted) return;
    final questions = [...card.questions]..[questionIndex] = changed;
    setState(() {
      _cards[cardIndex] = StudyCard(
        id: card.id,
        subject: card.subject,
        title: card.title,
        reference: card.reference,
        notes: card.notes,
        questions: questions,
      );
      _reviewed.add(_key(card, questionIndex));
    });
    await _persist();
  }

  Future<void> _finish(bool share) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final count = share
          ? await widget.workspace.shareChapter(_cards)
          : await widget.workspace.importCards(_cards);
      if (!mounted) return;
      if (share) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(count == 0 ? 'TA 已收到本章' : '已发给 TA')));
      } else {
        Navigator.pop(context, count);
      }
    } catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = extractServerMessage(failure,
              fallback: share ? '暂未发送，请重试' : '暂未导入，请重试');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _cards.fold(0, (sum, card) => sum + card.questions.length);
    final ready = !_saving && _reviewed.length == total;
    return Scaffold(
      appBar: AppBar(title: const Text('核对章节')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Text(widget.draft.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('已核对 ${_reviewed.length} / $total 题',
              style: theme.textTheme.bodySmall),
          for (final (cardIndex, card) in _cards.indexed) ...[
            const Divider(height: 28),
            Row(children: [
              Expanded(
                  child: Text(card.title, style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: '编辑考点',
                onPressed: _saving ? null : () => _editCard(cardIndex),
                icon: const Icon(Icons.edit_outlined),
              ),
            ]),
            const SizedBox(height: 6),
            SelectableText(card.notes,
                style: studySerif(theme.textTheme.bodyMedium)),
            for (final (questionIndex, question) in card.questions.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(question.prompt),
                trailing: Icon(_reviewed.contains(_key(card, questionIndex))
                    ? Icons.check_circle_outline
                    : Icons.chevron_right),
                onTap: _saving ? null : () => _review(cardIndex, questionIndex),
              ),
          ],
          if (_error case final error?)
            Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
                onPressed: ready ? () => _finish(false) : null,
                child: const Text('保存到我的备考')),
            FilledButton(
                onPressed: ready ? () => _finish(true) : null,
                child: const Text('发给 TA')),
          ],
        ),
      ),
    );
  }
}
