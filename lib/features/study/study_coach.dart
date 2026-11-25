import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import 'study_book_theme.dart';
import 'study_pdf.dart';
import 'study_workspace.dart';

class StudyCoach extends StatefulWidget {
  const StudyCoach({
    super.key,
    required this.workspace,
    required this.card,
    this.questionIndex,
    this.selected = const [],
  });

  final StudyWorkspace workspace;
  final StudyCard card;
  final int? questionIndex;
  final List<String> selected;

  @override
  State<StudyCoach> createState() => _StudyCoachState();
}

class _StudyCoachState extends State<StudyCoach> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _turns = <({String message, Map<String, dynamic> reply})>[];
  String? _pending;
  String? _error;
  bool _web = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _latest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send(String value) async {
    final message = value.trim();
    if (message.isEmpty || _pending != null) return;
    FocusScope.of(context).unfocus();
    final web = _web;
    setState(() {
      _pending = message;
      _error = null;
      _web = false;
      _input.clear();
    });
    _latest();
    try {
      final history = [
        for (final turn in _turns.reversed.take(3).toList().reversed) ...[
          {'role': 'user', 'content': turn.message},
          {
            'role': 'assistant',
            'content': String.fromCharCodes(
                (turn.reply['answer'] as String).runes.take(900)),
          },
        ],
      ];
      final reply = await widget.workspace.askCoach(
        cardId: widget.card.id,
        message: message,
        history: history,
        questionIndex: widget.questionIndex,
        selected: widget.selected,
        web: web,
      );
      if (!mounted) return;
      setState(() {
        _turns.add((message: message, reply: reply));
        _pending = null;
      });
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        _input.text = message;
        _error = extractServerMessage(failure, fallback: 'AI 暂未回答，请重试');
        _pending = null;
        _web = web;
      });
    }
    _latest();
  }

  Widget _reply(BuildContext context, Map<String, dynamic> result) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.6);
    final quote = result['quote'] as String;
    final supplement = result['supplement'] as Map?;
    final page = result['page'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(result['answer'] as String, style: body),
        if (quote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('讲义 · $quote', style: theme.textTheme.bodySmall),
          ),
        if (page is Map && StudyPdf.available)
          TextButton(
            onPressed: () => openStudyPage(
                context,
                StudyPageReference.fromJson(Map<String, dynamic>.from(page)),
                widget.workspace.account!),
            child: Text('PDF 第 ${page['page']} 页'),
          ),
        if (supplement != null) ...[
          const SizedBox(height: 12),
          Text('网络补充', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(supplement['text'] as String, style: body),
          for (final link in (supplement['links'] as List))
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(link['url'] as String),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: Text(link['title'] as String,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
        if (result['webUnavailable'] == true) const Text('暂未查到可核对的网络来源'),
      ],
    );
  }

  Widget _question(String text, Color color) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 14, bottom: 12, left: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(14)),
          child: Text(text),
        ),
      );

  @override
  Widget build(BuildContext context) =>
      StudyBookTheme(child: Builder(builder: _buildBook));

  Widget _buildBook(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final busy = _pending != null;
    return Scaffold(
      appBar: AppBar(title: const Text('问 AI')),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                for (final turn in _turns) ...[
                  _question(turn.message, colors.primaryContainer),
                  _reply(context, turn.reply),
                ],
                if (_pending case final message?) ...[
                  _question(message, colors.primaryContainer),
                  const LinearProgressIndicator(),
                ],
                if (_turns.isEmpty && !busy && _error == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ActionChip(
                      onPressed: () => _send(widget.questionIndex == null
                          ? '用简单的话解释这个考点'
                          : '这道题为什么这么选？'),
                      label: Text(widget.questionIndex == null
                          ? '换个说法解释'
                          : '这道题为什么这么选？'),
                    ),
                  ),
              ],
            ),
          ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(error, style: TextStyle(color: colors.error)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '联网查一下',
                  isSelected: _web,
                  selectedIcon: const Icon(Icons.language),
                  icon: const Icon(Icons.language_outlined),
                  onPressed: busy ? null : () => setState(() => _web = !_web),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !busy,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                        hintText: '问个问题', counterText: ''),
                  ),
                ),
                IconButton.filled(
                  tooltip: '发送',
                  onPressed: busy ? null : () => _send(_input.text),
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
