import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'study_editor.dart';
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

  void _edit(StudyWorkspace workspace, [StudyCard? card]) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StudyEditor(workspace: workspace, card: card),
    ));
  }

  void _review(StudyWorkspace workspace, List<StudyCard> cards) {
    if (cards.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StudyReview(workspace: workspace, cards: cards),
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
  Widget build(BuildContext context) {
    final workspace = context.watch<StudyWorkspace>();
    final selected = workspace.cards
        .where((card) =>
            (_subject == null || _subject == card.subject) &&
            (!_showNeedsReview || (card.attempts > 0 && card.level == 0)))
        .toList();
    final due = workspace.due(DateTime.now(), _subject);
    final editable = workspace.ready && !workspace.loading && !workspace.saving;
    return Scaffold(
      appBar: AppBar(title: const Text('专升本备考'), actions: [
        IconButton(
          tooltip: '录入考点',
          onPressed: editable ? () => _edit(workspace) : null,
          icon: const Icon(Icons.note_add_outlined),
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              if (workspace.loading || workspace.saving)
                const LinearProgressIndicator(),
              if (workspace.error case final error?)
                ListTile(
                    title: Text(error),
                    trailing: TextButton(
                        onPressed: workspace.load, child: const Text('重试'))),
              if (workspace.ready) ...[
                const Text('广东普通专升本 · 会计方向'),
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [
                  ChoiceChip(
                      label: const Text('全部'),
                      selected: _subject == null,
                      onSelected: (_) => setState(() => _subject = null)),
                  for (final subject in StudySubject.values)
                    ChoiceChip(
                        label: Text(subject.label),
                        selected: _subject == subject,
                        onSelected: (_) => setState(() => _subject = subject)),
                ]),
                const SizedBox(height: 12),
                RebuildGlass(
                  radius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            due.isEmpty
                                ? (workspace.cards.isEmpty
                                    ? '录入第一个考点'
                                    : '今天的复习已安排好')
                                : '今天有 ${due.length} 个考点待练习',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        if (due.isNotEmpty)
                          FilledButton(
                              onPressed: editable
                                  ? () => _review(workspace, due)
                                  : null,
                              child: const Text('开始今日复习'))
                        else if (workspace.cards.isEmpty)
                          FilledButton(
                              onPressed:
                                  editable ? () => _edit(workspace) : null,
                              child: const Text('拍讲义或粘贴笔记'))
                        else
                          const Text('可以从下面选一个考点再练一遍'),
                      ]),
                ),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(
                      child: Text('考点',
                          style: Theme.of(context).textTheme.titleLarge)),
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
                for (final card in selected)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.title),
                    subtitle: Text(
                        '${card.subject.label} · ${card.questions.isEmpty ? '待配题' : card.dueOn == null ? '可以现在练' : '下次复习 ${card.dueOn}'}',
                        style: TextStyle(color: context.lgTextSecondary)),
                    onTap: !editable
                        ? null
                        : card.questions.isEmpty
                            ? () => _edit(workspace, card)
                            : () => _review(workspace, [card]),
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
              ],
            ],
          )),
    );
  }
}
