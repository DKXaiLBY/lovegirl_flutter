import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/log_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../utils/constants.dart';
import '../mood/mood_screen.dart';
import '../chat/chat_screen.dart';
import '../photo/photo_screen.dart';
import '../timeline/timeline_screen.dart';
import '../feeding/feeding_screen.dart';

/// 全局搜索页面
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  Map<String, List<Map<String, dynamic>>> _groupedResults = {};
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;
  Timer? _debounce;

  static const _hotKeywords = [
    '旅行', '约会', '电影', '礼物',
    '美食', '酒店', '周年', '纪念日',
  ];

  static const _typeLabels = {
    'travel': '旅行足迹',
    'todo': '待办事项',
    'finance': '记账记录',
    'course': '课程表',
    'mood': '心情日记',
    'photo': '云端相册',
    'chat': '聊天记录',
    'timeline': '时光轴',
    'feeding': '投喂记录',
  };

  static const _typeIcons = {
    'travel': Icons.map_rounded,
    'todo': Icons.checklist_rounded,
    'finance': Icons.account_balance_wallet_rounded,
    'course': Icons.school_rounded,
    'mood': Icons.mood_rounded,
    'photo': Icons.photo_library_rounded,
    'chat': Icons.chat_bubble_rounded,
    'timeline': Icons.auto_awesome_rounded,
    'feeding': Icons.card_giftcard_rounded,
  };

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final keyword = value.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _groupedResults = {};
        _hasSearched = false;
        _error = null;
      });
      return;
    }
    if (keyword.length < 2) return;

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(keyword);
    });
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.trim().length < 2) return;
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
    });
    try {
      final res = await _api.search(keyword);
      final data = res.data?['data'];

      _results = [];
      _groupedResults = {};

      if (data is Map) {
        // 后端返回格式: { todos: [...], finances: [...], courses: [...], wishlist: [...], photos: [...], moods: [...] }
        final categories = ['todos', 'finances', 'courses', 'wishlist', 'photos', 'moods'];
        final typeMap = {
          'todos': 'todo',
          'finances': 'finance',
          'courses': 'course',
          'wishlist': 'feeding',
          'photos': 'photo',
          'moods': 'mood',
        };

        for (final cat in categories) {
          final items = data[cat];
          if (items is List && items.isNotEmpty) {
            final type = typeMap[cat] ?? cat;
            for (final item in items) {
              final Map<String, dynamic> result = Map<String, dynamic>.from(item);
              result['type'] = type;
              _results.add(result);
              _groupedResults.putIfAbsent(type, () => []).add(result);
            }
          }
        }
      } else if (data is List) {
        _results = data.map((e) => Map<String, dynamic>.from(e)).toList();
        for (final item in _results) {
          final type = (item['type'] ?? 'other').toString();
          _groupedResults.putIfAbsent(type, () => []).add(item);
        }
      }

      LogService().info('Search', '搜索"$keyword" 找到${_results.length}条结果');
    } catch (e) {
      _error = '搜索失败，请重试';
      LogService().error('Search', '搜索失败: $e');
    }
    setState(() => _loading = false);
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _results = [];
      _groupedResults = {};
      _hasSearched = false;
      _error = null;
    });
    _focusNode.requestFocus();
  }

  void _onResultTap(Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString();
    final title = (item['title'] ?? item['name'] ?? '').toString();
    LogService().userAction('搜索点击: $type - $title');

    // 根据类型跳转到对应页面或Tab
    switch (type) {
      case 'mood':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodScreen()));
        break;
      case 'chat':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
        break;
      case 'photo':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoScreen()));
        break;
      case 'timeline':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TimelineScreen()));
        break;
      case 'feeding':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedingScreen()));
        break;
      case 'travel':
      case 'todo':
      case 'finance':
      case 'course':
        // Tab 类型：关闭搜索页并返回主页，通过结果传递导航意图
        Navigator.pop(context, {'type': type, 'id': item['id'], 'title': title});
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(title.isNotEmpty ? '查看: $title' : '暂不支持跳转到此类型'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _searchController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 8),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: true,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '搜索旅行、待办、账单...',
              hintStyle: TextStyle(color: LoveGirlTheme.textMuted.withAlpha(150), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: LoveGirlTheme.primary, size: 20),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: _clearSearch,
                    )
                  : null,
              filled: true,
              fillColor: LoveGirlTheme.bgLight,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LoveGirlTheme.separator.withAlpha(200)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: LoveGirlTheme.separator.withAlpha(200)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: LoveGirlTheme.primary, width: 1.5),
              ),
            ),
          ),
        ),
        titleSpacing: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return _buildSuggestions();
    }
    if (_error != null) {
      return _buildError();
    }
    if (_results.isEmpty) {
      return _buildNoResults();
    }
    return _buildResults();
  }

  // ==================== 热门搜索建议 ====================
  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(color: LoveGirlTheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              const Text('热门搜索', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LoveGirlTheme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _hotKeywords.map((keyword) {
            return GestureDetector(
              onTap: () {
                _searchController.text = keyword;
                _onSearchChanged(keyword);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: LoveGirlTheme.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  keyword,
                  style: const TextStyle(
                    fontSize: 14,
                    color: LoveGirlTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 40),
        Center(
          child: Column(
            children: [
              const Icon(Icons.search_off_rounded, size: 64, color: LoveGirlTheme.separator),
              const SizedBox(height: 12),
              const Text('搜一搜你们的回忆', style: TextStyle(fontSize: 15, color: LoveGirlTheme.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 搜索结果 ====================
  Widget _buildResults() {
    final types = _groupedResults.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: types.length,
      itemBuilder: (ctx, i) {
        final type = types[i];
        final items = _groupedResults[type]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(type, items.length),
            const SizedBox(height: 8),
            ...items.map((item) => _buildResultCard(item)),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String type, int count) {
    final label = _typeLabels[type] ?? type;
    final icon = _typeIcons[type] ?? Icons.search_rounded;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(color: LoveGirlTheme.primary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: LoveGirlTheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LoveGirlTheme.textSecondary)),
          const SizedBox(width: 6),
          Text('$count', style: const TextStyle(fontSize: 12, color: LoveGirlTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item) {
    final title = item['title'] ?? item['name'] ?? '';
    final subtitle = item['subtitle'] ?? item['description'] ?? item['desc'] ?? '';
    final type = item['type'] ?? 'other';
    final icon = _typeIcons[type] ?? Icons.search_rounded;

    return GestureDetector(
      onTap: () => _onResultTap(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: LoveGirlTheme.cardLight,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: LoveGirlTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: LoveGirlTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: LoveGirlTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: LoveGirlTheme.textMuted),
          ],
        ),
      ),
    );
  }

  // ==================== 空结果 ====================
  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: LoveGirlTheme.textMuted),
            const SizedBox(height: 16),
            const Text('未找到相关结果', style: TextStyle(fontSize: 16, color: LoveGirlTheme.textSecondary)),
            const SizedBox(height: 4),
            Text(
              '换个关键词试试吧~',
              style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted.withAlpha(180)),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 错误状态 ====================
  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: LoveGirlTheme.textSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _performSearch(_searchController.text.trim()),
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
