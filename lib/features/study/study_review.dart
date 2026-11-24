import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'study_book_theme.dart';
import 'study_pdf.dart';
import 'study_workspace.dart';

class StudyReview extends StatefulWidget {
  const StudyReview(
      {super.key,
      required this.workspace,
      required this.cards,
      this.returnLabel = '返回备考'});
  final StudyWorkspace workspace;
  final List<StudyCard> cards;
  final String returnLabel;

  @override
  State<StudyReview> createState() => _StudyReviewState();
}

class _StudyReviewState extends State<StudyReview> {
  final _text = List.generate(8, (_) => TextEditingController());
  final _scroll = ScrollController();
  final _feedback = GlobalKey();
  int _card = 0;
  int _question = 0;
  int _again = 0;
  String? _option;
  final _options = <String>{};
  String? _error;
  bool _revealed = false;
  bool? _correct;
  bool _cardCorrect = true;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
    _scroll.dispose();
    for (final controller in _text) {
      controller.dispose();
    }
    super.dispose();
  }

  StudyCard get _currentCard => widget.cards[_card];
  StudyQuestion get _current => _currentCard.questions[_question];

  void _reveal(bool? result) {
    FocusScope.of(context).unfocus();
    setState(() {
      _revealed = true;
      _correct = result;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final feedbackContext = _feedback.currentContext;
      if (feedbackContext != null) {
        Scrollable.ensureVisible(feedbackContext, alignment: 0.04);
      }
    });
  }

  void _resetQuestion() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    for (final field in _text) {
      field.clear();
    }
    _option = null;
    _options.clear();
    _error = null;
    _revealed = false;
    _correct = null;
  }

  Future<void> _next(bool correct) async {
    if (_saving) return;
    final card = _currentCard;
    final passed = _cardCorrect && correct;
    if (_question < card.questions.length - 1) {
      setState(() {
        _cardCorrect = passed;
        _question++;
        _resetQuestion();
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.workspace.saveCard(card.afterReview(passed, DateTime.now()));
      if (mounted) {
        setState(() {
          if (!passed) _again++;
          _done = _card + 1 == widget.cards.length;
          if (!_done) _card++;
          _question = 0;
          _cardCorrect = true;
          _resetQuestion();
        });
      }
    } catch (failure) {
      if (mounted) {
        setState(() => _error =
            extractServerMessage(failure, fallback: '复习结果暂未保存，当前题目已保留'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StudyBookTheme(child: Builder(builder: _buildBook));

  Widget _buildBook(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    if (_done) {
      return Scaffold(
        appBar: AppBar(title: const Text('本次复习')),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('已完成 ${widget.cards.length} 个考点',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(_again == 0 ? '下次复习时间已安排' : '$_again 个考点明天再练'),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(widget.returnLabel)),
          ]),
        )),
      );
    }
    final card = _currentCard, question = _current;
    final kind = question.kind;
    final fields = switch (kind) {
      StudyQuestionKind.blank => const ['你的答案'],
      StudyQuestionKind.multiBlank => [
          for (var i = 1; i <= question.answerParts.length; i++) '第 $i 空'
        ],
      StudyQuestionKind.journal => const ['借方科目', '贷方科目', '金额'],
      _ => const <String>[],
    };
    final entered =
        _text.take(fields.length).map((field) => field.text.trim()).toList();
    final account = widget.workspace.account;
    return Scaffold(
      appBar: AppBar(
          title: Text('第 ${_question + 1} / ${card.questions.length} 题')),
      body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
          children: [
            LinearProgressIndicator(
                value: (_question + 1) / card.questions.length,
                backgroundColor: colors.outlineVariant,
                minHeight: 2),
            const SizedBox(height: 16),
            Text(card.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                )),
            const SizedBox(height: 22),
            Text(question.prompt,
                style: theme.textTheme.headlineSmall?.copyWith(height: 1.45)),
            const SizedBox(height: 20),
            if (kind == StudyQuestionKind.choice ||
                kind == StudyQuestionKind.multiChoice) ...[
              const Divider(height: 1),
              for (final (index, option) in question.options.indexed)
                _ChoiceTile(
                  letter: String.fromCharCode(65 + index),
                  text: option,
                  multiple: kind == StudyQuestionKind.multiChoice,
                  selected: kind == StudyQuestionKind.choice
                      ? _option == option
                      : _options.contains(option),
                  onTap: _revealed
                      ? null
                      : () => setState(() {
                            if (kind == StudyQuestionKind.choice) {
                              _option = option;
                            } else if (!_options.add(option)) {
                              _options.remove(option);
                            }
                          }),
                ),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _text[i],
                  enabled: !_revealed,
                  onChanged: (_) => setState(() {}),
                  keyboardType: kind == StudyQuestionKind.journal && i == 2
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(labelText: fields[i]),
                ),
              ),
            if (!_revealed) ...[
              FilledButton(
                onPressed: switch (kind) {
                  StudyQuestionKind.recall => () => _reveal(null),
                  StudyQuestionKind.choice => _option == null
                      ? null
                      : () => _reveal(_option == question.answer),
                  StudyQuestionKind.multiChoice => _options.isEmpty
                      ? null
                      : () => _reveal(question.checkMultiChoice(_options)),
                  StudyQuestionKind.blank => _text.first.text.trim().isEmpty
                      ? null
                      : () => _reveal(_text.first.text.trim() == question.answer
                          ? true
                          : null),
                  StudyQuestionKind.multiBlank =>
                    entered.any((value) => value.isEmpty)
                        ? null
                        : () => _reveal(
                            question.checkMultiBlank(entered) ? true : null),
                  StudyQuestionKind.journal =>
                    entered.any((value) => value.isEmpty)
                        ? null
                        : () => _reveal(question.checkJournal(entered).isEmpty),
                },
                child: Text(
                    kind == StudyQuestionKind.recall ? '想好了，核对要点' : '提交答案'),
              ),
              TextButton(
                  onPressed: () => _reveal(false),
                  child: const Text('想不起来，先看解析')),
            ] else ...[
              Container(
                  key: _feedback,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    border: BorderDirectional(
                        start: BorderSide(color: colors.primary, width: 2)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          _correct == true
                              ? '回答正确'
                              : _correct == false
                                  ? '明天再练一次'
                                  : '对照参考答案',
                          style: theme.textTheme.titleLarge),
                      if (kind == StudyQuestionKind.journal &&
                          _correct == false &&
                          entered.every((value) => value.isNotEmpty))
                        Text(
                            '需要核对 ${question.checkJournal(entered).join('、')}'),
                      const SizedBox(height: 8),
                      Text(question.answer,
                          style: studySerif(theme.textTheme.bodyLarge)),
                      const SizedBox(height: 18),
                      Text(card.reference.isEmpty ? '资料出处' : card.reference,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(question.source,
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      if (question.questionPage case final page?)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('试题出处 · 第 ${page.page} 页'),
                            subtitle: Text(page.name),
                            onTap: account != null && StudyPdf.available
                                ? () => openStudyPage(context, page, account)
                                : null),
                      if (question.answerPage case final page?)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('答案出处 · 第 ${page.page} 页'),
                            subtitle: Text(page.name),
                            onTap: account != null && StudyPdf.available
                                ? () => openStudyPage(context, page, account)
                                : null),
                    ],
                  )),
              const SizedBox(height: 15),
              if (_error case final message?)
                Semantics(
                    liveRegion: true,
                    child: Text(message,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              if (_correct == null) ...[
                FilledButton(
                    onPressed: _saving ? null : () => _next(true),
                    child: const Text('要点都答到了')),
                OutlinedButton(
                    onPressed: _saving ? null : () => _next(false),
                    child: const Text('漏了要点，明天再练')),
              ] else ...[
                FilledButton(
                    onPressed: _saving ? null : () => _next(_correct!),
                    child: Text(_saving
                        ? '正在保存…'
                        : _correct == true
                            ? '继续'
                            : '记下错题并继续')),
                if (_correct == true)
                  OutlinedButton(
                      onPressed: _saving ? null : () => _next(false),
                      child: const Text('是猜对的，明天再练')),
              ],
            ],
          ]),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile(
      {required this.letter,
      required this.text,
      required this.multiple,
      required this.selected,
      required this.onTap});

  final String letter;
  final String text;
  final bool multiple;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: !multiple,
        child: Material(
          color: selected ? colors.primaryContainer : colors.surface,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                  border: BorderDirectional(
                start: BorderSide(
                    color: selected ? colors.primary : Colors.transparent,
                    width: 2),
                bottom: BorderSide(color: colors.outlineVariant),
              )),
              padding: const EdgeInsets.fromLTRB(8, 13, 8, 13),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 31),
                  padding: const EdgeInsetsDirectional.only(end: 9),
                  decoration: BoxDecoration(
                      border: BorderDirectional(
                    end: BorderSide(color: colors.outlineVariant),
                  )),
                  child: Center(
                      widthFactor: 1,
                      child: Text(letter,
                          style: studySerif(theme.textTheme.titleMedium,
                                  weight: FontWeight.w700)
                              .copyWith(
                                  color: selected
                                      ? colors.primary
                                      : colors.onSurface))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(text,
                        softWrap: true,
                        style: studySerif(theme.textTheme.bodyLarge)
                            .copyWith(height: 1.55))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
