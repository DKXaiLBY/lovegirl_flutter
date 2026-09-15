import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/lovegirl_ui.dart';

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

  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 滚动到顶部（列表倒序，所以顶部=更早的消息）时加载更多
    if (_scrollCtrl.position.pixels <= 50 &&
        _hasMore &&
        !_loadingMore &&
        !_loading) {
      _loadMessages();
    }
  }

  Future<void> _loadMessages({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }
    if (!_hasMore && !refresh) return;
    final isRefresh = refresh || _messages.isEmpty;
    setState(() {
      _loading = isRefresh;
      _loadingMore = !isRefresh;
      _error = null;
    });
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
        if (refresh) {
          _messages = list;
        } else {
          _messages.addAll(list);
        }
        _hasMore = list.length >= 20;
        _page = refresh ? 2 : _page + 1;
        _loading = false;
        _loadingMore = false;
      });
      LogService().info('Chat', '加载${list.length}条消息');
    } catch (e) {
      setState(() {
        _error = '加载失败';
        _loading = false;
        _loadingMore = false;
      });
      LogService().error('Chat', '加载失败: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final optimisticId = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _messages.insert(0, {
        'content': text,
        'is_mine': true,
        'created_at': DateTime.now().toIso8601String(),
        'id': optimisticId,
      });
      _sending = true;
    });
    _msgCtrl.clear();
    try {
      await _api.sendMessage({'content': text});
      LogService().userAction('发送消息');
      await _loadMessages(refresh: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == optimisticId);
          _msgCtrl.text = text;
          _msgCtrl.selection =
              TextSelection.collapsed(offset: _msgCtrl.text.length);
        });
      }
      LogService().error('Chat', '发送失败: $e');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _buildHeader(),
          ),
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _messages.isEmpty
                    ? _buildError()
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount: _messages.length +
                            (_hasMore || _loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))));
                          }
                          return _buildMessage(_messages[index]);
                        },
                      ),
          ),
          _buildInputBar(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return LovePaper(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          LoveIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: '返回',
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: LoveGirlTheme.primarySoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.mark_chat_unread_rounded,
              color: LoveGirlTheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '私密聊天',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '只属于你们的小纸条',
                  style: TextStyle(
                    fontSize: 12,
                    color: LoveGirlTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          LoveIconButton(
            icon: Icons.refresh_rounded,
            tooltip: '刷新',
            onTap: () => _loadMessages(refresh: true),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
        const SizedBox(height: 12),
        Text(_error!,
            style: const TextStyle(color: LoveGirlTheme.textSecondary)),
        const SizedBox(height: 16),
        TextButton.icon(
            onPressed: () => _loadMessages(refresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('重试')),
      ]));

  Widget _buildMessage(Map<String, dynamic> msg) {
    final content = fixUtf8Encoding(msg['content']?.toString());
    final userId = context.read<AuthProvider>().user?['id']?.toString();
    final senderId = (msg['senderId'] ?? msg['sender_id'])?.toString();
    final isMine =
        msg['is_mine'] == true || (userId != null && senderId == userId);
    final createdAtStr =
        (msg['created_at'] ?? msg['createdAt'])?.toString() ?? '';
    final time =
        createdAtStr.length >= 16 ? createdAtStr.substring(11, 16) : '';
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? LoveGirlTheme.primary : LoveGirlTheme.paper,
          borderRadius: BorderRadius.circular(20).copyWith(
              bottomRight: isMine ? const Radius.circular(6) : null,
              bottomLeft: isMine ? null : const Radius.circular(6)),
          border: isMine ? null : Border.all(color: LoveGirlTheme.separator),
          boxShadow: isMine
              ? LoveGirlTheme.cardShadow()
              : [
                  BoxShadow(
                      color: Colors.black.withAlpha(5),
                      blurRadius: 12,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(content,
                  style: TextStyle(
                      fontSize: 15,
                      color:
                          isMine ? Colors.white : LoveGirlTheme.textPrimary)),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(time,
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            isMine ? Colors.white60 : LoveGirlTheme.textMuted))
              ],
            ]),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: LoveGirlTheme.paperWarm,
        border: Border(
          top: BorderSide(color: LoveGirlTheme.separator.withAlpha(180)),
        ),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _msgCtrl,
            maxLines: 4,
            minLines: 1,
            decoration: InputDecoration(
                hintText: '发送消息...',
                filled: true,
                fillColor: LoveGirlTheme.paper,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sending ? null : _sendMessage,
          child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: LoveGirlTheme.primary,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: LoveGirlTheme.cardShadow()),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20)),
        ),
      ]),
    );
  }
}
