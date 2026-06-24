import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/services/log_service.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:lovegirl_flutter/utils/constants.dart';
import 'package:intl/intl.dart';

/// 添加/编辑旅行地点的全屏表单页面
class TravelFormScreen extends StatefulWidget {
  /// 传入已有地点为编辑模式，null 为新建模式
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

  // 构造存储
  final _tagsCtrl = TextEditingController();
  final _moodCtrl = TextEditingController();

  String _status = 'visited';
  int _rating = 0;
  int _desire = 1;
  String? _visitedDate;
  String? _plannedDate;
  String _emoji = '📍';
  int _selectedIconIndex = 0;
  final List<String> _tags = [];
  List<String> _photos = [];
  bool _saving = false;
  bool _locating = false;

  // 经纬度
  double _lat = 0;
  double _lng = 0;

  bool get _isEditing => widget.spot != null;

  @override
  void initState() {
    super.initState();
    final s = widget.spot;
    if (s != null) {
      _nameCtrl.text = s.name;
      _cityCtrl.text = s.city;
      _addressCtrl.text = s.address;
      _emoji = s.emoji;
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
      _moodCtrl.text = s.mood ?? '';
      _tags.addAll(s.tags);
      _photos = List.from(s.photos);
      _lat = s.lat;
      _lng = s.lng;
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
    _tagsCtrl.dispose();
    _moodCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isVisited}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: LoveGirlTheme.primary,
                ),
          ),
          child: child!,
        );
      },
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (file == null) return;

      // 上传图片到服务器
      final api = ApiService();
      try {
        final res = await api.upload('/api/travel/upload', file.path);
        final data = res.data?['data'];
        final url = data is Map ? (data['url'] as String?) : null;
        if (url != null && url.isNotEmpty) {
          setState(() => _photos.add(url));
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('图片上传失败，请重试'), behavior: SnackBarBehavior.floating),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: $e'), behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择图片失败'), behavior: SnackBarBehavior.floating),
        );
      }
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

    // 解析标签
    if (_tagsCtrl.text.trim().isNotEmpty) {
      final parsed = _tagsCtrl.text
          .split(RegExp(r'[,，、\s]+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      _tags.addAll(parsed.where((t) => !_tags.contains(t)));
    }

    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'emoji': _emoji,
      'status': _status,
      'lng': _lng,
      'lat': _lat,
      'note': _noteCtrl.text.trim(),
      'tags': _tags,
      'mood': _moodCtrl.text.trim(),
    };

    switch (_status) {
      case 'visited':
        data['visited_date'] = _visitedDate;
        data['rating'] = _rating;
        data['diary'] = _diaryCtrl.text.trim();
        data['photos'] = _photos;
        data['mood'] = _moodCtrl.text.trim();
        break;
      case 'wish':
        data['reason'] = _reasonCtrl.text.trim();
        data['desire'] = _desire;
        break;
      case 'planned':
        data['planned_date'] = _plannedDate;
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
                    style: TextButton.styleFrom(
                      foregroundColor: LoveGirlTheme.primary,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // ======== Emoji 选择器 ========
            _buildSection('地点图标', [
              _buildEmojiPicker(),
            ]),

            // ======== 基本信息 ========
            _buildSection('基本信息', [
              _buildTextField(
                controller: _nameCtrl,
                label: '地点名称',
                hint: '例如：故宫博物院',
                required: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入地点名称' : null,
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
              const SizedBox(height: 16),
              // 定位信息
              _buildLocationSection(),
            ]),

            const SizedBox(height: 8),

            // ======== 状态切换 ========
            _buildSection('旅行状态', [
              _buildStatusToggle(),
            ]),

            const SizedBox(height: 8),

            // ======== 状态专属字段 ========
            if (_status == 'visited') _buildVisitedFields(),
            if (_status == 'wish') _buildWishFields(),
            if (_status == 'planned') _buildPlannedFields(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ==================== Visited 专属字段 ====================
  Widget _buildVisitedFields() {
    return Column(
      children: [
        _buildSection('旅行回忆', [
          // 去的日期
          _buildDateTile(
            icon: Icons.calendar_today,
            label: '去的日期',
            value: _visitedDate,
            onTap: () => _pickDate(isVisited: true),
          ),
          const SizedBox(height: 16),

          // 评分
          const Text('评分', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
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
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // 心情
          _buildTextField(
            controller: _moodCtrl,
            label: '心情',
            hint: '例如：开心、感动、浪漫',
          ),
          const SizedBox(height: 16),

          // 照片
          const Text('照片', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 8),
          _buildPhotoGrid(),
          const SizedBox(height: 16),

          // 游记
          _buildTextField(
            controller: _diaryCtrl,
            label: '游记日记',
            hint: '写下你们的旅行故事...',
            maxLines: 5,
          ),
          const SizedBox(height: 16),

          // 标签
          _buildTextField(
            controller: _tagsCtrl,
            label: '标签（逗号分隔）',
            hint: '例如：第一次, 必去, 情侣',
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => setState(() => _tags.remove(t)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
        ]),
      ],
    );
  }

  // ==================== Wish 专属字段 ====================
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
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final idx = i + 1;
          return GestureDetector(
            onTap: () => setState(() => _desire = idx),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 32.0 - (3 - _desire) * 4.0,
                color: idx <= _desire ? LoveGirlTheme.orange : LoveGirlTheme.textMuted.withAlpha(77),
              ),
            ),
          );
        }),
      ),
    ]);
  }

  // ==================== Planned 专属字段 ====================
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

  // ==================== 定位信息 ====================
  Widget _buildLocationSection() {
    final hasLocation = _lat != 0 || _lng != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('定位信息',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            const Spacer(),
            // GPS定位按钮
            GestureDetector(
              onTap: _locating ? null : _getCurrentLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: LoveGirlTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_locating)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: LoveGirlTheme.primary),
                      )
                    else
                      const Icon(Icons.my_location,
                          size: 14, color: LoveGirlTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      _locating ? '定位中...' : 'GPS定位',
                      style: const TextStyle(
                        fontSize: 12,
                        color: LoveGirlTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 经纬度显示/输入
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: TextEditingController(
                    text: _lat != 0 ? _lat.toStringAsFixed(6) : ''),
                label: '纬度 (lat)',
                hint: '例如：39.9042',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final val = double.tryParse(v);
                  if (val != null) _lat = val;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: TextEditingController(
                    text: _lng != 0 ? _lng.toStringAsFixed(6) : ''),
                label: '经度 (lng)',
                hint: '例如：116.4074',
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final val = double.tryParse(v);
                  if (val != null) _lng = val;
                },
              ),
            ),
          ],
        ),
        if (hasLocation) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    size: 16, color: Color(0xFF4CAF50)),
                const SizedBox(width: 6),
                Text(
                  '已定位: ${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!hasLocation) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LoveGirlTheme.orange.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: LoveGirlTheme.orange),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '未定位，地点将不会显示在地图上。请点击GPS定位或手动输入经纬度。',
                    style: TextStyle(
                      fontSize: 12,
                      color: LoveGirlTheme.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 获取当前GPS位置
  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);
    try {
      // 使用简单的HTTP请求获取IP定位
      final api = ApiService();
      final res = await api.get('/api/weather', query: {'city': 'auto'});
      final data = res.data?['data'];
      if (data is Map) {
        // 尝试从天气API获取位置信息
        // 如果有经纬度字段就使用，否则使用默认值
        final lat = data['lat'] ?? data['latitude'];
        final lng = data['lng'] ?? data['longitude'];
        if (lat != null && lng != null) {
          setState(() {
            _lat = double.tryParse(lat.toString()) ?? 0;
            _lng = double.tryParse(lng.toString()) ?? 0;
          });
          LogService().userAction('旅行:GPS定位成功 $_lat,$_lng');
        } else {
          // 使用城市名称提示用户手动输入
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('无法自动获取经纬度，请手动输入'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      LogService().error('Travel', 'GPS定位失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('定位失败，请手动输入经纬度'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _locating = false);
  }

  // ==================== 通用构建方法 ====================

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LoveGirlTheme.cardLight,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
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
    String? Function(String?)? validator,
    void Function(String)? onChanged,
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
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: LoveGirlTheme.textMuted.withAlpha(150), fontSize: 14),
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
          style: const TextStyle(fontSize: 15),
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
                      fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
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
      {'key': 'visited', 'label': '已打卡', 'color': LoveGirlTheme.visited},
      {'key': 'wish', 'label': '心愿单', 'color': LoveGirlTheme.wish},
      {'key': 'planned', 'label': '计划中', 'color': LoveGirlTheme.planned},
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

  static const _spotIcons = <IconData>[
    Icons.location_on_rounded,
    Icons.beach_access_rounded,
    Icons.terrain_rounded,
    Icons.account_balance_rounded,
    Icons.attractions_rounded,
    Icons.castle_rounded,
    Icons.water_rounded,
    Icons.nature_rounded,
    Icons.volcano_rounded,
    Icons.fort_rounded,
    Icons.park_rounded,
    Icons.mosque_rounded,
    Icons.tour_rounded,
    Icons.landscape_rounded,
    Icons.cabin_rounded,
    Icons.construction_rounded,
    Icons.hotel_rounded,
    Icons.temple_buddhist_rounded,
  ];

  Widget _buildEmojiPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(_spotIcons.length, (i) {
        final icon = _spotIcons[i];
        final selected = i == _selectedIconIndex;
        return GestureDetector(
          onTap: () => setState(() {
            _selectedIconIndex = i;
            _emoji = 'location_$i'; // store index as emoji for backward compat
          }),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? LoveGirlTheme.primary.withAlpha(30)
                  : LoveGirlTheme.bgLight,
              border: Border.all(
                color: selected ? LoveGirlTheme.primary : Colors.black.withAlpha(15),
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(icon, size: 20, color: selected ? LoveGirlTheme.primary : LoveGirlTheme.textSecondary),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPhotoGrid() {
    if (_photos.isEmpty) {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: LoveGirlTheme.bgLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withAlpha(15), style: BorderStyle.solid),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_photo_alternate_outlined, size: 32, color: LoveGirlTheme.textMuted.withAlpha(150)),
                const SizedBox(height: 4),
                Text('添加照片', style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted.withAlpha(180))),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == _photos.length) {
                return GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: LoveGirlTheme.bgLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black.withAlpha(15)),
                    ),
                    child: Center(
                      child: Icon(Icons.add, size: 28, color: LoveGirlTheme.textMuted.withAlpha(150)),
                    ),
                  ),
                );
              }
              final photo = _photos[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    if (photo.startsWith('http'))
                      Image.network(photo, width: 100, height: 100, fit: BoxFit.cover)
                    else
                      Image.file(File(photo), width: 100, height: 100, fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _photos.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
