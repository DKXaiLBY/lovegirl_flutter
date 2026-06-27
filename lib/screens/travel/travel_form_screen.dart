import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/widgets/city_picker.dart';
import 'package:lovegirl_flutter/widgets/travel_photo_grid.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:intl/intl.dart';

/// 添加/编辑旅行地点 — 完整表单
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
  final _budgetCtrl = TextEditingController();
  final _itineraryCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  String _city = '';
  String _status = 'visited';
  int _rating = 0;
  String? _visitedDate;
  String? _plannedDate;
  String _weather = '';
  String _mood = '';
  bool _saving = false;

  bool get _isEditing => widget.spot != null;

  // 天气选项
  static const _weatherOptions = [
    {'emoji': '☀️', 'label': '晴天'},
    {'emoji': '🌤️', 'label': '多云'},
    {'emoji': '🌧️', 'label': '雨天'},
    {'emoji': '❄️', 'label': '雪天'},
    {'emoji': '🌙', 'label': '夜晚'},
    {'emoji': '🌈', 'label': '彩虹'},
  ];

  // 心情选项
  static const _moodOptions = [
    {'emoji': '🥰', 'label': '甜蜜'},
    {'emoji': '😊', 'label': '开心'},
    {'emoji': '🤩', 'label': '兴奋'},
    {'emoji': '😌', 'label': '平静'},
    {'emoji': '🥹', 'label': '感动'},
    {'emoji': '😎', 'label': '酷'},
  ];

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
      _plannedDate = s.plannedDate;
      _weather = s.mood ?? ''; // 复用mood字段存储天气+心情
      _budgetCtrl.text = s.budget != null ? s.budget!.toStringAsFixed(0) : '';
      _itineraryCtrl.text = s.itinerary ?? '';
      _reasonCtrl.text = s.reason ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _diaryCtrl.dispose();
    _budgetCtrl.dispose();
    _itineraryCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final city = await showCityPicker(context, currentCity: _city);
    if (city != null) setState(() => _city = city);
  }

  Future<void> _pickVisitedDate() async {
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

  Future<void> _pickPlannedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _plannedDate = DateFormat('yyyy-MM-dd').format(picked));
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
      'emoji': _statusEmoji,
      'note': _noteCtrl.text.trim(),
    };

    if (_status == 'visited') {
      data['visitedDate'] = _visitedDate ?? today;
      data['rating'] = _rating;
      data['diary'] = _diaryCtrl.text.trim();
      data['mood'] = _mood;
    }

    if (_status == 'planned') {
      data['plannedDate'] = _plannedDate;
      data['itinerary'] = _itineraryCtrl.text.trim();
    }

    if (_status == 'wish') {
      data['reason'] = _reasonCtrl.text.trim();
    }

    // 预算
    final budgetText = _budgetCtrl.text.trim();
    if (budgetText.isNotEmpty) {
      data['budget'] = double.tryParse(budgetText);
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

  String get _statusEmoji {
    switch (_status) {
      case 'visited':
        return '✅';
      case 'wish':
        return '⭐';
      case 'planned':
        return '📋';
      default:
        return '📍';
    }
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
          const SizedBox(height: 20),

          // ===== 已打卡专属 =====
          if (_status == 'visited') ...[
            _sectionTitle('打卡详情'),
            const SizedBox(height: 12),

            // 日期
            _label('去的日期'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickVisitedDate,
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

            // 天气
            _label('天气'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _weatherOptions.map((w) {
                final active = _weather == w['label'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _weather = active ? '' : w['label']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? LoveGirlTheme.primary.withAlpha(20)
                          : LoveGirlTheme.bgLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? LoveGirlTheme.primary
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Text('${w['emoji']} ${w['label']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: active
                              ? LoveGirlTheme.primary
                              : LoveGirlTheme.textSecondary,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 心情
            _label('心情'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moodOptions.map((m) {
                final active = _mood == m['label'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _mood = active ? '' : m['label']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? LoveGirlTheme.pink.withAlpha(20)
                          : LoveGirlTheme.bgLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active
                            ? LoveGirlTheme.pink
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Text('${m['emoji']} ${m['label']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: active
                              ? LoveGirlTheme.pink
                              : LoveGirlTheme.textSecondary,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ),
                );
              }).toList(),
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
              maxLines: 5,
              decoration: _inputDecoration('写下你们的旅行故事...'),
            ),
            const SizedBox(height: 16),
          ],

          // ===== 心愿单专属 =====
          if (_status == 'wish') ...[
            _sectionTitle('心愿详情'),
            const SizedBox(height: 12),

            _label('想去的理由'),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: _inputDecoration('为什么想去这里？'),
            ),
            const SizedBox(height: 16),
          ],

          // ===== 规划中专属 =====
          if (_status == 'planned') ...[
            _sectionTitle('规划详情'),
            const SizedBox(height: 12),

            _label('计划日期'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickPlannedDate,
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
                    const Icon(Icons.event,
                        size: 18, color: Color(0xFF9C27B0)),
                    const SizedBox(width: 10),
                    Text(
                      _plannedDate ?? '点击选择计划日期',
                      style: TextStyle(
                        fontSize: 15,
                        color: _plannedDate != null
                            ? LoveGirlTheme.textPrimary
                            : LoveGirlTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            _label('行程安排'),
            const SizedBox(height: 6),
            TextField(
              controller: _itineraryCtrl,
              maxLines: 4,
              decoration: _inputDecoration('Day1: ...\nDay2: ...'),
            ),
            const SizedBox(height: 16),
          ],

          // ===== 预算（所有状态通用） =====
          _sectionTitle('其他信息'),
          const SizedBox(height: 12),

          _label('预算（元）'),
          const SizedBox(height: 6),
          TextField(
            controller: _budgetCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: _inputDecoration('例如：5000').copyWith(
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                  size: 20, color: LoveGirlTheme.textMuted),
            ),
          ),
          const SizedBox(height: 16),

          // 备注
          _label('备注'),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: _inputDecoration('补充说明...'),
          ),
          const SizedBox(height: 20),

          // ===== 照片管理（编辑模式） =====
          if (_isEditing) ...[
            _sectionTitle('照片'),
            const SizedBox(height: 12),
            TravelPhotoGrid(
              spotId: widget.spot!.id,
              editable: true,
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: LoveGirlTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LoveGirlTheme.textSecondary)),
      ],
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
      hintStyle:
          TextStyle(color: LoveGirlTheme.textMuted.withAlpha(150)),
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
