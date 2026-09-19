import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});
  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  String _filter = 'ALL';

  List<LogEntry> get _filtered {
    if (_filter == 'ALL') return LogService().logs;
    return LogService().logs.where((l) => l.level == _filter).toList();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'ERROR':
        return LoveGirlTheme.red;
      case 'WARN':
        return LoveGirlTheme.orange;
      default:
        return context.lgTextMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filtered;
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        backgroundColor: context.lgBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('开发者日志'),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: context.lgTextPrimary,
        ),
        actions: [
          // 一键复制
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: '复制全部日志',
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: LogService().exportAsText()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('日志已复制到剪贴板'), duration: Duration(seconds: 1)),
              );
            },
          ),
          // 清除日志
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清除全部日志',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  title: const Text('清除日志'),
                  content: const Text('确定清除全部开发者日志吗？此操作不可撤销。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('清除',
                            style: TextStyle(color: context.lgInk))),
                  ],
                ),
              );
              if (confirm == true) {
                await LogService().clear();
                if (!context.mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('日志已清除'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1)),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 筛选器
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: ['ALL', 'ERROR', 'WARN', 'INFO'].map((f) {
                final active = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400)),
                    selected: active,
                    selectedColor: _levelColor(f).withAlpha(30),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1),
          // 日志列表
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text('暂无日志',
                        style: TextStyle(color: context.lgTextMuted)))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, i) {
                      final entry = logs[i];
                      return InkWell(
                        onTap: () => _showDetail(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color:
                                        context.lgSeparator.withAlpha(80),
                                    width: 0.5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 6, right: 8),
                                decoration: BoxDecoration(
                                  color: _levelColor(entry.level),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(entry.type,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: _levelColor(entry.level),
                                                fontWeight: FontWeight.w600)),
                                        SizedBox(width: 8),
                                        Text(
                                          '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: context.lgTextMuted),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 2),
                                    Text(entry.message,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: context.lgTextPrimary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDetail(LogEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.lgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: _levelColor(entry.level).withAlpha(20),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(entry.level,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _levelColor(entry.level))),
                ),
                SizedBox(width: 8),
                Text(entry.type,
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextMuted)),
                Spacer(),
                Text(entry.timestamp.toString().substring(0, 19),
                    style: TextStyle(
                        fontSize: 12, color: context.lgTextMuted)),
              ],
            ),
            SizedBox(height: 12),
            Text(entry.message,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.lgTextPrimary)),
            if (entry.detail.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: context.lgBg,
                    borderRadius: BorderRadius.circular(8)),
                child: SelectableText(entry.detail,
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: context.lgTextSecondary)),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
