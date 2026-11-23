import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'study_workspace.dart';

class StudyReview extends StatefulWidget {
  const StudyReview({super.key, required this.workspace, required this.cards});
  final StudyWorkspace workspace;
  final List<StudyCard> cards;

  @override
  State<StudyReview> createState() => _StudyReviewState();
}

class _StudyReviewState extends State<StudyReview> {
  final _text = List.generate(3, (_) => TextEditingController());
  int _card = 0;
  int _question = 0;
  int _again = 0;
  String? _option;
  String? _error;
  bool _revealed = false;
  bool? _correct;
  bool _cardCorrect = true;
  bool _saving = false;
  bool _done = false;

  @override
  void dispose() {
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
  }

  void _resetQuestion() {
    for (final field in _text) {
      field.clear();
    }
    _option = null;
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
  Widget build(BuildContext context) {
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
                child: const Text('返回备考')),
          ]),
        )),
      );
    }
    final card = _currentCard, question = _current;
    final kind = question.kind;
    return Scaffold(
      appBar: AppBar(title: const Text('复习考点')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
          children: [
            Text(
                '${card.subject.label} · 考点 ${_card + 1}/${widget.cards.length} · 第 ${_question + 1} 题'),
            const SizedBox(height: 14),
            Text(question.prompt,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (kind == StudyQuestionKind.choice)
              for (final option in question.options)
                RadioListTile<String>(
                  value: option,
                  groupValue: _option,
                  title: Text(option),
                  onChanged: _revealed
                      ? null
                      : (value) => setState(() => _option = value),
                ),
            if (kind == StudyQuestionKind.blank ||
                kind == StudyQuestionKind.journal)
              for (var i = 0;
                  i < (kind == StudyQuestionKind.blank ? 1 : 3);
                  i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _text[i],
                    enabled: !_revealed,
                    onChanged: (_) => setState(() {}),
                    keyboardType: i == 2
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: InputDecoration(
                        labelText: kind == StudyQuestionKind.blank
                            ? '你的答案'
                            : const ['借方科目', '贷方科目', '金额'][i]),
                  ),
                ),
            if (!_revealed) ...[
              FilledButton(
                style: rebuildFilledStyle(context),
                onPressed: switch (kind) {
                  StudyQuestionKind.recall => () => _reveal(null),
                  StudyQuestionKind.choice => _option == null
                      ? null
                      : () => _reveal(_option == question.answer),
                  StudyQuestionKind.blank => _text.first.text.trim().isEmpty
                      ? null
                      : () => _reveal(_text.first.text.trim() == question.answer
                          ? true
                          : null),
                  StudyQuestionKind.journal =>
                    _text.any((field) => field.text.trim().isEmpty)
                        ? null
                        : () => _reveal(question
                            .checkJournal(
                                _text.map((field) => field.text).toList())
                            .isEmpty),
                },
                child: Text(
                    kind == StudyQuestionKind.recall ? '想好了，核对要点' : '提交答案'),
              ),
              TextButton(
                  onPressed: () => _reveal(false),
                  child: const Text('想不起来，先看解析')),
            ] else ...[
              RebuildGlass(
                  radius: 18,
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
                          style: Theme.of(context).textTheme.titleLarge),
                      if (kind == StudyQuestionKind.journal &&
                          _correct == false &&
                          _text.every((field) => field.text.isNotEmpty))
                        Text(
                            '需要核对 ${question.checkJournal(_text.map((field) => field.text).toList()).join('、')}'),
                      const SizedBox(height: 8),
                      Text(question.answer),
                      const SizedBox(height: 18),
                      Text(card.reference.isEmpty ? '资料出处' : card.reference,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(question.source,
                          style: TextStyle(color: context.lgTextSecondary)),
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
