import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/daily_provider.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/lovegirl_ui.dart';

/// 每日一问：双盲问答——两人都提交后才互相揭晓
class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<DailyProvider>().refresh();
      context.read<DailyProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(DailyProvider provider) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final err = await provider.submitAnswer(_controller.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
    } else {
      HapticFeedback.mediumImpact();
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyProvider>();
    final today = provider.today;

    return Scaffold(
      backgroundColor: context.lgBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
              child: Row(
                children: [
                  LoveIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '每日一问',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.loading && today == null
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: LoveGirlTheme.primary),
                    )
                  : provider.error != null && today == null
                      ? EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: provider.error!,
                          onRetry: () => provider.refresh(),
                        )
                      : RefreshIndicator(
                          color: LoveGirlTheme.primary,
                          onRefresh: () => provider.refresh(),
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                            children: [
                              _QuestionCard(today: today),
                              const SizedBox(height: 16),
                              if (today == null || today.myAnswer == null)
                                _AnswerInputCard(
                                  controller: _controller,
                                  submitting: _submitting,
                                  onSubmit: () => _submit(provider),
                                )
                              else if (!today.bothAnswered)
                                _WaitingCard(today: today)
                              else
                                _RevealCard(today: today),
                              const SizedBox(height: 24),
                              if (provider.history.isNotEmpty) ...[
                                LoveSectionTitle(title: '我们一起答过的'),
                                ...provider.history
                                    .map((e) => _HistoryRow(entry: e)),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 今日题目 + streak
class _QuestionCard extends StatelessWidget {
  final DailyToday? today;

  const _QuestionCard({required this.today});

  @override
  Widget build(BuildContext context) {
    final t = today;
    return LovePaper(
      color: context.lgPaperWarm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined,
                  size: 18, color: context.lgEmotion),
              const SizedBox(width: 6),
              Text(
                '今天的题目',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.lgTextSecondary,
                ),
              ),
              const Spacer(),
              if (t != null && t.streakCurrent > 0)
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 16, color: LoveGirlTheme.orange),
                    const SizedBox(width: 3),
                    Text(
                      '连续 ${t.streakCurrent} 天',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: LoveGirlTheme.orange,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t?.question ?? '正在取今天的题目…',
            style: TextStyle(
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w800,
              color: context.lgTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 未作答：输入答案
class _AnswerInputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _AnswerInputCard({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return LovePaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '写下你的答案',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.lgTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '两个人都提交后才会互相揭晓，先卖个关子。',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.lgTextMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: '想到什么写什么，没有标准答案…',
              filled: true,
              fillColor: context.lgBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.lgSeparator),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.lgSeparator),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.lgInk, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: LovePrimaryButton(
              text: submitting ? '提交中…' : '封存今天的答案',
              icon: Icons.favorite_rounded,
              onPressed: submitting ? null : onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

/// 我答了，等 TA
class _WaitingCard extends StatelessWidget {
  final DailyToday today;

  const _WaitingCard({required this.today});

  @override
  Widget build(BuildContext context) {
    return LovePaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                today.hasPartner
                    ? '等 ${today.partnerName ?? 'TA'} 揭晓…'
                    : '已封存（绑定伴侣后一起玩）',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.lgTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MyAnswerBubble(text: today.myAnswer ?? ''),
        ],
      ),
    );
  }
}

/// 双人都答完：揭晓
class _RevealCard extends StatelessWidget {
  final DailyToday today;

  const _RevealCard({required this.today});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 18, color: context.lgEmotion),
            const SizedBox(width: 6),
            Text(
              '已揭晓 · 今天也想到一起了',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.lgTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LovePaper(
          color: context.lgPaperWarm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的答案',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.lgEmotion,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                today.myAnswer ?? '',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: context.lgTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LovePaper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${today.partnerName ?? 'TA'} 的答案',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.lgTextSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                today.partnerAnswer ?? '',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: context.lgTextPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.local_fire_department_rounded,
                size: 15, color: LoveGirlTheme.orange),
            const SizedBox(width: 4),
            Text(
              '连续 ${today.streakCurrent} 天 · 最长 ${today.streakLongest} 天 · 累计 ${today.streakTotal} 天',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.lgTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MyAnswerBubble extends StatelessWidget {
  final String text;

  const _MyAnswerBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.lgBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.lgSeparator),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: context.lgTextPrimary,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final DailyHistoryEntry entry;

  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final parts = entry.date.split('-');
    final label = parts.length == 3 ? '${parts[1]}月${parts[2]}日' : entry.date;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.lgPaper,
        borderRadius: BorderRadius.circular(LoveGirlTheme.radiusLg),
        border: Border.all(color: context.lgSeparator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.lgEmotion,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.lgTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '我：${entry.myAnswer}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.4, color: context.lgTextSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            'TA：${entry.partnerAnswer}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.4, color: context.lgTextSecondary),
          ),
        ],
      ),
    );
  }
}
