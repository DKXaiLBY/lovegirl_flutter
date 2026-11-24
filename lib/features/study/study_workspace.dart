import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../services/api_service.dart';

enum StudySubject {
  politics('政治理论'),
  management('管理学'),
  accounting('基础会计学');

  const StudySubject(this.label);
  final String label;
}

enum StudyQuestionKind {
  recall('回忆要点'),
  choice('单选'),
  multiChoice('多选'),
  blank('填空'),
  multiBlank('多空填空'),
  journal('会计分录');

  const StudyQuestionKind(this.label);
  final String label;
}

class StudyPageReference {
  const StudyPageReference(this.documentId, this.name, this.page);

  final String documentId;
  final String name;
  final int page;

  String get label => '$name · PDF 第 $page 页';

  factory StudyPageReference.fromJson(Map<String, dynamic> json) =>
      StudyPageReference(json['documentId'] as String, json['name'] as String,
          (json['page'] as num).toInt());

  Map<String, dynamic> toJson() => {
        'documentId': documentId,
        'name': name,
        'page': page,
      };
}

class StudyQuestion {
  const StudyQuestion({
    required this.kind,
    required this.prompt,
    required this.answer,
    required this.source,
    this.options = const [],
    this.answerParts = const [],
    this.questionPage,
    this.answerPage,
  });

  final StudyQuestionKind kind;
  final String prompt;
  final String answer;
  final String source;
  final List<String> options;
  final List<String> answerParts;
  final StudyPageReference? questionPage;
  final StudyPageReference? answerPage;

  static StudyPageReference? _page(dynamic value) => value is Map
      ? StudyPageReference.fromJson(Map<String, dynamic>.from(value))
      : null;

  factory StudyQuestion.fromJson(Map<String, dynamic> json) => StudyQuestion(
        kind: StudyQuestionKind.values.byName(json['kind'] as String),
        prompt: json['prompt'] as String,
        answer: json['answer'] as String,
        source: json['source'] as String,
        options: (json['options'] as List).cast<String>(),
        answerParts: (json['answerParts'] as List?)?.cast<String>() ?? const [],
        questionPage: _page(json['questionPage']),
        answerPage: _page(json['answerPage']),
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'prompt': prompt,
        'answer': answer,
        'source': source,
        'options': options,
        if (answerParts.isNotEmpty) 'answerParts': answerParts,
        if (questionPage != null) 'questionPage': questionPage!.toJson(),
        if (answerPage != null) 'answerPage': answerPage!.toJson(),
      };

  bool checkMultiChoice(Set<String> selected) =>
      selected.length == answerParts.length &&
      selected.containsAll(answerParts);

  bool checkMultiBlank(List<String> entered) {
    if (entered.length != answerParts.length) return false;
    String normalized(String value) =>
        value.replaceAll(RegExp(r'[\s，。、；：！？，,.!?;:]+'), '').toLowerCase();
    return entered.asMap().entries.every((entry) =>
        normalized(entry.value) == normalized(answerParts[entry.key]));
  }

  List<String> checkJournal(List<String> inputs) {
    final expected = answer.split('\n').map((line) => line.trim()).toList();
    if (expected.length != 3 || inputs.length != 3) return const ['参照原文核对分录'];
    final expectedAmount = num.tryParse(expected[2]);
    final amount = num.tryParse(inputs[2].trim());
    return [
      if (inputs[0].trim() != expected[0]) '借方科目',
      if (inputs[1].trim() != expected[1]) '贷方科目',
      if (expectedAmount == null || amount != expectedAmount) '金额',
    ];
  }

  String? validate(String notes) {
    if (prompt.trim().isEmpty || answer.trim().isEmpty) return '请填写题目和参考答案';
    if (source.trim().isEmpty || !notes.contains(source)) {
      return '请选择或填写资料中的原文作为出处';
    }
    if ((kind == StudyQuestionKind.choice ||
            kind == StudyQuestionKind.multiChoice) &&
        (options.length != 4 ||
            options.any((option) => option.trim().isEmpty) ||
            options.toSet().length != 4 ||
            (kind == StudyQuestionKind.choice
                ? !options.contains(answer)
                : answerParts.length < 2 ||
                    answerParts.toSet().length != answerParts.length ||
                    !answerParts.every(options.contains)))) {
      return '请填写四个不同的选项并选择正确答案';
    }
    if (kind == StudyQuestionKind.multiBlank &&
        (answerParts.length < 2 ||
            answerParts.length > 8 ||
            answerParts.any((part) => part.trim().isEmpty) ||
            RegExp(r'_{2,}').allMatches(prompt).length != answerParts.length)) {
      return '请用下划线标出每个空，并按顺序逐行填写答案';
    }
    if (kind == StudyQuestionKind.journal) {
      final parts = answer.split('\n');
      final amount = parts.length == 3 ? num.tryParse(parts[2]) : null;
      if (parts.length != 3 ||
          parts.any((part) => part.trim().isEmpty) ||
          amount == null ||
          !amount.isFinite ||
          amount <= 0) {
        return '请核对借方科目、贷方科目和金额';
      }
    }
    return null;
  }
}

String studyDay(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class StudyCard {
  const StudyCard({
    required this.id,
    required this.subject,
    required this.title,
    required this.reference,
    required this.notes,
    required this.questions,
    this.dueOn,
    this.level = 0,
    this.attempts = 0,
  });
  final String id;
  final StudySubject subject;
  final String title;
  final String reference;
  final String notes;
  final List<StudyQuestion> questions;
  final String? dueOn;
  final int level;
  final int attempts;

  bool isDue(DateTime now) =>
      questions.isNotEmpty &&
      (dueOn == null || dueOn!.compareTo(studyDay(now)) <= 0);

  StudyCard afterReview(bool recalled, DateTime now) {
    final next = recalled ? (level + 1).clamp(1, 3).toInt() : 0;
    final days = const [1, 3, 7, 14][next];
    return StudyCard(
      id: id,
      subject: subject,
      title: title,
      reference: reference,
      notes: notes,
      questions: questions,
      level: next,
      attempts: attempts + 1,
      dueOn: studyDay(DateTime(now.year, now.month, now.day + days)),
    );
  }

  StudyCard copied() => StudyCard(
      id: const Uuid().v4(),
      subject: subject,
      title: title,
      reference: reference,
      notes: notes,
      questions: questions);

  factory StudyCard.fromJson(Map<String, dynamic> json) => StudyCard(
        id: json['id'] as String,
        subject: StudySubject.values.byName(json['subject'] as String),
        title: json['title'] as String,
        reference: json['reference'] as String,
        notes: json['notes'] as String,
        questions: (json['questions'] as List)
            .map((value) =>
                StudyQuestion.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList(growable: false),
        dueOn: json['dueOn'] as String?,
        level: (json['level'] as num).toInt(),
        attempts: (json['attempts'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject.name,
        'title': title,
        'reference': reference,
        'notes': notes,
        'questions': questions.map((question) => question.toJson()).toList(),
        'dueOn': dueOn,
        'level': level,
        'attempts': attempts,
      };
}

List<StudyQuestion> draftFromNotes(String title, String notes) {
  final first = notes
      .split(RegExp(r'[。！？；\n]'))
      .map((line) => line.trim())
      .firstWhere((line) => line.length >= 8 && line.length <= 200,
          orElse: () => '');
  final excerpt = first.isNotEmpty
      ? first
      : String.fromCharCodes(notes.trim().runes.take(200));
  if (excerpt.isEmpty) return const [];
  final label = title.trim().isEmpty ? '这个考点' : '「${title.trim()}」';
  final split = RegExp(r'[：:，、]').firstMatch(excerpt);
  return [
    StudyQuestion(
        kind: StudyQuestionKind.recall,
        prompt: '请回忆$label 的要点。',
        answer: excerpt,
        source: excerpt),
    if (split != null && split.start >= 2 && split.end + 3 < excerpt.length)
      StudyQuestion(
          kind: StudyQuestionKind.blank,
          prompt: '${excerpt.substring(0, split.end)}________',
          answer: excerpt.substring(split.end).trim(),
          source: excerpt),
  ];
}

class StudyWorkspace extends ChangeNotifier {
  StudyWorkspace(this.account, {ApiService? api}) : _api = api ?? ApiService();
  final int? account;
  final ApiService _api;
  int? _revision;
  bool _disposed = false;
  bool loading = false;
  bool saving = false;
  String? error;
  bool showOnToday = false;
  bool aiAvailable = false;
  List<StudyCard> cards = const [];

  bool get ready => _revision != null;
  List<StudyCard> due(DateTime now, [StudySubject? subject]) => cards
      .where((card) =>
          (subject == null || subject == card.subject) &&
          card.dueOn != null &&
          card.isDue(now))
      .toList(growable: false);

  Future<void> load() async {
    if (account == null || loading || saving || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _api.get('/api/study', query: {'schema': 2});
      final data = response.data['data'] as Map;
      final document = data['document'] as Map;
      final fetched = (document['cards'] as List)
          .map((value) =>
              StudyCard.fromJson(Map<String, dynamic>.from(value as Map)))
          .toList(growable: false);
      _revision = (data['revision'] as num).toInt();
      showOnToday = document['showOnToday'] == true;
      aiAvailable = data['aiAvailable'] == true;
      cards = fetched;
    } catch (failure) {
      error = extractServerMessage(failure, fallback: '备考资料暂未读取');
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> saveCard(StudyCard card) => _save(
      [card, ...cards.where((entry) => entry.id != card.id)], showOnToday);

  Future<List<StudyQuestion>> draftQuestions(
      StudySubject subject, String source) async {
    if (_disposed || !aiAvailable || account == null) return const [];
    final response = await _api.createStudyDrafts({
      'owner': account,
      'consent': true,
      'subject': subject.name,
      'source': source,
    });
    final data = response.data['data'] as Map;
    return (data['questions'] as List)
        .map((value) =>
            StudyQuestion.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList(growable: false);
  }

  Future<int> importCards(List<StudyCard> incoming) async {
    final seen = cards.map((card) => card.id).toSet();
    final additions = incoming.where((card) => seen.add(card.id)).toList();
    if (additions.isEmpty) return 0;
    await _save([...additions, ...cards], showOnToday);
    return additions.length;
  }

  Future<void> removeCard(String id) =>
      _save(cards.where((card) => card.id != id).toList(), showOnToday);

  Future<void> saveTodayPreference(bool enabled) => _save(cards, enabled);

  Future<void> _save(List<StudyCard> next, bool show) async {
    final revision = _revision;
    if (revision == null || account == null || loading || saving || _disposed) {
      throw StateError('备考资料暂时无法保存');
    }
    saving = true;
    notifyListeners();
    try {
      final response = await _api.put('/api/study', data: {
        'owner': account,
        'schema': 2,
        'revision': revision,
        'document': {
          'cards': next.map((card) => card.toJson()).toList(),
          'showOnToday': show,
        },
      });
      _revision = (response.data['data']['revision'] as num).toInt();
      cards = List.unmodifiable(next);
      showOnToday = show;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
