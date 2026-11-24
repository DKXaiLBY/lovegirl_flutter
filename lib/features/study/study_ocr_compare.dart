import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'study_book_theme.dart';
import 'study_pdf.dart';
import 'study_workspace.dart';

class StudyOcrCompare extends StatefulWidget {
  const StudyOcrCompare({
    super.key,
    required this.page,
    required this.pdf,
    required this.workspace,
    required this.role,
    this.previousText,
  });

  final StudyPdfText page;
  final StudyPdf pdf;
  final StudyWorkspace workspace;
  final StudyOcrRole role;
  final String? previousText;

  @override
  State<StudyOcrCompare> createState() => _StudyOcrCompareState();
}

class _StudyOcrCompareState extends State<StudyOcrCompare> {
  late final _preview = widget.pdf.preview(widget.page.reference);
  late final _localText = widget.page.rows.join('\n').trim();
  late final _draft = TextEditingController(text: widget.previousText);
  late bool _hasDraft = widget.previousText != null;
  List<String> _differences = const [];
  int _view = 0;
  bool _busy = false;
  String? _error;

  bool get _sameAccount =>
      context.read<AuthProvider?>()?.userId == widget.pdf.account;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _recognize() async {
    if (_busy || !_sameAccount || !widget.workspace.ocrAvailable) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('AI 重识别当前页'),
        content: Text('只把第 ${widget.page.reference.page} 页的图片发送给'
            '${widget.workspace.ocrProvider}。核对后可选择采用识别结果。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('识别本页'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || !_sameAccount) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final image =
          await widget.pdf.preview(widget.page.reference, forOcr: true);
      if (!mounted || !_sameAccount) return;
      if (image == null) throw StateError('原页无法打开');
      final result = await widget.workspace.recognizePage(widget.role, image);
      if (!mounted || !_sameAccount) return;
      final original = _localText.split('\n').map(_normalized).toSet();
      final differences = result
          .split('\n')
          .map((line) => line.trim())
          .where((line) =>
              line.isNotEmpty && !original.contains(_normalized(line)))
          .toList(growable: false);
      setState(() {
        _view = 2;
        _hasDraft = true;
        _differences = differences;
        _draft.text = result;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = extractServerMessage(
              error,
              fallback: 'AI 暂未读出这一页，本地结果仍在',
            ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _normalized(String line) => line.replaceAll(RegExp(r'\s+'), '');

  Widget _original() => FutureBuilder<Uint8List?>(
        future: _preview,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null) return const Center(child: Text('本机暂时无法打开原页'));
          return InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: Image.memory(bytes, semanticLabel: 'PDF 原页'),
            ),
          );
        },
      );

  Widget _text(bool showAi) {
    final theme = Theme.of(context);
    return ListView(
      key: ValueKey(showAi),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!showAi)
          SelectableText(
            _localText.isEmpty ? '本地未识别到文字' : _localText,
            style: studySerif(theme.textTheme.bodyLarge).copyWith(height: 1.65),
          )
        else if (!_hasDraft)
          const Text('识别后的文字可以在这里核对和修正。')
        else ...[
          if (_differences.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('${_differences.length} 行 AI 文字与本地结果不同'),
              children: [
                for (final line in _differences.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(line,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          TextField(
            key: const ValueKey('study-ocr-draft'),
            controller: _draft,
            enabled: !_busy,
            minLines: 6,
            maxLines: null,
            maxLength: 16000,
            style: studySerif(theme.textTheme.bodyLarge).copyWith(height: 1.65),
            decoration: const InputDecoration(labelText: '校对 AI 文字'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthProvider?>()?.userId != widget.pdf.account) {
      return Scaffold(
        appBar: AppBar(title: const Text('核对识别')),
        body: const Center(child: Text('账号已切换，请重新打开备考')),
      );
    }
    final page = widget.page.reference;
    final available = widget.workspace.ocrAvailable;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('核对第 ${page.page} 页')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final view = wide && _view == 0 ? 1 : _view;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(page.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: theme.colorScheme.primaryContainer,
                selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
              ),
              segments: [
                if (!wide) const ButtonSegment(value: 0, label: Text('原页')),
                const ButtonSegment(value: 1, label: Text('本地')),
                const ButtonSegment(value: 2, label: Text('AI')),
              ],
              selected: {view},
              onSelectionChanged: (selection) =>
                  setState(() => _view = selection.single),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: wide
                  ? Row(children: [
                      Expanded(child: _original()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _text(view == 2)),
                    ])
                  : view == 0
                      ? _original()
                      : _text(view == 2),
            ),
          ]);
        }),
      ),
      bottomNavigationBar: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              if (_busy) const LinearProgressIndicator(),
              if (!available)
                const Text('云端重识别暂未启用，可继续核对本地结果。')
              else if (_hasDraft && !_busy) ...[
                FilledButton(
                  onPressed: _sameAccount && _draft.text.trim().isNotEmpty
                      ? () {
                          if (_sameAccount) {
                            Navigator.pop(context, _draft.text.trim());
                          }
                        }
                      : null,
                  child: const Text('采用校对后的文字'),
                ),
                if (widget.previousText != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('恢复本地识别'),
                  ),
              ] else
                FilledButton(
                  onPressed: _busy ? null : _recognize,
                  child: Text(_busy ? '正在识别本页…' : '用 AI 重识别本页'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
