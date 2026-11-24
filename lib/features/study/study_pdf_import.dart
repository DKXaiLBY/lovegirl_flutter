import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../services/api_service.dart';
import '../../widgets/rebuild_controls.dart';
import 'study_editor.dart';
import 'study_pdf.dart';
import 'study_pdf_questions.dart';
import 'study_workspace.dart';

typedef _Selection = ({StudyPdfDocument document, int first, int last});

class StudyPdfImport extends StatefulWidget {
  const StudyPdfImport(
      {super.key, required this.workspace, required this.subject});

  final StudyWorkspace workspace;
  final StudySubject subject;

  @override
  State<StudyPdfImport> createState() => _StudyPdfImportState();
}

class _StudyPdfImportState extends State<StudyPdfImport> {
  late final _pdf = StudyPdf(widget.workspace.account!);
  late StudySubject _subject = widget.subject;
  final _chapter = TextEditingController();
  bool _lecture = false;
  bool _busy = false;
  bool _forceOcr = false;
  _Selection? _questions;
  _Selection? _answers;
  List<StudyPdfText> _pages = [];
  List<ImportedStudyQuestion> _candidates = [];
  final _checked = <ImportedStudyQuestion, StudyCard>{};
  final _reviewed = <ImportedStudyQuestion, StudyCard>{};
  String? _message;

  @override
  void dispose() {
    _chapter.dispose();
    super.dispose();
  }

  void _clearResult() {
    _pages = [];
    _candidates = [];
    _checked.clear();
    _reviewed.clear();
    _message = null;
  }

  Future<void> _select(bool answers, {StudyPdfDocument? sameFile}) async {
    try {
      final document = sameFile ?? await _pdf.pick();
      if (!mounted || document == null) return;
      final previous = answers ? _answers : _questions;
      final range = await showDialog<_Selection>(
          context: context,
          builder: (_) => _RangeDialog(
              document: document,
              previous:
                  previous?.document.id == document.id ? previous : null));
      if (!mounted || range == null) return;
      setState(() {
        if (answers) {
          _answers = range;
        } else {
          _questions = range;
        }
        _clearResult();
      });
    } catch (failure) {
      if (mounted) {
        setState(() =>
            _message = extractServerMessage(failure, fallback: '暂时无法打开文件'));
      }
    }
  }

  Future<void> _read() async {
    final paper = _questions, key = _lecture ? null : _answers;
    if (_busy || paper == null) return;
    FocusScope.of(context).unfocus();
    final chapter = _chapter.text.trim();
    setState(() {
      _busy = true;
      _clearResult();
    });
    try {
      final pages = await _pdf.read(paper.document, paper.first, paper.last,
          forceOcr: _forceOcr);
      if (!mounted) return;
      final answers = key == null
          ? const <StudyPdfText>[]
          : await _pdf.read(key.document, key.first, key.last,
              forceOcr: _forceOcr, answerGrid: true);
      if (!mounted) return;
      final candidates = _lecture
          ? const <ImportedStudyQuestion>[]
          : matchStudyPdfQuestions(pages, answers,
              chapter: chapter.isEmpty ? '选定章节' : chapter);
      setState(() {
        _candidates = candidates;
        _pages = pages
            .where((page) => page.rows.any((row) => row.trim().isNotEmpty))
            .toList();
        if (_pages.isEmpty) {
          _message = '这几页没有识别到文字';
        } else if (!_lecture && candidates.isEmpty) {
          _message = '这几页没有识别到可配对的题目，可以直接选一页录入';
        }
      });
    } catch (failure) {
      if (mounted) {
        setState(() => _message =
            extractServerMessage(failure, fallback: '读取失败，请核对文件或页码'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check(ImportedStudyQuestion candidate) async {
    final answerSelection = _answers;
    final answerPage = candidate.answerPage ??
        (answerSelection != null &&
                answerSelection.first == answerSelection.last
            ? answerSelection.document.page(answerSelection.first)
            : null);
    final edited = await showDialog<StudyQuestion>(
        context: context,
        builder: (context) => StudyQuestionEditor(
            notes: candidate.source,
            question: _reviewed[candidate]?.questions.single ?? candidate.draft,
            sourceActions: [
              TextButton(
                  onPressed: () =>
                      openStudyPage(context, candidate.page, _pdf.account),
                  child: const Text('试题原页')),
              if (answerPage != null)
                TextButton(
                    onPressed: () =>
                        openStudyPage(context, answerPage, _pdf.account),
                    child: const Text('答案原页')),
            ],
            allowJournal: _subject == StudySubject.accounting));
    if (edited == null || !mounted) return;
    final card = candidate.toCard(_subject, edited);
    if (card == null) return;
    setState(() {
      _checked[candidate] = card;
      _reviewed[candidate] = card;
      _message = null;
    });
  }

  Future<void> _save() async {
    if (_busy || _checked.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final count =
          await widget.workspace.importCards(_checked.values.toList());
      if (!mounted) return;
      Navigator.pop(context, count);
    } catch (failure) {
      if (!mounted) return;
      setState(() => _message =
          extractServerMessage(failure, fallback: '暂时无法保存，选中的题目已保留'));
      await widget.workspace.load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _makeNote(StudyPdfText page) {
    final raw = page.rows.join('\n').trim();
    final notes = raw.length > 12000 ? raw.substring(0, 12000) : raw;
    if (notes.isEmpty) return;
    final heading = _chapter.text.trim();
    final title = heading.isEmpty ? 'PDF 第 ${page.reference.page} 页' : heading;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => StudyEditor(
                  workspace: widget.workspace,
                  sourcePage: page.reference,
                  card: StudyCard(
                      id: const Uuid().v4(),
                      subject: _subject,
                      title: title,
                      reference: page.reference.label,
                      notes: notes,
                      questions: const []),
                )));
  }

  Widget _fileTile(String label, _Selection? file, {required bool answer}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _select(answer),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(label)),
          if (file != null)
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(file.document.name),
                subtitle: Text('第 ${file.first}–${file.last} 页'),
                trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '取消选择',
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              if (answer) {
                                _answers = null;
                              } else {
                                _questions = null;
                              }
                              _clearResult();
                            })),
                onTap: _busy
                    ? null
                    : () => _select(answer, sameFile: file.document)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final prefilled = {
      for (final question in _candidates)
        if ((_reviewed[question] ?? question.toCard(_subject)) case final card?)
          question: card,
    };
    final questions = _questions;
    return Scaffold(
      appBar: AppBar(title: const Text('导入 PDF')),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('试题')),
                  ButtonSegment(value: true, label: Text('讲义')),
                ],
                selected: {
                  _lecture
                },
                onSelectionChanged: _busy
                    ? null
                    : (values) => setState(() {
                          _lecture = values.single;
                          _clearResult();
                        })),
            const SizedBox(height: 10),
            DropdownButtonFormField<StudySubject>(
                value: _subject,
                decoration: const InputDecoration(labelText: '科目'),
                items: [
                  for (final subject in StudySubject.values)
                    DropdownMenuItem(value: subject, child: Text(subject.label))
                ],
                onChanged: _busy
                    ? null
                    : (subject) {
                        if (subject != null) {
                          setState(() {
                            _subject = subject;
                            _checked.clear();
                            _reviewed.clear();
                          });
                        }
                      }),
            TextField(
                controller: _chapter,
                enabled: !_busy,
                maxLength: 80,
                decoration:
                    const InputDecoration(labelText: '章节（可选）', counterText: ''),
                onChanged: (_) => setState(_clearResult)),
            _fileTile(_lecture ? '选择讲义 PDF' : '选择试题 PDF', _questions,
                answer: false),
            if (!_lecture) ...[
              _fileTile('选择答案 PDF（可选）', _answers, answer: true),
              if (questions != null && _answers == null)
                TextButton(
                    onPressed: _busy
                        ? null
                        : () => _select(true, sameFile: questions.document),
                    child: const Text('答案在同一份 PDF')),
            ],
            if (questions != null)
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('按扫描件识字'),
                  value: _forceOcr,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                            _forceOcr = value ?? false;
                            _clearResult();
                          })),
            FilledButton(
                style: rebuildFilledStyle(context),
                onPressed: _busy || questions == null ? null : _read,
                child: Text(_busy ? '正在处理…' : '读取选中页')),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator()),
            if (_message case final message?) Text(message),
            if (_candidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('已选 ${_checked.length}/${_candidates.length} 道题'),
                    if (prefilled.isNotEmpty)
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    for (final entry in prefilled.entries) {
                                      _checked.putIfAbsent(
                                          entry.key, () => entry.value);
                                    }
                                  }),
                          child: const Text('全选已配对')),
                  ]),
              for (final candidate in _candidates)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(candidate.prompt,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${candidate.label} · ${_reviewed.containsKey(candidate) ? '已核对' : prefilled.containsKey(candidate) ? '已配对' : '待核对'}'),
                    onTap: _busy ? null : () => _check(candidate),
                    trailing: Checkbox(
                        semanticLabel: '选中 ${candidate.label}',
                        value: _checked.containsKey(candidate),
                        onChanged: _busy ||
                                !_checked.containsKey(candidate) &&
                                    !prefilled.containsKey(candidate)
                            ? null
                            : (value) {
                                setState(() {
                                  if (value == true) {
                                    _checked[candidate] = prefilled[candidate]!;
                                  } else {
                                    _checked.remove(candidate);
                                  }
                                });
                              })),
              FilledButton(
                  onPressed: _busy || _checked.isEmpty ? null : _save,
                  child: Text('导入 ${_checked.length} 道题')),
            ] else
              for (final page in _pages)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('第 ${page.reference.page} 页'),
                    subtitle: Text(
                        page.rows.firstWhere((line) => line.trim().isNotEmpty),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    onTap: _busy ? null : () => _makeNote(page),
                    trailing: IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: '查看原页',
                        onPressed: _busy
                            ? null
                            : () => openStudyPage(
                                context, page.reference, _pdf.account))),
          ]),
    );
  }
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.document, this.previous});
  final StudyPdfDocument document;
  final _Selection? previous;

  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late final _first =
      TextEditingController(text: (widget.previous?.first ?? 1).toString());
  late final _last = TextEditingController(
      text: (widget.previous?.last ?? widget.document.pages.clamp(1, 4))
          .toString());
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  void _accept() {
    final first = int.tryParse(_first.text.trim()),
        last = int.tryParse(_last.text.trim());
    if (first == null ||
        last == null ||
        first < 1 ||
        last < first ||
        last > widget.document.pages ||
        last - first >= StudyPdf.maxRange) {
      setState(() => _error =
          '页码须在 1–${widget.document.pages} 之间，每次最多 ${StudyPdf.maxRange} 页');
      return;
    }
    Navigator.pop(
        context, (document: widget.document, first: first, last: last));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('选择页码'),
          scrollable: true,
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${widget.document.name} · 共 ${widget.document.pages} 页'),
            TextField(
                controller: _first,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '起始页')),
            TextField(
                controller: _last,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '结束页')),
            if (_error case final message?) Text(message),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(onPressed: _accept, child: const Text('确定'))
          ]);
}
