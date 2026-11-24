import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'study_pdf.dart';
import 'study_workspace.dart';

typedef _QuestionKey = ({String chapter, StudyQuestionKind kind, int number});
typedef _PageAnswer = ({List<String> parts, StudyPageReference page});

final _chapter = RegExp(r'(第\s*[零〇一二三四五六七八九十\d]+\s*章|导论)');
final _numbered = RegExp(r'^\s*[（(]?(\d{1,3})\s*[.．、，,：:）)]\s*(.+)$');
final _option = RegExp(r'(?:^|\s)([A-DＡ-Ｄ])\s*[.．、，,：:）)]\s*');
final _answerPrefix = RegExp(r'^\s*[【\[]?(?:参考|正确)?答案[】\]]?\s*[：:]?\s*');
final _choiceKey = RegExp(r'(?<![A-Za-z0-9])(\d{1,3})[\s.．、）)：:]*'
    r'([A-D](?:[\s,、，/]*[A-D]){0,3})(?![A-Za-z0-9])');
final _labelsOnly = RegExp(r'^[A-D](?:[\s,、，/]*[A-D]){0,3}$');
final _blanks = RegExp(r'_{2,}|＿{2,}');
const _digits = '零一二三四五六七八九';

String _ascii(String text) => String.fromCharCodes(text.runes.map((rune) =>
    rune >= 0xff10 && rune <= 0xff19 || rune >= 0xff21 && rune <= 0xff3a
        ? rune - 0xfee0
        : rune));

String _chapterKey(String value) {
  final match = _chapter.firstMatch(value);
  if (match == null) return value.trim();
  final label = match[0]!.replaceAll(RegExp(r'\s'), '');
  if (label == '导论') return label;
  final number = label.substring(1, label.length - 1);
  final parsed = int.tryParse(number);
  if (parsed != null) return '第$parsed章';
  final tens = number.split('十');
  final normalized = tens.length == 2
      ? (tens[0].isEmpty ? 1 : _digits.indexOf(tens[0])) * 10 +
          (tens[1].isEmpty ? 0 : _digits.indexOf(tens[1]))
      : _digits.indexOf(number);
  return normalized < 0 ? label : '第$normalized章';
}

StudyQuestionKind? _kind(String content) {
  if (content.contains('多选')) return StudyQuestionKind.multiChoice;
  if (content.contains('单选')) return StudyQuestionKind.choice;
  if (content.contains('填空')) return StudyQuestionKind.blank;
  return null;
}

List<String> _letters(String text) => RegExp('[A-D]')
    .allMatches(text)
    .map((match) => match[0]!)
    .toList(growable: false);

List<String> _pageRows(StudyPdfText page) => page.rows
    .map((line) => _ascii(line.trim())
        .replaceAll(RegExp(r'(?<=[\u3400-\u9fff])\s+(?=[\u3400-\u9fff])'), ''))
    .where((line) =>
        line.isNotEmpty &&
        !RegExp(r'^(?:公众号|微信|上课APP|主讲老师|第\s*\d+\s*页\s*共|20\d{2}.{0,36}(?:精讲课|周测))')
            .hasMatch(line))
    .toList(growable: false);

String? _edition(List<StudyPdfText> pages) {
  if (pages.isEmpty) return null;
  final candidates = [
    pages.first.reference.name,
    ..._pageRows(pages.first).take(3)
  ];
  for (final value in candidates) {
    final match = RegExp(r'(?<!\d)(?:20)?(2\d)\s*(?:年\s*)?(?:mayi|专升本|专插本)',
            caseSensitive: false)
        .firstMatch(value);
    if (match != null) return '20${match[1]}';
  }
  return null;
}

class ImportedStudyQuestion {
  const ImportedStudyQuestion(
      {required this.chapter,
      required this.number,
      required this.kind,
      required this.prompt,
      required this.options,
      required this.page,
      required this.source,
      this.suggested = const [],
      this.answerPage});

  final String chapter;
  final int number;
  final StudyQuestionKind kind;
  final String prompt;
  final List<String> options;
  final StudyPageReference page;
  final String source;
  final List<String> suggested;
  final StudyPageReference? answerPage;

  bool get isChoice =>
      kind == StudyQuestionKind.choice || kind == StudyQuestionKind.multiChoice;
  String get label => '$chapter · ${kind.label} $number';

  StudyQuestion get draft => StudyQuestion(
      kind: kind,
      prompt: prompt,
      source: source,
      options: options,
      answer: suggested.join(isChoice ? '、' : '\n'),
      answerParts: kind == StudyQuestionKind.multiChoice ||
              kind == StudyQuestionKind.multiBlank
          ? suggested
          : const [],
      questionPage: page,
      answerPage: answerPage);

  StudyCard? toCard(StudySubject subject, [StudyQuestion? edited]) {
    final cleanedPrompt = prompt.replaceAll(RegExp(r'\s+'), '');
    final unique = sha256.convert(utf8.encode(
        '${subject.name}|$chapter|${kind.name}|$number|$cleanedPrompt'));
    final question = edited ?? draft;
    if (question.validate(source) != null || question.answer.length > 2400) {
      return null;
    }
    return StudyCard(
        id: 'pdf-${unique.toString().substring(0, 30)}',
        subject: subject,
        title: label.length <= 120 ? label : label.substring(0, 120),
        reference: '',
        notes: source,
        questions: [question]);
  }
}

class _QuestionDraft {
  _QuestionDraft(
      this.chapter, this.number, this.heading, this.page, String text)
      : lines = [text];
  final String chapter;
  final int number;
  final StudyQuestionKind? heading;
  final StudyPageReference page;
  final List<String> lines;
  _PageAnswer? answer;

  ImportedStudyQuestion? complete(Map<_QuestionKey, _PageAnswer?> keys) {
    final content = lines.join('\n');
    final matches = _option.allMatches(content).toList();
    final options = <String, String>{};
    for (var i = 0; i < matches.length; i++) {
      final marker = matches[i];
      final text = content
          .substring(marker.end,
              i + 1 < matches.length ? matches[i + 1].start : content.length)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (text.isEmpty || text.length > 260 || options.containsKey(marker[1])) {
        return null;
      }
      options[marker[1]!] = text;
    }
    final rawPrompt =
        (matches.isEmpty ? content : content.substring(0, matches.first.start))
            .trim();
    if (rawPrompt.isEmpty || rawPrompt.length > 700 || content.length > 2400) {
      return null;
    }
    final prompt = rawPrompt.replaceAll(_blanks, '____');
    final blankCount = _blanks.allMatches(prompt).length;
    final kind =
        options.length == 4 && 'ABCD'.split('').every(options.containsKey)
            ? heading == StudyQuestionKind.multiChoice
                ? StudyQuestionKind.multiChoice
                : StudyQuestionKind.choice
            : options.isNotEmpty
                ? null
                : blankCount > 1
                    ? StudyQuestionKind.multiBlank
                    : blankCount == 1 || heading == StudyQuestionKind.blank
                        ? StudyQuestionKind.blank
                        : null;
    if (kind == null || blankCount > 8) return null;
    final fromTable = keys[(chapter: chapter, kind: kind, number: number)] ??
        (kind == StudyQuestionKind.multiBlank
            ? keys[(
                chapter: chapter,
                kind: StudyQuestionKind.blank,
                number: number
              )]
            : null);
    final matching = answer != null &&
            fromTable != null &&
            !listEquals(answer!.parts, fromTable.parts)
        ? null
        : answer ?? fromTable;
    final raw = matching?.parts ?? const <String>[];
    final correct = options.isNotEmpty
        ? raw.map((part) => options[part] ?? '').toList()
        : raw;
    final countOk = switch (kind) {
      StudyQuestionKind.choice => correct.length == 1,
      StudyQuestionKind.multiChoice =>
        correct.length >= 2 && correct.toSet().length == correct.length,
      StudyQuestionKind.multiBlank => correct.length == blankCount,
      _ => correct.length == 1,
    };
    final confirmedParts = countOk && correct.every((part) => part.isNotEmpty)
        ? correct
        : const <String>[];
    return ImportedStudyQuestion(
        chapter: chapter,
        number: number,
        kind: kind,
        prompt: prompt,
        options: options.isEmpty
            ? const []
            : 'ABCD'.split('').map((letter) => options[letter]!).toList(),
        page: page,
        source: content,
        suggested: confirmedParts,
        answerPage: confirmedParts.isEmpty ? null : matching?.page);
  }
}

List<String> _fillParts(String text) => text
    .split(RegExp(r'[；;]'))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toList();

Map<_QuestionKey, _PageAnswer?> _answerTable(
    List<StudyPdfText> pages, String fallbackChapter) {
  final keys = <_QuestionKey, _PageAnswer?>{};
  var chapter = fallbackChapter;
  StudyQuestionKind? heading;
  for (final page in pages) {
    List<int> previous = const [];
    void add(int number, List<String> parts, StudyQuestionKind kind) {
      if (parts.isEmpty) return;
      final key = (chapter: chapter, kind: kind, number: number);
      if (keys.containsKey(key)) {
        final known = keys[key];
        if (known != null && !listEquals(known.parts, parts)) keys[key] = null;
      } else {
        keys[key] = (parts: parts, page: page.reference);
      }
    }

    for (final row in _pageRows(page)) {
      final start = _numbered.firstMatch(row);
      if (start == null && row.length < 66) {
        if (_chapter.hasMatch(row)) {
          chapter = _chapterKey(row);
          heading = null;
          previous = const [];
        }
        final type = _kind(row);
        if (type != null) {
          heading = type;
          previous = const [];
        }
      }
      if (heading == StudyQuestionKind.blank && start != null) {
        add(int.parse(start[1]!), _fillParts(start[2]!),
            StudyQuestionKind.blank);
      } else {
        for (final match in _choiceKey.allMatches(row)) {
          final parts = _letters(match[2]!);
          add(
              int.parse(match[1]!),
              parts,
              heading ??
                  (parts.length == 1
                      ? StudyQuestionKind.choice
                      : StudyQuestionKind.multiChoice));
        }
      }
      final tokens = row.split(RegExp(r'\s+'));
      if (tokens.every((token) => RegExp(r'^\d{1,3}$').hasMatch(token))) {
        previous = tokens.map(int.parse).toList();
      } else {
        if (previous.length == tokens.length &&
            tokens.every(_labelsOnly.hasMatch)) {
          for (var i = 0; i < tokens.length; i++) {
            final parts = _letters(tokens[i]);
            add(
                previous[i],
                parts,
                heading ??
                    (parts.length == 1
                        ? StudyQuestionKind.choice
                        : StudyQuestionKind.multiChoice));
          }
        }
        previous = const [];
      }
    }
  }
  return keys;
}

List<ImportedStudyQuestion> matchStudyPdfQuestions(
    List<StudyPdfText> questionPages, List<StudyPdfText> answerPages,
    {required String chapter}) {
  chapter = _chapterKey(chapter);
  final questionYear = _edition(questionPages),
      answerYear = _edition(answerPages);
  final keys =
      questionYear != null && answerYear != null && questionYear != answerYear
          ? <_QuestionKey, _PageAnswer?>{}
          : _answerTable(answerPages, chapter);
  final completed = <ImportedStudyQuestion>[];
  StudyQuestionKind? heading;
  _QuestionDraft? active;
  void finish() {
    final result = active?.complete(keys);
    if (result != null) completed.add(result);
    active = null;
  }

  for (final page in questionPages) {
    for (final row in _pageRows(page)) {
      final start = _numbered.firstMatch(row);
      if (start != null) {
        finish();
        final body = start[2]!;
        final type = _kind(body.length <= 5 ? body : body.substring(0, 5));
        final prompt = body.replaceFirst(RegExp(r'^(?:单选|多选|填空)题?\s*'), '');
        active = _QuestionDraft(chapter, int.parse(start[1]!), type ?? heading,
            page.reference, prompt);
      } else if (row.length < 65 &&
          _chapter.hasMatch(row) &&
          !_option.hasMatch(row)) {
        finish();
        chapter = _chapterKey(row);
        heading = null;
      } else if ((row.length < 28 ? _kind(row) : null) case final type?) {
        // Slides often repeat one heading per page.
        finish();
        heading = type;
      } else if (_answerPrefix.firstMatch(row) case final start?) {
        final content = row.substring(start.end).trim();
        if (active != null && content.isNotEmpty) {
          final parts = _labelsOnly.hasMatch(content)
              ? _letters(content)
              : _fillParts(content);
          active!.answer = (parts: parts, page: page.reference);
          finish();
        }
      } else {
        active?.lines.add(row);
      }
    }
  }
  finish();
  // A repeated number in the same chapter and type can belong to another practice set.
  // Keep both prompts for manual review and remove uncertain answer suggestions.
  final counts = <String, int>{};
  for (final entry in completed) {
    counts.update(entry.label, (value) => value + 1, ifAbsent: () => 1);
  }
  return completed
      .map((entry) => counts[entry.label] == 1
          ? entry
          : ImportedStudyQuestion(
              chapter: entry.chapter,
              number: entry.number,
              kind: entry.kind,
              prompt: entry.prompt,
              options: entry.options,
              page: entry.page,
              source: entry.source))
      .toList(growable: false);
}
