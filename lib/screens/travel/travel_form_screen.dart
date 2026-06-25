import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/map_picker_screen.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:intl/intl.dart';

/// 添加/编辑旅行地点的表单页面
class TravelFormScreen extends StatefulWidget {
  final TravelSpot? spot;

  const TravelFormScreen({super.key, this.spot});

  @override
  State<TravelFormScreen> createState() => _TravelFormScreenState();
}

class _TravelFormScreenState extends State<TravelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _diaryCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _itineraryCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

  String _status = 'visited';
  int _rating = 0;
  int _desire = 1;
  String? _visitedDate;
  String? _plannedDate;
  bool _saving = false;

  // 地图选点相关
  double _lat = 0;
  double _lng = 0;
  String _selectedCity = '';
  String _selectedAddress = '';

  bool get _isEditing => widget.spot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.spot;
    if (s != null) {
      _nameCtrl.text = s.name;
      _cityCtrl.text = s.city;
      _addressCtrl.text = s.address;
      _status = s.status;
      _diaryCtrl.text = s.diary ?? '';
      _noteCtrl.text = s.note ?? '';
      _reasonCtrl.text = s.reason ?? '';
      _itineraryCtrl.text = s.itinerary ?? '';
      _budgetCtrl.text = s.budget?.toStringAsFixed(0) ?? '';
      _rating = s.rating ?? 0;
      _desire = s.desire ?? 1;
      _visitedDate = s.visitedDate;
      _plannedDate = s.plannedDate;
      _lat = s.lat;
      _lng = s.lng;
      _selectedCity = s.city;
      _selectedAddress = s.address;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _diaryCtrl.dispose();
    _noteCtrl.dispose();
    _reasonCtrl.dispose();
    _itineraryCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isVisited}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        final fmt = DateFormat('yyyy-MM-dd');
        if (isVisited) {
          _visitedDate = fmt.format(picked);
        } else {
          _plannedDate = fmt.format(picked);
        }
      });
    }
  }

  /// 打开地图选点
  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _lat != 0 ? _lat : null,
          initialLng: _lng != 0 ? _lng : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _lat = result['lat'] ?? 0;
        _lng = result['lng'] ?? 0;
        _selectedCity = result['city'] ?? '';
        _selectedAddress = result['address'] ?? '';
        // 自动填充城市（如果为空）
        if (_cityCtrl.text.isEmpty && _selectedCity.isNotEmpty) {
          _cityCtrl.text = _selectedCity;
        }
        // 自动填充地址（如果为空）
        if (_addressCtrl.text.isEmpty && _selectedAddress.isNotEmpty) {
          _addressCtrl.text = _selectedAddress;
        }
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入地点名称')),
      );
      return;
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'emoji': '📍',
      'status': _status,
      'lng': _lng,
      'lat': _lat,
      'note': _noteCtrl.text.trim(),
    };

    switch (_status) {
      case 'visited':
        data['visitedDate'] = _visitedDate;
        data['rating'] = _rating;
        data['diary'] = _diaryCtrl.text.trim();
        break;
      case 'wish':
        data['reason'] = _reasonCtrl.text.trim();
        data['desire'] = _desire;
        break;
      case 'planned':
        data['plannedDate'] = _plannedDate;
        data['itinerary'] = _itineraryCtrl.text.trim();
        final budget = double.tryParse(_budgetCtrl.text.trim());
        if (budget != null) data['budget'] = budget;
        break;
    }

    try {
      final provider = context.read<TravelProvider>();
      if (_isEditing) {
        await provider.updateSpot(widget.spot!.id, data);
      } else {
        await provider.createSpot(data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑地点' : '添加地点'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('保存'),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // 基本信息
            _buildSection('基本信息', [
              _buildTextField(
                controller: _nameCtrl,
                label: '地点名称',
                hint: '例如：故宫博物院',
                required: true,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _cityCtrl,
                label: '城市',
                hint: '例如：北京',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _addressCtrl,
                label: '地址（可选）',
                hint: '具体地址',
              ),
            ]),

            const SizedBox(height: 8),

            // 位置选择
            _buildSection('位置信息', [
              _buildLocationPicker(),
            ]),

            const SizedBox(height: 8),

            // 状态切换
            _buildSection('旅行状态', [
              _buildStatusToggle(),
            ]),

            const SizedBox(height: 8),

            // 状态专属字段
            if (_status == 'visited') _buildVisitedFields(),
            if (_status == 'wish') _buildWishFields(),
            if (_status == 'planned') _buildPlannedFields(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Visited 专属字段
  Widget _buildVisitedFields() {
    return _buildSection('旅行回忆', [
      _buildDateTile(
        icon: Icons.calendar_today,
        label: '去的日期',
        value: _visitedDate,
        onTap: () => _pickDate(isVisited: true),
      ),
      const SizedBox(height: 16),
      const Text('评分', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
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
                color: starIdx <= _rating ? const Color(0xFFFFB800) : LoveGirlTheme.textMuted,
                size: 32,
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _diaryCtrl,
        label: '游记日记',
        hint: '写下你们的旅行故事...',
        maxLines: 5,
      ),
    ]);
  }

  // Wish 专属字段
  Widget _buildWishFields() {
    return _buildSection('想去的心愿', [
      _buildTextField(
        controller: _reasonCtrl,
        label: '想去的理由',
        hint: '为什么想去这里呢？',
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      const Text('渴望度', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      const SizedBox(height: 8),
      Row(
        children: List.generate(3, (i) {
          final idx = i + 1;
          return GestureDetector(
            onTap: () => setState(() => _desire = idx),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 32,
                color: idx <= _desire ? LoveGirlTheme.orange : LoveGirlTheme.textMuted.withAlpha(77),
              ),
            ),
          );
        }),
      ),
    ]);
  }

  // Planned 专属字段
  Widget _buildPlannedFields() {
    return _buildSection('出行计划', [
      _buildDateTile(
        icon: Icons.event,
        label: '计划日期',
        value: _plannedDate,
        onTap: () => _pickDate(isVisited: false),
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _itineraryCtrl,
        label: '行程安排',
        hint: '计划去哪些地方？',
        maxLines: 3,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _budgetCtrl,
        label: '预估预算（元）',
        hint: '例如：5000',
        keyboardType: TextInputType.number,
      ),
    ]);
  }

  // 通用构建方法
  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            if (required)
              const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? '请输入$label' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              borderSide: const BorderSide(color: LoveGirlTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: LoveGirlTheme.bgLight,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: LoveGirlTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withAlpha(15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: LoveGirlTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: LoveGirlTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value ?? '点击选择日期',
                    style: TextStyle(
                      fontSize: 15,
                      color: value != null ? LoveGirlTheme.textPrimary : LoveGirlTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: LoveGirlTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusToggle() {
    final statuses = [
      {'key': 'visited', 'label': '已打卡', 'color': const Color(0xFF4CAF50)},
      {'key': 'wish', 'label': '心愿单', 'color': const Color(0xFFFF9800)},
      {'key': 'planned', 'label': '计划中', 'color': const Color(0xFF9C27B0)},
    ];

    return Row(
      children: statuses.map((s) {
        final active = _status == s['key'];
        final color = s['color'] as Color;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: s['key'] == 'visited' ? 0 : 6,
              right: s['key'] == 'planned' ? 0 : 6,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _status = s['key'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: active ? color.withAlpha(30) : LoveGirlTheme.bgLight,
                  border: Border.all(
                    color: active ? color : Colors.black.withAlpha(15),
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  s['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active ? color : LoveGirlTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 位置选择器
  Widget _buildLocationPicker() {
    final hasLocation = _lat != 0 || _lng != 0;

    return GestureDetector(
      onTap: _openMapPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: LoveGirlTheme.bgLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withAlpha(15)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.map,
              size: 20,
              color: hasLocation ? LoveGirlTheme.primary : LoveGirlTheme.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '地图位置',
                    style: const TextStyle(fontSize: 12, color: LoveGirlTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  if (hasLocation)
                    Text(
                      _selectedAddress.isNotEmpty
                          ? _selectedAddress
                          : '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: LoveGirlTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text(
                      '点击在地图上选择位置',
                      style: TextStyle(
                        fontSize: 14,
                        color: LoveGirlTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              hasLocation ? Icons.check_circle : Icons.chevron_right,
              size: 20,
              color: hasLocation ? const Color(0xFF4CAF50) : LoveGirlTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
