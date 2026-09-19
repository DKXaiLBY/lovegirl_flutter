import 'package:flutter/material.dart';
import '../../utils/lovegirl_theme.dart';

/// 倒计时表单页面 — 新增 / 编辑
class CountdownForm extends StatefulWidget {
  final Map<String, dynamic>? item;

  const CountdownForm({super.key, this.item});

  @override
  State<CountdownForm> createState() => _CountdownFormState();
}

class _CountdownFormState extends State<CountdownForm> {
  final _nameController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  int _selectedIconCodePoint = 0xe87d; // favorite

  bool get _isEdit => widget.item != null;

  static const _iconOptions = <_IconOption>[
    _IconOption(0xe87d, Icons.favorite_rounded, '爱心'),
    _IconOption(0xe1b7, Icons.cake_rounded, '蛋糕'),
    _IconOption(0xe539, Icons.flight_rounded, '飞机'),
    _IconOption(0xe80c, Icons.school_rounded, '学校'),
    _IconOption(0xe88a, Icons.home_rounded, '家'),
    _IconOption(0xe769, Icons.celebration_rounded, '庆祝'),
    _IconOption(0xe838, Icons.star_rounded, '星星'),
    _IconOption(0xe3a3, Icons.fitness_center_rounded, '健身'),
    _IconOption(0xe405, Icons.music_note_rounded, '音乐'),
    _IconOption(0xe865, Icons.book_rounded, '书本'),
    _IconOption(0xe56c, Icons.restaurant_rounded, '餐厅'),
    _IconOption(0xe8f9, Icons.work_rounded, '工作'),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final item = widget.item!;
      _nameController.text = item['name'] ?? '';
      _selectedIconCodePoint = item['iconCodePoint'] ?? 0xe87d;
      final dateStr = item['targetDate'] ?? '';
      if (dateStr.isNotEmpty) {
        _selectedDate = DateTime.tryParse(dateStr) ?? _selectedDate;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入名称'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final result = <String, dynamic>{
      'id': _isEdit
          ? widget.item!['id']
          : DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'targetDate': _formatDate(_selectedDate),
      'iconCodePoint': _selectedIconCodePoint,
      'createdAt': _isEdit
          ? (widget.item!['createdAt'] ?? DateTime.now().toIso8601String())
          : DateTime.now().toIso8601String(),
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑倒计时' : '新建倒计时'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
              style: TextStyle(
                color: context.lgInk,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 名称 =====
            _buildSectionTitle('名称'),
            SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: '例如：在一起纪念日、生日...',
                prefixIcon: Icon(Icons.edit_note, color: context.lgInk),
              ),
            ),
            SizedBox(height: 24),

            // ===== 目标日期 =====
            _buildSectionTitle('目标日期'),
            SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.lgCard,
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  border: Border.all(color: context.lgSeparator),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: context.lgInk, size: 20),
                    SizedBox(width: 10),
                    Text(
                      _formatDate(_selectedDate),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.lgTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: context.lgTextMuted),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // ===== 图标选择 =====
            _buildSectionTitle('图标'),
            SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _iconOptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final option = _iconOptions[index];
                final selected = option.codePoint == _selectedIconCodePoint;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIconCodePoint = option.codePoint),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.lgCard,
                      borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                      border: Border.all(
                        color: selected ? LoveGirlTheme.primary : context.lgSeparator,
                        width: selected ? 2.0 : 1.0,
                      ),
                      boxShadow: selected ? LoveGirlTheme.cardShadow() : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option.icon,
                          size: 28,
                          color: selected ? LoveGirlTheme.primary : context.lgTextSecondary,
                        ),
                        SizedBox(height: 4),
                        Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? LoveGirlTheme.primary : context.lgTextMuted,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: context.lgInk,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.lgTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconOption {
  final int codePoint;
  final IconData icon;
  final String label;

  const _IconOption(this.codePoint, this.icon, this.label);
}
