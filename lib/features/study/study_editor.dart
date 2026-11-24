import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../services/api_service.dart';
import '../../widgets/rebuild_controls.dart';
import 'study_pdf.dart';
import 'study_workspace.dart';

class StudyEditor extends StatefulWidget {
  const StudyEditor(
      {super.key, required this.workspace, this.card, this.sourcePage});
  final StudyWorkspace workspace;
  final StudyCard? card;
  final StudyPageReference? sourcePage;

  @override
  State<StudyEditor> createState() => _StudyEditorState();
}

class _StudyEditorState extends State<StudyEditor> {
  late final _title = TextEditingController(text: widget.card?.title);
  late final _reference = TextEditingController(text: widget.card?.reference);
  late final _notes = TextEditingController(text: widget.card?.notes);
  late StudySubject _subject = widget.card?.subject ?? StudySubject.politics;
  late final _questions = [...?widget.card?.questions];
  String? _photo;
  String? _error;
  bool _reading = false;
  bool _generating = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1900,
          maxHeight: 2300,
          imageQuality: 90);
      if (photo == null || !mounted) return;
      final crop =
          await ImageCropper().cropImage(sourcePath: photo.path, uiSettings: [
        AndroidUiSettings(toolbarTitle: '框选要背的段落', lockAspectRatio: false),
      ]);
      if (crop == null || !mounted) return;
      setState(() => _photo = crop.path);
      final text = await const MethodChannel('lovegirl/device')
          .invokeMethod<String>('recognizeStudyText', crop.path);
      if (!mounted) return;
      final recognized = text?.trim() ?? '';
      if (recognized.isEmpty) {
        setState(() => _error = '没有读到文字，请重选图片或填写原文');
        return;
      }
      final combined = [_notes.text.trim(), recognized]
          .where((part) => part.isNotEmpty)
          .join('\n');
      if (combined.length > 12000) {
        setState(() => _error = '请缩小框选范围，每个考点最多 12000 字');
        return;
      }
      _notes.text = combined;
    } catch (_) {
      if (mounted) setState(() => _error = '文字暂时无法识别，请重选图片或粘贴笔记');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _draft() {
    final additions = draftFromNotes(_title.text, _selectedNotes())
        .where((question) =>
            _questions.every((saved) => saved.prompt != question.prompt))
        .take(6 - _questions.length)
        .toList();
    setState(() {
      _questions.addAll(additions);
      _error = additions.isEmpty ? '请补充原文、编辑已有草稿，或添加一道题' : null;
    });
  }

  String _selectedNotes() {
    final selection = _notes.selection;
    final all = _notes.text;
    return selection.isValid &&
            !selection.isCollapsed &&
            selection.end <= all.length
        ? selection.textInside(all).trim()
        : all.trim();
  }

  Future<void> _aiDraft() async {
    final source = _selectedNotes();
    if (source.length < 12 || source.length > 4000) {
      setState(() => _error = '请选择 12–4000 字资料原文');
      return;
    }
    final approved = await showDialog<bool>(
        context: context,
        builder: (sheet) => AlertDialog(
              title: const Text('AI 起草题目'),
              content: Text('将这段 ${source.length} 字的原文发送给阿里云百炼起草，确认后才保存题目。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(sheet, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(sheet, true),
                    child: const Text('发送并起草'))
              ],
            ));
    if (!mounted || approved != true) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final questions = await widget.workspace.draftQuestions(_subject, source);
      if (!mounted) return;
      final accepted = questions
          .where((question) =>
              question.validate(_notes.text) == null &&
              _questions.every((old) => old.prompt != question.prompt))
          .take(6 - _questions.length)
          .toList();
      setState(() {
        _questions.addAll(accepted);
        if (accepted.isEmpty) _error = '这段资料暂未生成可核对的题目';
      });
    } catch (failure) {
      if (mounted) {
        setState(() =>
            _error = extractServerMessage(failure, fallback: '暂未生成题目，请重试'));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _editQuestion([int? index]) async {
    final question = await showDialog<StudyQuestion>(
      context: context,
      builder: (_) => StudyQuestionEditor(
        notes: _notes.text.trim(),
        question: index == null ? null : _questions[index],
        allowJournal: _subject == StudySubject.accounting,
      ),
    );
    if (question == null || !mounted) return;
    setState(() {
      _error = null;
      if (index == null) {
        _questions.add(question);
      } else {
        _questions[index] = question;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _reading || _generating) return;
    final title = _title.text.trim(), notes = _notes.text.trim();
    if (title.isEmpty || notes.isEmpty) {
      setState(() => _error = '请填写考点标题和资料原文');
      return;
    }
    for (final question in _questions) {
      final issue = question.validate(notes);
      if (issue != null) {
        setState(() => _error = issue);
        return;
      }
    }
    final previous = widget.card;
    final page = widget.sourcePage;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.workspace.saveCard(StudyCard(
        id: previous?.id ?? const Uuid().v4(),
        subject: _subject,
        title: title,
        reference: _reference.text.trim(),
        notes: notes,
        questions: [
          for (final question in _questions)
            if (page != null && question.questionPage == null)
              StudyQuestion(
                  kind: question.kind,
                  prompt: question.prompt,
                  answer: question.answer,
                  source: question.source,
                  options: question.options,
                  answerParts: question.answerParts,
                  questionPage: page,
                  answerPage: question.answerPage)
            else
              question,
        ],
        level: previous?.level ?? 0,
        attempts: previous?.attempts ?? 0,
        dueOn: previous?.dueOn,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (failure) {
      if (mounted) {
        setState(() {
          _error = extractServerMessage(failure, fallback: '保存失败，填写内容已保留');
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _reading || _saving || _generating;
    final account = widget.workspace.account;
    final page = widget.sourcePage;
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.card == null ? '录入考点' : '编辑考点'), actions: [
        if (page != null && account != null)
          IconButton(
              onPressed: () => openStudyPage(context, page, account),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: '讲义原页'),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          DropdownButtonFormField<StudySubject>(
            value: _subject,
            decoration: const InputDecoration(labelText: '科目'),
            items: [
              for (final subject in StudySubject.values)
                DropdownMenuItem(value: subject, child: Text(subject.label))
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) setState(() => _subject = value);
                  },
          ),
          TextField(
              controller: _title,
              enabled: !busy,
              maxLength: 120,
              decoration:
                  const InputDecoration(labelText: '考点标题', counterText: '')),
          TextField(
              controller: _reference,
              enabled: !busy,
              maxLength: 200,
              decoration:
                  const InputDecoration(labelText: '讲义名称或页码', counterText: '')),
          if (Platform.isAndroid)
            OutlinedButton.icon(
                onPressed: busy ? null : _scan,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(_reading ? '正在识别讲义…' : '从相册选讲义')),
          if (_photo case final path?)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('核对原图'),
              children: [Image.file(File(path), cacheWidth: 1000)],
            ),
          TextField(
              controller: _notes,
              enabled: !busy,
              minLines: 5,
              maxLines: 12,
              maxLength: 12000,
              decoration:
                  const InputDecoration(labelText: '资料原文', counterText: '')),
          const SizedBox(height: 12),
          Text('练习题', style: Theme.of(context).textTheme.titleLarge),
          // Notes without practice questions can still be saved as an unfinished card.
          for (var i = 0; i < _questions.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_questions[i].prompt),
              subtitle: Text(_questions[i].kind.label),
              onTap: busy ? null : () => _editQuestion(i),
              trailing: IconButton(
                  tooltip: '移除这道题',
                  icon: const Icon(Icons.close),
                  onPressed: busy
                      ? null
                      : () => setState(() => _questions.removeAt(i))),
            ),
          if (_questions.length < 6)
            Wrap(spacing: 8, children: [
              OutlinedButton(
                  onPressed: busy ? null : _draft, child: const Text('从原文起草')),
              if (widget.workspace.aiAvailable)
                OutlinedButton(
                    onPressed: busy ? null : _aiDraft,
                    child: Text(_generating ? '正在起草…' : 'AI 起草')),
              TextButton(
                  onPressed: busy ? null : _editQuestion,
                  child: const Text('添加题目')),
            ]),
          if (_error case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                  liveRegion: true,
                  child: Text(message,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            ),
          FilledButton(
              onPressed: busy ? null : _save,
              style: rebuildFilledStyle(context),
              child: Text(_saving ? '正在保存…' : '保存考点')),
        ],
      ),
    );
  }
}

class StudyQuestionEditor extends StatefulWidget {
  const StudyQuestionEditor(
      {super.key,
      required this.notes,
      this.question,
      this.sourceActions = const [],
      required this.allowJournal});
  final String notes;
  final StudyQuestion? question;
  final List<Widget> sourceActions;
  final bool allowJournal;

  @override
  State<StudyQuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<StudyQuestionEditor> {
  late StudyQuestionKind _kind =
      widget.question?.kind ?? StudyQuestionKind.recall;
  late final _prompt = TextEditingController(text: widget.question?.prompt);
  late final _answer = TextEditingController(
      text: widget.question?.kind == StudyQuestionKind.multiBlank
          ? widget.question!.answerParts.join('\n')
          : widget.question?.answer);
  late final _source = TextEditingController(text: widget.question?.source);
  late final _options = List.generate(4, (i) {
    final options = widget.question?.options ?? [];
    return TextEditingController(text: options.length > i ? options[i] : null);
  });
  late int _correct =
      widget.question?.options.indexOf(widget.question!.answer) ?? -1;
  late final Set<int> _selected = {
    for (var i = 0; i < (widget.question?.options.length ?? 0); i++)
      if (widget.question!.answerParts.contains(widget.question!.options[i])) i,
  };
  String? _problem;

  @override
  void dispose() {
    for (final field in [_prompt, _answer, _source, ..._options]) {
      field.dispose();
    }
    super.dispose();
  }

  void _finish() {
    final options = _kind == StudyQuestionKind.choice ||
            _kind == StudyQuestionKind.multiChoice
        ? _options.map((option) => option.text.trim()).toList()
        : const <String>[];
    final parts = switch (_kind) {
      StudyQuestionKind.multiChoice => [
          for (var i = 0; i < options.length; i++)
            if (_selected.contains(i)) options[i]
        ],
      StudyQuestionKind.multiBlank =>
        _answer.text.trim().split('\n').map((line) => line.trim()).toList(),
      _ => const <String>[],
    };
    final answer = _kind == StudyQuestionKind.multiChoice
        ? parts.join('、')
        : options.isEmpty
            ? _answer.text.trim()
            : _correct < 0
                ? ''
                : options[_correct];
    final result = StudyQuestion(
      kind: _kind,
      prompt: _prompt.text.trim(),
      source: _source.text.trim(),
      answer: answer,
      options: options,
      answerParts: parts,
      questionPage: widget.question?.questionPage,
      answerPage:
          widget.question?.answer == answer && widget.question?.kind == _kind
              ? widget.question?.answerPage
              : null,
    );
    final error = result.validate(widget.notes);
    if (error == null) {
      Navigator.pop(context, result);
    } else {
      setState(() => _problem = error);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('核对题目'),
        scrollable: true,
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<StudyQuestionKind>(
              value: _kind,
              decoration: const InputDecoration(labelText: '题型'),
              items: [
                for (final kind in StudyQuestionKind.values)
                  if (kind != StudyQuestionKind.journal ||
                      widget.allowJournal ||
                      _kind == kind)
                    DropdownMenuItem(value: kind, child: Text(kind.label))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _kind = value;
                    _problem = null;
                  });
                }
              },
            ),
            TextField(
                controller: _prompt,
                maxLength: 700,
                maxLines: 3,
                minLines: 1,
                decoration:
                    const InputDecoration(labelText: '题目', counterText: '')),
            if (_kind == StudyQuestionKind.choice ||
                _kind == StudyQuestionKind.multiChoice) ...[
              for (var i = 0; i < _options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_kind == StudyQuestionKind.multiChoice)
                          Checkbox(
                              value: _selected.contains(i),
                              onChanged: (checked) => setState(() {
                                    if (checked == true) {
                                      _selected.add(i);
                                    } else {
                                      _selected.remove(i);
                                    }
                                  }))
                        else
                          Radio<int>(
                              value: i,
                              groupValue: _correct,
                              onChanged: (value) =>
                                  setState(() => _correct = value!)),
                        Expanded(
                            child: TextField(
                                controller: _options[i],
                                maxLength: 260,
                                minLines: 1,
                                maxLines: null,
                                decoration: InputDecoration(
                                    labelText: '选项 ${i + 1}',
                                    counterText: ''))),
                      ]),
                ),
            ] else
              TextField(
                  controller: _answer,
                  maxLines: 5,
                  minLines: 2,
                  maxLength: 2400,
                  decoration: InputDecoration(
                      labelText: '参考答案',
                      counterText: '',
                      hintText: _kind == StudyQuestionKind.journal
                          ? '分三行填写借方科目、贷方科目、金额'
                          : _kind == StudyQuestionKind.multiBlank
                              ? '每个空的答案填一行'
                              : null)),
            TextField(
                controller: _source,
                maxLines: 5,
                minLines: 2,
                maxLength: 2400,
                decoration:
                    const InputDecoration(labelText: '出处', counterText: '')),
            if (widget.sourceActions.isNotEmpty)
              Wrap(children: widget.sourceActions),
            if (_problem case final message?) Text(message),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: _finish, child: const Text('确认题目')),
        ],
      );
}
