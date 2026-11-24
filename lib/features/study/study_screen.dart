import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import 'study_book_theme.dart';
import 'study_editor.dart';
import 'study_lesson.dart';
import 'study_pdf.dart';
import 'study_pdf_import.dart';
import 'study_review.dart';
import 'study_workspace.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  static const _shareTag = 'LoveGirl-考点-1\n';
  StudySubject? _subject;
  bool _showNeedsReview = false;
  String? _lastOpened;

  void _edit(StudyWorkspace workspace, [StudyCard? card]) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) =>
          StudyBookTheme(child: StudyEditor(workspace: workspace, card: card)),
    ));
  }

  Future<void> _add(StudyWorkspace workspace) async {
    if (!StudyPdf.available || workspace.account == null) {
      _edit(workspace);
      return;
    }
    final picked = await showModalBottomSheet<bool>(
        context: context,
        builder: (sheet) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: const Text('导入 PDF'),
                  onTap: () => Navigator.pop(sheet, true)),
              ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('录入笔记'),
                  onTap: () => Navigator.pop(sheet, false)),
            ])));
    if (!mounted || picked == null) return;
    if (!picked) {
      _edit(workspace);
      return;
    }
    final count = await Navigator.push<int>(
        context,
        MaterialPageRoute(
            builder: (_) => StudyBookTheme(
                child: StudyPdfImport(
                    workspace: workspace,
                    subject: _subject ?? StudySubject.politics))));
    if (mounted && count != null) {
      _notice(count == 0 ? '这些题已经在备考里' : '已导入 $count 道题');
    }
  }

  void _review(StudyWorkspace workspace, List<StudyCard> cards) {
    if (cards.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StudyReview(workspace: workspace, cards: cards),
    ));
  }

  void _read(StudyWorkspace workspace, StudyCard card) {
    setState(() => _lastOpened = card.id);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StudyLesson(workspace: workspace, lesson: card),
    ));
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _copy(StudyCard card) async {
    final portable = card.copied().toJson();
    await Clipboard.setData(
        ClipboardData(text: _shareTag + jsonEncode(portable)));
    if (mounted) _notice('已复制考点和题目');
  }

  Future<void> _import(StudyWorkspace workspace) async {
    try {
      final value = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
      if (!mounted) return;
      if (!value.startsWith(_shareTag) || value.length > 60000) {
        _notice('请先复制对方发来的考点');
        return;
      }
      final card = StudyCard.fromJson(Map<String, dynamic>.from(
        jsonDecode(value.substring(_shareTag.length)) as Map,
      )).copied();
      if (card.questions.length > 6 || card.notes.length > 12000) {
        _notice('考点内容过长，请分段发送');
        return;
      }
      _edit(workspace, card);
    } catch (_) {
      if (mounted) _notice('剪贴板里的考点无法识别');
    }
  }

  Future<void> _remove(StudyWorkspace workspace, StudyCard card) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('删除考点'),
              content: Text('将删除「${card.title}」的题目和复习记录。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('删除')),
              ],
            ));
    if (confirm != true || !mounted) return;
    try {
      await workspace.removeCard(card.id);
    } catch (failure) {
      if (mounted) _notice(extractServerMessage(failure));
    }
  }

  Future<void> _toggleToday(StudyWorkspace workspace, bool enabled) async {
    try {
      await workspace.saveTodayPreference(enabled);
    } catch (failure) {
      if (mounted) _notice(extractServerMessage(failure));
    }
  }

  @override
  Widget build(BuildContext context) =>
      StudyBookTheme(child: Builder(builder: _buildBook));

  Widget _buildBook(BuildContext context) {
    final workspace = context.watch<StudyWorkspace>();
    final lessons = workspace.cards
        .where((card) => _subject == null || _subject == card.subject)
        .toList();
    final selected = _showNeedsReview
        ? lessons.where((card) => card.attempts > 0 && card.level == 0)
        : lessons;
    final due = workspace.due(DateTime.now(), _subject);
    final last = lessons.where((card) => card.id == _lastOpened).firstOrNull;
    final featured = last ?? lessons.firstOrNull;
    final editable = workspace.ready && !workspace.loading && !workspace.saving;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final excerpt = featured?.notes.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Scaffold(
      appBar: AppBar(title: const Text('专升本备考'), actions: [
        PopupMenuButton<String>(
          tooltip: '备考工具',
          enabled: editable,
          onSelected: (value) {
            if (value == 'import') _import(workspace);
            if (value == 'today') {
              _toggleToday(workspace, !workspace.showOnToday);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'import', child: Text('粘贴分享的考点')),
            PopupMenuItem(
                value: 'today',
                child: Text(workspace.showOnToday ? '从今天收起复习' : '在今天显示复习')),
          ],
        ),
      ]),
      body: RefreshIndicator(
          onRefresh: workspace.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Divider(height: 1, color: colors.primary),
              if (workspace.loading || workspace.saving)
                const LinearProgressIndicator(),
              if (workspace.error case final error?)
                ListTile(
                    title: Text(error),
                    trailing: TextButton(
                        onPressed: workspace.load, child: const Text('重试'))),
              if (workspace.ready) ...[
                if (featured != null || workspace.cards.isEmpty) ...[
                  const SizedBox(height: 24),
                  if (featured != null) ...[
                    Text(featured.subject.label,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    featured?.title.replaceFirst(' · ', '\n') ?? '添加第一份讲义',
                    style:
                        theme.textTheme.headlineMedium?.copyWith(height: 1.25),
                  ),
                  if (excerpt != null && excerpt.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsetsDirectional.only(start: 12),
                      decoration: BoxDecoration(
                          border: BorderDirectional(
                              start:
                                  BorderSide(color: colors.primary, width: 2))),
                      child: Text(excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: studySerif(theme.textTheme.bodyLarge)
                              .copyWith(height: 1.55)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton.icon(
                      onPressed: !editable
                          ? null
                          : featured == null
                              ? () => _add(workspace)
                              : () => _read(workspace, featured),
                      icon: Icon(
                          featured == null ? Icons.add : Icons.bookmark_border),
                      label: Text(featured == null
                          ? '导入资料'
                          : last == null
                              ? '开始阅读'
                              : '继续阅读'),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                if (due.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('今日复习',
                        style: studySerif(theme.textTheme.titleMedium)),
                    subtitle: Text('${due.length} 个考点待练习'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: editable ? () => _review(workspace, due) : null,
                  ),
                ],
                if (workspace.cards.isNotEmpty) ...[
                  const Divider(height: 1),
                  Row(children: [
                    Expanded(
                        child: Text('章节目录', style: theme.textTheme.titleLarge)),
                    TextButton.icon(
                        onPressed: editable ? () => _add(workspace) : null,
                        icon: const Icon(Icons.add),
                        label: const Text('添加资料')),
                  ]),
                ] else
                  const SizedBox(height: 12),
                Wrap(spacing: 6, children: [
                  for (final subject in <StudySubject?>[
                    null,
                    ...StudySubject.values
                  ])
                    Semantics(
                      selected: _subject == subject,
                      child: TextButton(
                        onPressed: () => setState(() => _subject = subject),
                        style: TextButton.styleFrom(
                          foregroundColor: _subject == subject
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(subject?.label ?? '全部',
                            style: _subject == subject
                                ? const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  )
                                : null),
                      ),
                    ),
                  if (workspace.cards.isNotEmpty)
                    FilterChip(
                        label: const Text('需要重练'),
                        selected: _showNeedsReview,
                        onSelected: (value) =>
                            setState(() => _showNeedsReview = value)),
                ]),
                if (selected.isEmpty && workspace.cards.isNotEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text('这里暂时没有考点')),
                for (final card in selected) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.title,
                        style: studySerif(theme.textTheme.titleMedium)),
                    subtitle: Text(
                        '${card.subject.label} · ${card.questions.isEmpty ? '讲义' : '${card.questions.length} 道习题'}',
                        style: TextStyle(color: colors.onSurfaceVariant)),
                    onTap: () => _read(workspace, card),
                    trailing: PopupMenuButton<String>(
                      tooltip: '管理${card.title}',
                      enabled: editable,
                      onSelected: (action) {
                        if (action == 'edit') _edit(workspace, card);
                        if (action == 'share') _copy(card);
                        if (action == 'remove') _remove(workspace, card);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑考点')),
                        PopupMenuItem(value: 'share', child: Text('复制分享考点')),
                        PopupMenuItem(value: 'remove', child: Text('删除考点')),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ],
            ],
          )),
    );
  }
}
