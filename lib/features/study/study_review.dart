import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'study_book_theme.dart';
import 'study_coach.dart';
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
    final wide = MediaQuery.sizeOf(context).width >= studyTwoPaneWidth;
    final choices = kind == StudyQuestionKind.choice ||
        kind == StudyQuestionKind.multiChoice;
    final prompt = [
      LinearProgressIndicator(
          value: (_question + 1) / card.questions.length,
          backgroundColor: colors.outlineVariant,
          borderRadius: BorderRadius.circular(4),
          minHeight: 4),
      const SizedBox(height: 16),
      Text(card.title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.onSurfaceVariant,
          )),
      const SizedBox(height: 12),
      Text(kind.label, style: theme.textTheme.labelMedium),
      const SizedBox(height: 8),
      Text(question.prompt,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontSize: wide ? 26 : 22, height: 1.45)),
    ];
    final response = <Widget>[
      if (choices) ...[
        for (final (index, option) in question.options.indexed)
          _ChoiceTile(
            letter: String.fromCharCode(65 + index),
            text: option,
            multiple: kind == StudyQuestionKind.multiChoice,
            selected: kind == StudyQuestionKind.choice
                ? _option == option
                : _options.contains(option),
            correct: _revealed &&
                (kind == StudyQuestionKind.choice
                    ? question.answer == option
                    : question.answerParts.contains(option)),
            incorrect: _revealed &&
                (kind == StudyQuestionKind.choice
                    ? _option == option && option != question.answer
                    : _options.contains(option) &&
                        !question.answerParts.contains(option)),
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
      if (!_revealed)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => _reveal(false),
            child: const Text('先看解析'),
          ),
        )
      else ...[
        Container(
            key: _feedback,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    _correct == true
                        ? '回答正确'
                        : _correct == false
                            ? '再练一次'
                            : '对照参考答案',
                    style: theme.textTheme.titleLarge),
                if (kind == StudyQuestionKind.journal &&
                    _correct == false &&
                    entered.every((value) => value.isNotEmpty))
                  Text('需要核对 ${question.checkJournal(entered).join('、')}'),
                const SizedBox(height: 8),
                Text(question.answer,
                    style: studySerif(theme.textTheme.bodyLarge)),
                if (question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(question.explanation),
                ],
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
                if (widget.workspace.coachAvailable)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudyCoach(
                                  workspace: widget.workspace,
                                  card: card,
                                  questionIndex: _question,
                                  selected: [_option, ..._options, ...entered]
                                      .whereType<String>()
                                      .where((value) => value.isNotEmpty)
                                      .toList(),
                                ))),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('问 AI'),
                  ),
              ],
            )),
        const SizedBox(height: 15),
        if (_error case final message?)
          Semantics(
              liveRegion: true,
              child: Text(message,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_correct == null) ...[
          TextButton(
              onPressed: _saving ? null : () => _next(false),
              child: const Text('漏了要点，明天再练')),
        ] else if (_correct == true)
          TextButton(
              onPressed: _saving ? null : () => _next(false),
              child: const Text('是猜对的，明天再练')),
      ],
    ];
    final submit = switch (kind) {
      StudyQuestionKind.recall => () => _reveal(null),
      StudyQuestionKind.choice =>
        _option == null ? null : () => _reveal(_option == question.answer),
      StudyQuestionKind.multiChoice => _options.isEmpty
          ? null
          : () => _reveal(question.checkMultiChoice(_options)),
      StudyQuestionKind.blank => entered.first.isEmpty
          ? null
          : () => _reveal(entered.first == question.answer ? true : null),
      StudyQuestionKind.multiBlank => entered.any((value) => value.isEmpty)
          ? null
          : () => _reveal(question.checkMultiBlank(entered) ? true : null),
      StudyQuestionKind.journal => entered.any((value) => value.isEmpty)
          ? null
          : () => _reveal(question.checkJournal(entered).isEmpty),
    };
    final primary = FilledButton(
      onPressed: !_revealed
          ? submit
          : _saving
              ? null
              : () => _next(_correct ?? true),
      child: Text(_saving
          ? '正在保存…'
          : !_revealed
              ? (kind == StudyQuestionKind.recall ? '想好了，核对要点' : '提交答案')
              : switch (_correct) {
                  true => '继续',
                  false => '记下错题并继续',
                  null => '要点都答到了',
                }),
    );
    final answerList = ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        if (!wide) ...[...prompt, const SizedBox(height: 22)],
        ...response,
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('第 ${_question + 1} / ${card.questions.length} 题'),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1120 : 680),
            child: Column(
              children: [
                Expanded(
                  child: wide
                      ? Row(children: [
                          Expanded(
                            child: ListView(
                              primary: false,
                              key: ValueKey((card.id, _question)),
                              padding:
                                  const EdgeInsets.fromLTRB(24, 12, 24, 24),
                              children: prompt,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(flex: 2, child: answerList),
                        ])
                      : answerList,
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: SafeArea(
                    top: false,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: wide ? 360 : double.infinity),
                        child: SizedBox(width: double.infinity, child: primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile(
      {required this.letter,
      required this.text,
      required this.multiple,
      required this.selected,
      required this.correct,
      required this.incorrect,
      required this.onTap});

  final String letter;
  final String text;
  final bool multiple;
  final bool selected;
  final bool correct;
  final bool incorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final success = theme.brightness == Brightness.dark
        ? const Color(0xff91dab0)
        : const Color(0xff22673f);
    final accent = correct
        ? success
        : incorrect
            ? colors.error
            : colors.primary;
    final emphasized = correct || incorrect || selected;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: emphasized ? accent : colors.outlineVariant),
    );
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: !multiple,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: emphasized
                ? Color.alphaBlend(
                    accent.withValues(alpha: .10), colors.surface)
                : colors.surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 30),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: emphasized
                              ? accent.withValues(alpha: .13)
                              : colors.surfaceContainerLow,
                        ),
                        child: Center(
                            widthFactor: 1,
                            child: Text(letter,
                                style: studySerif(theme.textTheme.titleMedium,
                                        weight: FontWeight.w700)
                                    .copyWith(
                                        color: emphasized
                                            ? accent
                                            : colors.onSurface))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(text,
                              softWrap: true,
                              style: studySerif(theme.textTheme.bodyLarge)
                                  .copyWith(height: 1.55))),
                      if (emphasized) ...[
                        const SizedBox(width: 8),
                        Icon(
                          incorrect
                              ? Icons.cancel_outlined
                              : Icons.check_circle,
                          color: accent,
                          size: 19,
                          semanticLabel: correct
                              ? '正确选项'
                              : incorrect
                                  ? '误选'
                                  : '已选',
                        ),
                      ],
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
