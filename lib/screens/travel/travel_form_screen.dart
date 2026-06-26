import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/widgets/city_picker.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:intl/intl.dart';

/// 添加/编辑旅行地点 — 精简版表单
class TravelFormScreen extends StatefulWidget {
  final TravelSpot? spot;

  const TravelFormScreen({super.key, this.spot});

  @override
  State<TravelFormScreen> createState() => _TravelFormScreenState();
}

class _TravelFormScreenState extends State<TravelFormScreen> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _diaryCtrl = TextEditingController();

  String _city = '';
  String _status = 'visited';
  int _rating = 0;
  String? _visitedDate;
  bool _saving = false;

  bool get _isEditing => widget.spot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.spot;
    if (s != null) {
      _nameCtrl.text = s.name;
      _city = s.city;
      _status = s.status;
      _noteCtrl.text = s.note ?? '';
      _diaryCtrl.text = s.diary ?? '';
      _rating = s.rating ?? 0;
      _visitedDate = s.visitedDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _diaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final city = await showCityPicker(context, currentCity: _city);
    if (city != null) setState(() => _city = city);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _visitedDate = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请输入地点名称'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (_city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请选择城市'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _saving = true);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'city': _city,
      'status': _status,
      'emoji': '📍',
      'note': _noteCtrl.text.trim(),
    };

    if (_status == 'visited') {
      data['visitedDate'] = _visitedDate ?? today;
      data['rating'] = _rating;
      data['diary'] = _diaryCtrl.text.trim();
    }

    // 编辑时保留原坐标
    if (_isEditing) {
      data['lat'] = widget.spot!.lat;
      data['lng'] = widget.spot!.lng;
    }

    try {
      if (!mounted) return;
      final provider = context.read<TravelProvider>();
      if (_isEditing) {
        await provider.updateSpot(widget.spot!.id, data);
      } else {
        await provider.createSpot(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '修改成功' : '添加成功'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('SocketException')
            ? '网络连接失败，请检查网络'
            : e.toString().contains('Timeout')
                ? '请求超时，请稍后重试'
                : '保存失败，请重试';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: LoveGirlTheme.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑地点' : '添加地点'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('保存'),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 地点名称
          _label('地点名称', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: _inputDecoration('例如：故宫博物院'),
          ),
          const SizedBox(height: 16),

          // 城市
          _label('城市', required: true),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickCity,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: LoveGirlTheme.bgLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black.withAlpha(15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city,
                      size: 20, color: LoveGirlTheme.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _city.isEmpty ? '点击选择城市' : _city,
                      style: TextStyle(
                        fontSize: 15,
                        color: _city.isEmpty
                            ? LoveGirlTheme.textMuted
                            : LoveGirlTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: LoveGirlTheme.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 状态
          _label('状态'),
          const SizedBox(height: 8),
          Row(
            children: [
              _statusChip('visited', '✅ 已打卡', const Color(0xFF4CAF50)),
              const SizedBox(width: 8),
              _statusChip('wish', '⭐ 心愿单', const Color(0xFFFF9800)),
              const SizedBox(width: 8),
              _statusChip('planned', '📋 计划中', const Color(0xFF9C27B0)),
            ],
          ),
          const SizedBox(height: 16),

          // 已打卡专属
          if (_status == 'visited') ...[
            // 日期
            _label('去的日期'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: LoveGirlTheme.bgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black.withAlpha(15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: LoveGirlTheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      _visitedDate ?? '点击选择日期（默认今天）',
                      style: TextStyle(
                        fontSize: 15,
                        color: _visitedDate != null
                            ? LoveGirlTheme.textPrimary
                            : LoveGirlTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 评分
            _label('评分'),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final starIdx = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIdx),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      starIdx <= _rating ? Icons.star : Icons.star_border,
                      color: starIdx <= _rating
                          ? const Color(0xFFFFB800)
                          : LoveGirlTheme.textMuted,
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // 游记
            _label('游记'),
            const SizedBox(height: 6),
            TextField(
              controller: _diaryCtrl,
              maxLines: 4,
              decoration: _inputDecoration('写下你们的旅行故事...'),
            ),
            const SizedBox(height: 16),
          ],

          // 备注
          _label('备注'),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: _inputDecoration('补充说明...'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        if (required)
          const Text(' *',
              style: TextStyle(color: Colors.red, fontSize: 14)),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: LoveGirlTheme.bgLight,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withAlpha(15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withAlpha(15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: LoveGirlTheme.primary, width: 1.5),
      ),
    );
  }

  Widget _statusChip(String value, String label, Color color) {
    final active = _status == value;
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(30) : LoveGirlTheme.bgLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.black.withAlpha(10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: active ? color : LoveGirlTheme.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
