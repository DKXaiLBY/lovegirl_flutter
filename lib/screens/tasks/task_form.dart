import 'package:flutter/material.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';

class TaskForm extends StatefulWidget {
  final Map<String, dynamic>? task;

  const TaskForm({super.key, this.task});

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = '旅行';
  bool _isEdit = false;

  static const _categories = ['旅行', '美食', '运动', '学习', '生活'];

  static const _categoryColors = <String, Color>{
    '旅行': Color(0xFF2196F3),
    '美食': Color(0xFFFF9800),
    '运动': Color(0xFF4CAF50),
    '学习': Color(0xFF9C27B0),
    '生活': Color(0xFFE91E63),
  };

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _isEdit = true;
      _nameCtrl.text = widget.task!['name'] ?? '';
      _notesCtrl.text = widget.task!['notes'] ?? '';
      _category = widget.task!['category'] ?? '旅行';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入任务名称'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = <String, dynamic>{
      'name': name,
      'category': _category,
      'notes': _notesCtrl.text.trim(),
    };

    if (_isEdit) {
      result['id'] = widget.task!['id'];
      result['completed'] = widget.task!['completed'];
      result['createdAt'] = widget.task!['createdAt'];
      result['completedAt'] = widget.task!['completedAt'];
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LoveGirlTheme.bgLight,
      appBar: AppBar(
        title: Text(_isEdit ? '编辑愿望' : '添加愿望'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              '保存',
              style: TextStyle(
                color: LoveGirlTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(LoveGirlTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任务名称
            const Text(
              '任务名称',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textPrimary,
              ),
            ),
            const SizedBox(height: LoveGirlTheme.spaceXs),
            TextField(
              controller: _nameCtrl,
              autofocus: !_isEdit,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '输入愿望名称...',
                prefixIcon: const Icon(
                  Icons.auto_awesome_rounded,
                  color: LoveGirlTheme.primary,
                ),
                filled: true,
                fillColor: LoveGirlTheme.cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  borderSide: const BorderSide(color: LoveGirlTheme.separator),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  borderSide: const BorderSide(
                    color: LoveGirlTheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: LoveGirlTheme.spaceLg),

            // 分类
            const Text(
              '分类',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textPrimary,
              ),
            ),
            const SizedBox(height: LoveGirlTheme.spaceXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: LoveGirlTheme.cardLight,
                borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                border: Border.all(color: LoveGirlTheme.separator),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: LoveGirlTheme.textMuted,
                  ),
                  items: _categories.map((c) {
                    final color = _categoryColors[c] ?? LoveGirlTheme.primary;
                    return DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(c),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: LoveGirlTheme.spaceLg),

            // 备注
            const Text(
              '备注',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textPrimary,
              ),
            ),
            const SizedBox(height: LoveGirlTheme.spaceXs),
            TextField(
              controller: _notesCtrl,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: '添加备注（可选）...',
                filled: true,
                fillColor: LoveGirlTheme.cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  borderSide: const BorderSide(color: LoveGirlTheme.separator),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  borderSide: const BorderSide(
                    color: LoveGirlTheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
