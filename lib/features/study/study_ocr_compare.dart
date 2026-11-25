import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/rebuild_controls.dart';
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
  late final _localRows = _localText.split('\n').map(_normalized).toSet();
  late final _draft = TextEditingController(text: widget.previousText);
  final _pageView = TransformationController();
  late bool _hasDraft = widget.previousText != null;
  int _view = 0;
  bool _busy = false;
  String? _error;

  bool get _sameAccount =>
      context.read<AuthProvider?>()?.userId == widget.pdf.account;

  @override
  void dispose() {
    _pageView.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _recognize() async {
    if (_busy || !_sameAccount || !widget.workspace.ocrAvailable) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('AI 重识别'),
        content: Text('将第 ${widget.page.reference.page} 页发送到'
            '${widget.workspace.ocrProvider}。'),
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
      setState(() {
        _view = 2;
        _hasDraft = true;
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

  String _normalized(String line) => line.replaceAll(_whitespace, '');
  static final _whitespace = RegExp(r'\s+');

  Widget _original() => FutureBuilder<Uint8List?>(
        future: _preview,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snapshot.data;
          if (bytes == null) return const Center(child: Text('本机暂时无法打开原页'));
          return InteractiveViewer(
            transformationController: _pageView,
            maxScale: 4,
            child: Center(
              child: Image.memory(bytes, semanticLabel: 'PDF 原页'),
            ),
          );
        },
      );

  Widget _text(bool showAi) {
    final theme = Theme.of(context);
    if (showAi && !_hasDraft) return const SizedBox.expand();
    final differences = showAi
        ? _draft.text
            .split('\n')
            .map((line) => line.trim())
            .where(
              (line) =>
                  line.isNotEmpty && !_localRows.contains(_normalized(line)),
            )
            .toList()
        : const <String>[];
    final ink = studySerif(theme.textTheme.bodyLarge).copyWith(height: 1.65);
    return ListView(
      key: PageStorageKey(showAi ? 'study_ocr_ai' : 'study_ocr_local'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (!showAi)
          SelectableText(
            _localText.isEmpty ? '本地未识别到文字' : _localText,
            style: ink,
          )
        else ...[
          if (differences.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('AI 独有 ${differences.length} 行'),
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(differences.join('\n'), style: ink),
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
            style: ink,
            decoration: InputDecoration(
              hintText: 'AI 识别文字',
              counterText: '',
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _sourcePicker(int view, bool wide, Duration duration) {
    final sources = [if (!wide) (0, '原页'), (1, '本地'), (2, 'AI')];
    final colors = Theme.of(context).colorScheme;
    final index = sources.indexWhere((source) => source.$1 == view);
    final radius = BorderRadius.circular(12);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: radius,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(3),
                child: AnimatedAlign(
                  alignment:
                      Alignment(-1 + 2 * index / (sources.length - 1), 0),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 1 / sources.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ),
              ),
              Row(children: [
                for (final (value, label) in sources)
                  Expanded(
                    child: Semantics(
                      selected: view == value,
                      button: true,
                      child: InkWell(
                        onTap: value == 2 && !_hasDraft
                            ? null
                            : () {
                                FocusScope.of(context).unfocus();
                                setState(() => _view = value);
                              },
                        child: Center(
                          child: Text(label,
                              style: TextStyle(
                                color: view == value
                                    ? colors.onSurface
                                    : colors.onSurfaceVariant,
                                fontWeight: view == value
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              )),
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
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
    final duration = rebuildReduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 210);
    return Scaffold(
      appBar: AppBar(title: Text('第 ${page.page} 页')),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final view = wide && _view == 0 ? 1 : _view;
          final content = ClipRect(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: animation.drive(Tween(
                    begin: const Offset(.045, 0),
                    end: Offset.zero,
                  )),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(view),
                child: view == 0 ? _original() : _text(view == 2),
              ),
            ),
          );
          return Column(children: [
            _sourcePicker(view, wide, duration),
            const Divider(height: 1),
            Expanded(
              child: wide
                  ? Row(children: [
                      Expanded(child: _original()),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ])
                  : content,
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
                const Text('AI 重识别未启用')
              else if (_hasDraft && !_busy) ...[
                FilledButton(
                  onPressed: _sameAccount && _draft.text.trim().isNotEmpty
                      ? () {
                          if (_sameAccount) {
                            Navigator.pop(context, _draft.text.trim());
                          }
                        }
                      : null,
                  child: const Text('采用'),
                ),
                if (widget.previousText != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('恢复本地识别'),
                  ),
              ] else
                FilledButton(
                  onPressed: _busy ? null : _recognize,
                  child: Text(_busy ? '识别中…' : 'AI 重识别'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
