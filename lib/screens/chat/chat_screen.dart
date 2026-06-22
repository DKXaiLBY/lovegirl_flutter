import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() { super.initState(); _loadMessages(); }
  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _loadMessages({bool refresh = false}) async {
    if (refresh) { _page = 1; _hasMore = true; }
    if (!_hasMore && !refresh) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.getMessages(page: refresh ? 1 : _page);
      final data = res.data?['data'];
      List raw;
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data['list'] as List? ?? [];
      } else {
        raw = [];
      }
      final list = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      setState(() {
        if (refresh) { _messages = list; } else { _messages.addAll(list); }
        _hasMore = list.length >= 20;
        _page = refresh ? 2 : _page + 1;
        _loading = false;
      });
      LogService().info('Chat', '加载${list.length}条消息');
    } catch (e) {
      setState(() { _error = '加载失败'; _loading = false; });
      LogService().error('Chat', '加载失败: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.insert(0, {'content': text, 'is_mine': true, 'created_at': DateTime.now().toIso8601String(), 'id': DateTime.now().millisecondsSinceEpoch,});
      _sending = true;
    });
    _msgCtrl.clear();
    try {
      await _api.sendMessage({'content': text});
      LogService().userAction('发送消息');
      await _loadMessages(refresh: true);
    } catch (e) {
      LogService().error('Chat', '发送失败: $e');
    }
    setState(() => _sending = false);
  }

  /// 解码处理，防止乱码
  String _decode(String? text) {
    if (text == null) return '';
    try {
      // 尝试修复双重编码
      if (text.contains('Ã') || text.contains('â') || text.contains('Â')) {
        return utf8.decode(latin1.encode(text), allowMalformed: true);
      }
    } catch (_) {}
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: const Text('私密聊天'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadMessages(refresh: true))],
      ),
      body: Column(children: [
        Expanded(
          child: _loading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _messages.isEmpty
                  ? _buildError()
                  : ListView.builder(
                      reverse: true, controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _messages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) { _loadMessages(); return const Center(child: Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))); }
                        return _buildMessage(_messages[index]);
                      },
                    ),
        ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildError() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
    const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: LoveGirlTheme.textSecondary)),
    const SizedBox(height: 16), TextButton.icon(onPressed: () => _loadMessages(refresh: true), icon: const Icon(Icons.refresh), label: const Text('重试')),
  ]));

  Widget _buildMessage(Map<String, dynamic> msg) {
    final content = _decode(msg['content']?.toString());
    final isMine = msg['is_mine'] == true;
    final time = msg['created_at']?.toString().substring(11, 16) ?? '';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? LoveGirlTheme.primary : LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(18).copyWith(bottomRight: isMine ? const Radius.circular(4) : null, bottomLeft: isMine ? null : const Radius.circular(4)),
          boxShadow: isMine ? [] : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Text(content, style: TextStyle(fontSize: 15, color: isMine ? Colors.white : LoveGirlTheme.textPrimary)),
          if (time.isNotEmpty) ...[const SizedBox(height: 4), Text(time, style: TextStyle(fontSize: 10, color: isMine ? Colors.white60 : LoveGirlTheme.textMuted))],
        ]),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(color: LoveGirlTheme.cardLight, border: Border(top: BorderSide(color: LoveGirlTheme.separator, width: 0.5))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _msgCtrl, maxLines: 4, minLines: 1,
            decoration: InputDecoration(hintText: '发送消息...', filled: true, fillColor: LoveGirlTheme.bgLight, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sending ? null : _sendMessage,
          child: Container(width: 44, height: 44, decoration: BoxDecoration(color: LoveGirlTheme.primary, borderRadius: BorderRadius.circular(22)),
            child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
        ),
      ]),
    );
  }
}
