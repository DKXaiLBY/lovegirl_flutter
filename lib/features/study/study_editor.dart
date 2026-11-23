import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../services/api_service.dart';
import '../../widgets/rebuild_controls.dart';
import 'study_workspace.dart';

class StudyEditor extends StatefulWidget {
  const StudyEditor({super.key, required this.workspace, this.card});
  final StudyWorkspace workspace;
  final StudyCard? card;

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
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍讲义'),
              onTap: () => Navigator.pop(sheet, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('从相册选讲义'),
              onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
          source: source, maxWidth: 1900, maxHeight: 2300, imageQuality: 90);
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
        setState(() => _error = '没有读到文字，可以重拍或照着原图填写');
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
      if (mounted) setState(() => _error = '文字暂时无法识别，可以重拍或粘贴笔记');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _draft() {
    final additions = draftFromNotes(_title.text, _notes.text)
        .where((question) =>
            _questions.every((saved) => saved.prompt != question.prompt))
        .take(6 - _questions.length)
        .toList();
    setState(() {
      _questions.addAll(additions);
      _error = additions.isEmpty ? '请补充原文、编辑已有草稿，或添加一道题' : null;
    });
  }

  Future<void> _editQuestion([int? index]) async {
    final question = await showDialog<StudyQuestion>(
      context: context,
      builder: (_) => _QuestionEditor(
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
    if (_saving || _reading) return;
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
        questions: List.unmodifiable(_questions),
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
    final busy = _reading || _saving;
    return Scaffold(
      appBar: AppBar(title: Text(widget.card == null ? '录入考点' : '编辑考点')),
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
              decoration: const InputDecoration(labelText: '考点标题')),
          TextField(
              controller: _reference,
              enabled: !busy,
              maxLength: 200,
              decoration: const InputDecoration(labelText: '讲义名称或页码')),
          if (Platform.isAndroid)
            OutlinedButton.icon(
                onPressed: busy ? null : _scan,
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(_reading ? '正在识别讲义…' : '拍照识字')),
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
              decoration: const InputDecoration(
                  labelText: '资料原文', hintText: '粘贴笔记，或在这里核对识别结果')),
          const SizedBox(height: 12),
          Text('练习题', style: Theme.of(context).textTheme.titleLarge),
          const Text('保存前核对题目、答案和出处。也可以只保存考点，下次再补题。'),
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

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor(
      {required this.notes, this.question, required this.allowJournal});
  final String notes;
  final StudyQuestion? question;
  final bool allowJournal;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late StudyQuestionKind _kind =
      widget.question?.kind ?? StudyQuestionKind.recall;
  late final _prompt = TextEditingController(text: widget.question?.prompt);
  late final _answer = TextEditingController(text: widget.question?.answer);
  late final _source = TextEditingController(text: widget.question?.source);
  late final _options = List.generate(4, (i) {
    final options = widget.question?.options ?? [];
    return TextEditingController(text: options.length > i ? options[i] : null);
  });
  late int _correct =
      (widget.question?.options.indexOf(widget.question!.answer) ?? 0)
          .clamp(0, 3)
          .toInt();
  String? _problem;

  @override
  void dispose() {
    for (final field in [_prompt, _answer, _source, ..._options]) {
      field.dispose();
    }
    super.dispose();
  }

  void _finish() {
    final options = _kind == StudyQuestionKind.choice
        ? _options.map((option) => option.text.trim()).toList()
        : const <String>[];
    final result = StudyQuestion(
      kind: _kind,
      prompt: _prompt.text.trim(),
      source: _source.text.trim(),
      answer: options.isEmpty ? _answer.text.trim() : options[_correct],
      options: options,
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
                decoration: const InputDecoration(labelText: '题目')),
            if (_kind == StudyQuestionKind.choice) ...[
              for (var i = 0; i < _options.length; i++)
                Row(children: [
                  Radio<int>(
                      value: i,
                      groupValue: _correct,
                      onChanged: (value) => setState(() => _correct = value!)),
                  Expanded(
                      child: TextField(
                          controller: _options[i],
                          maxLength: 260,
                          decoration:
                              InputDecoration(labelText: '选项 ${i + 1}'))),
                ]),
            ] else
              TextField(
                  controller: _answer,
                  maxLines: 5,
                  minLines: 2,
                  maxLength: 2400,
                  decoration: InputDecoration(
                      labelText: '参考答案',
                      hintText: _kind == StudyQuestionKind.journal
                          ? '分三行填写借方科目、贷方科目、金额'
                          : null)),
            TextField(
                controller: _source,
                maxLines: 5,
                minLines: 2,
                maxLength: 2400,
                decoration: const InputDecoration(
                    labelText: '出处', hintText: '从资料原文复制对应的段落')),
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
