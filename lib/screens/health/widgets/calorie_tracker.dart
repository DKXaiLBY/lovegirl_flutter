import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

/// 餐段枚举
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get label {
    switch (this) {
      case MealType.breakfast:
        return '早餐';
      case MealType.lunch:
        return '午餐';
      case MealType.dinner:
        return '晚餐';
      case MealType.snack:
        return '加餐';
    }
  }

  IconData get icon {
    switch (this) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
      case MealType.snack:
        return Icons.cookie;
    }
  }
}

/// 卡路里记录模型
class CalorieRecord {
  final int? id;
  final String date;
  final String mealType;
  final String foodName;
  final double calories;
  final String? createdAt;

  CalorieRecord({
    this.id,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.calories,
    this.createdAt,
  });

  factory CalorieRecord.fromJson(Map<String, dynamic> json) {
    return CalorieRecord(
      id: json['id'] as int?,
      date: json['date'] as String? ?? '',
      mealType: json['meal_type'] as String? ?? 'snack',
      foodName: json['food_name'] as String? ?? json['name'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  MealType get mealTypeEnum {
    switch (mealType) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.snack;
    }
  }
}

/// 餐段分组
class MealGroup {
  final MealType type;
  final List<CalorieRecord> records;
  double get totalCalories => records.fold(0, (sum, r) => sum + r.calories);

  MealGroup({required this.type, required this.records});
}

class CalorieTracker extends StatefulWidget {
  const CalorieTracker({super.key});

  @override
  State<CalorieTracker> createState() => _CalorieTrackerState();
}

class _CalorieTrackerState extends State<CalorieTracker> {
  final ApiService _api = ApiService();
  final double _dailyTarget = 1500.0;

  bool _isLoading = true;
  String? _error;

  DateTime _selectedDate = DateTime.now();
  List<CalorieRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  String get _todayStr => DateFormat('yyyy-MM-dd').format(_selectedDate);

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _api.getCalorieRecords(_todayStr);
      List<dynamic>? listData;
      if (res.data['data'] != null) {
        listData = res.data['data'] as List<dynamic>?;
      } else if (res.data is List) {
        listData = res.data as List<dynamic>;
      }

      final records = <CalorieRecord>[];
      if (listData != null) {
        for (final item in listData) {
          records.add(CalorieRecord.fromJson(item as Map<String, dynamic>));
        }
      }

      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败，下拉刷新重试';
        _isLoading = false;
      });
    }
  }

  List<MealGroup> get _mealGroups {
    final groups = <MealGroup>[];
    for (final type in MealType.values) {
      final filtered =
          _records.where((r) => r.mealType == type.name).toList();
      if (filtered.isNotEmpty) {
        groups.add(MealGroup(type: type, records: filtered));
      }
    }
    // 按 meal type 顺序排序
    groups.sort((a, b) => a.type.index.compareTo(b.type.index));
    return groups;
  }

  double get _totalCalories {
    return _records.fold(0.0, (sum, r) => sum + r.calories);
  }

  double get _progress => (_totalCalories / _dailyTarget).clamp(0.0, 1.5);

  Color get _progressColor {
    if (_totalCalories <= _dailyTarget * 0.8) return const Color(0xFF4CAF50);
    if (_totalCalories <= _dailyTarget) return const Color(0xFFFF9800);
    return Colors.redAccent;
  }

  String get _progressLabel {
    if (_totalCalories <= _dailyTarget * 0.8) return '继续加油';
    if (_totalCalories <= _dailyTarget) return '接近目标';
    return '已超标';
  }

  Future<void> _deleteRecord(int id) async {
    try {
      await _api.deleteCalorieRecord(id);
      await _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已删除记录'),
            backgroundColor: LoveGirlTheme.pink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('删除失败'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddFoodDialog() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddFoodSheet(
        onAdded: () {
          _loadRecords();
        },
      ),
    );
  }

  void _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: LoveGirlTheme.pink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: LoveGirlTheme.pink),
      );
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _loadRecords,
        color: LoveGirlTheme.pink,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: LoveGirlTheme.textMuted),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: LoveGirlTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadRecords,
          color: LoveGirlTheme.pink,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              _buildDateSelector(),
              const SizedBox(height: 16),
              _buildCalorieProgress(),
              const SizedBox(height: 20),
              if (_mealGroups.isEmpty) _buildEmptyState(),
              ..._mealGroups.map((g) => _buildMealGroup(g)),
            ],
          ),
        ),
        // 浮动按钮
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton(
            onPressed: _showAddFoodDialog,
            backgroundColor: LoveGirlTheme.pink,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final dateFormat = DateFormat('M月d日 EEEE', 'zh_CN');
    final isToday = _selectedDate.day == DateTime.now().day &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.year == DateTime.now().year;

    return GestureDetector(
      onTap: _showDatePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: LoveGirlTheme.pink),
            const SizedBox(width: 10),
            Text(
              isToday ? '今天' : dateFormat.format(_selectedDate),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 20, color: LoveGirlTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            LoveGirlTheme.pink.withAlpha(30),
            LoveGirlTheme.pinkLight.withAlpha(15),
            Colors.white,
          ],
        ),
        border: Border.all(
          color: LoveGirlTheme.pink.withAlpha(30),
        ),
        boxShadow: [
          BoxShadow(
            color: LoveGirlTheme.pink.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 总卡路里数字
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _totalCalories.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: LoveGirlTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '千卡',
                  style: TextStyle(
                    fontSize: 14,
                    color: LoveGirlTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '目标 $_dailyTarget 千卡',
            style: const TextStyle(
              fontSize: 13,
              color: LoveGirlTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress > 1.0 ? 1.0 : _progress,
              minHeight: 12,
              backgroundColor: Colors.white.withAlpha(180),
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0千卡',
                style: TextStyle(fontSize: 11, color: LoveGirlTheme.textMuted),
              ),
              Text(
                _progressLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _progressColor,
                ),
              ),
              Text(
                '$_dailyTarget千卡',
                style: TextStyle(fontSize: 11, color: LoveGirlTheme.textMuted),
              ),
            ],
          ),
          // 超出提示
          if (_totalCalories > _dailyTarget)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '超出 ${(_totalCalories - _dailyTarget).toStringAsFixed(0)} 千卡',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(Icons.restaurant, size: 64, color: LoveGirlTheme.textMuted.withAlpha(80)),
          const SizedBox(height: 12),
          const Text(
            '今天还没有记录',
            style: TextStyle(
              fontSize: 16,
              color: LoveGirlTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '点击右下角按钮添加饮食记录',
            style: TextStyle(
              fontSize: 13,
              color: LoveGirlTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealGroup(MealGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 餐段标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(group.type.icon, size: 20, color: LoveGirlTheme.pink),
                const SizedBox(width: 8),
                Text(
                  group.type.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${group.totalCalories.toStringAsFixed(0)} 千卡',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: LoveGirlTheme.pink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // 食物列表
          ...group.records.map((record) => _buildFoodItem(record)),
        ],
      ),
    );
  }

  Widget _buildFoodItem(CalorieRecord record) {
    return Dismissible(
      key: Key('calorie_${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除记录'),
            content: Text('确认删除「${record.foodName}」吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) {
        if (record.id != null) {
          _deleteRecord(record.id!);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 食物图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: LoveGirlTheme.pink.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_menu, size: 18, color: LoveGirlTheme.pink),
            ),
            const SizedBox(width: 12),
            // 名称
            Expanded(
              child: Text(
                record.foodName,
                style: const TextStyle(
                  fontSize: 15,
                  color: LoveGirlTheme.textPrimary,
                ),
              ),
            ),
            // 卡路里
            Text(
              '${record.calories.toStringAsFixed(0)} 千卡',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: LoveGirlTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 添加食物底部弹窗
// =============================================================================

class _AddFoodSheet extends StatefulWidget {
  final VoidCallback onAdded;

  const _AddFoodSheet({required this.onAdded});

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSearching = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showCustomForm = false;

  // 自定义表单字段
  String _customFoodName = '';
  double _customCalories = 0;
  MealType _selectedMealType = MealType.lunch;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchFood(String keyword) async {
    if (keyword.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final res = await _api.searchFoods(keyword.trim());
      List<dynamic>? list;
      if (res.data['data'] != null) {
        list = res.data['data'] as List<dynamic>;
      } else if (res.data is List) {
        list = res.data as List<dynamic>;
      }
      setState(() {
        _searchResults = list?.map((e) => e as Map<String, dynamic>).toList() ?? [];
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _saveRecord({
    required String foodName,
    required double calories,
    required String mealType,
  }) async {
    setState(() => _isSaving = true);

    try {
      final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await _api.addCalorieRecord({
        'date': now,
        'meal_type': mealType,
        'food_name': foodName,
        'calories': calories,
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('添加失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showCustomFormToggle() {
    setState(() {
      _showCustomForm = true;
      _searchResults = [];
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 拖动指示条
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: LoveGirlTheme.textMuted.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '添加食物',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: LoveGirlTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    if (!_showCustomForm)
                      TextButton.icon(
                        onPressed: _showCustomFormToggle,
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text('手动输入'),
                        style: TextButton.styleFrom(
                          foregroundColor: LoveGirlTheme.pink,
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: LoveGirlTheme.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _showCustomForm ? _buildCustomForm() : _buildSearchView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchView() {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '搜索食物名称...',
              prefixIcon: const Icon(Icons.search, color: LoveGirlTheme.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: LoveGirlTheme.bgLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: (v) {
              // 防抖：300ms 后再搜索
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_searchController.text == v && v.isNotEmpty) {
                  _searchFood(v);
                }
              });
            },
          ),
        ),
        // 搜索结果
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: LoveGirlTheme.pink))
              : _searchResults.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 60),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 48, color: LoveGirlTheme.textMuted.withAlpha(100)),
                              const SizedBox(height: 12),
                              const Text(
                                '搜索食物名称，或手动输入',
                                style: TextStyle(color: LoveGirlTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        final name = item['name'] as String? ?? item['food_name'] as String? ?? '';
                        final cal = (item['calories'] as num?)?.toDouble() ?? 0;
                        final unit = item['unit'] as String? ?? '份';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: LoveGirlTheme.pink.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.restaurant_menu, size: 20, color: LoveGirlTheme.pink),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('每$unit $cal 千卡'),
                          trailing: const Icon(Icons.add_circle_outline, color: LoveGirlTheme.pink),
                          onTap: () => _showMealTypeSelector(
                            foodName: name,
                            calories: cal,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCustomForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('食物名称', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: LoveGirlTheme.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: '例如：苹果、三明治',
                filled: true,
                fillColor: LoveGirlTheme.bgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => _customFoodName = v,
            ),
            const SizedBox(height: 16),
            const Text('卡路里（千卡）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: LoveGirlTheme.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '例如：200',
                suffixText: '千卡',
                filled: true,
                fillColor: LoveGirlTheme.bgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => _customCalories = double.tryParse(v) ?? 0,
            ),
            const SizedBox(height: 16),
            const Text('餐段', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: LoveGirlTheme.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealType.values.map((type) {
                final selected = type == _selectedMealType;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(type.icon, size: 16, color: selected ? Colors.white : LoveGirlTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(type.label),
                    ],
                  ),
                  selected: selected,
                  selectedColor: LoveGirlTheme.pink,
                  backgroundColor: LoveGirlTheme.bgLight,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : LoveGirlTheme.textPrimary,
                    fontSize: 13,
                  ),
                  onSelected: (v) {
                    if (v) setState(() => _selectedMealType = type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        if (_customFoodName.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入食物名称')),
                          );
                          return;
                        }
                        if (_customCalories <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入有效卡路里数值')),
                          );
                          return;
                        }
                        _saveRecord(
                          foodName: _customFoodName.trim(),
                          calories: _customCalories,
                          mealType: _selectedMealType.name,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: LoveGirlTheme.pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('添加记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMealTypeSelector({
    required String foodName,
    required double calories,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: LoveGirlTheme.textMuted.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              foodName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: LoveGirlTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$calories 千卡',
              style: const TextStyle(
                fontSize: 16,
                color: LoveGirlTheme.pink,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const Text('选择餐段', style: TextStyle(fontSize: 14, color: LoveGirlTheme.textSecondary)),
            const SizedBox(height: 12),
            ...MealType.values.map((type) => ListTile(
                  leading: Icon(type.icon, color: LoveGirlTheme.pink),
                  title: Text(type.label),
                  trailing: const Icon(Icons.chevron_right, color: LoveGirlTheme.textMuted),
                  onTap: () {
                    Navigator.pop(ctx);
                    _saveRecord(
                      foodName: foodName,
                      calories: calories,
                      mealType: type.name,
                    );
                  },
                )),
          ],
        ),
      ),
    );
  }
}
