import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lovegirl_flutter/providers/travel_provider.dart';
import 'package:lovegirl_flutter/screens/travel/map_picker_screen.dart';
import 'package:lovegirl_flutter/services/api_service.dart';
import 'package:lovegirl_flutter/widgets/city_picker.dart';
import 'package:lovegirl_flutter/widgets/travel_photo_grid.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_icon.dart';

/// 添加/编辑旅行地点 — 完整表单
class TravelFormScreen extends StatefulWidget {
  final TravelSpot? spot;

  const TravelFormScreen({super.key, this.spot});

  @override
  State<TravelFormScreen> createState() => _TravelFormScreenState();
}

class _TravelFormScreenState extends State<TravelFormScreen> {
  final _formScroll = ScrollController();
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _noteCtrl = TextEditingController();
  final _diaryCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _itineraryCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _transportationCtrl = TextEditingController();
  final _nearbyCtrl = TextEditingController();
  final _tipsCtrl = TextEditingController();

  String _city = '';
  String _status = 'visited';
  int _rating = 0;
  String? _visitedDate;
  String? _plannedDate;
  String _weather = '';
  String _mood = '';
  double _lat = 0;
  double _lng = 0;
  String _address = '';
  double? _cityFocusLat;
  double? _cityFocusLng;
  String? _nameError;
  String? _cityError;
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
      _transportationCtrl.text = s.transportation ?? '';
      _nearbyCtrl.text = s.nearby ?? '';
      _tipsCtrl.text = s.tips ?? '';
      _lat = s.lat;
      _lng = s.lng;
      _address = s.address;
    }
  }

  @override
  void dispose() {
    _formScroll.dispose();
    _nameFocus.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _diaryCtrl.dispose();
    _budgetCtrl.dispose();
    _itineraryCtrl.dispose();
    _reasonCtrl.dispose();
    _transportationCtrl.dispose();
    _nearbyCtrl.dispose();
    _tipsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final city = await showCityPicker(context, currentCity: _city);
    if (city == null) return;
    setState(() {
      _city = city;
      _cityError = null;
    });
    // 后台解析城市中心坐标：进选点页直接落到该城市，不用在中国地图上找
    if (_lat == 0 && _lng == 0) {
      try {
        final res = await ApiService().geocodeAmap(city);
        final data = res.data?['data'];
        if (data is Map && mounted) {
          setState(() {
            _cityFocusLat = (data['lat'] as num?)?.toDouble();
            _cityFocusLng = (data['lng'] as num?)?.toDouble();
          });
        }
      } catch (_) {
        // 编码失败则选点页退化为全国视角
      }
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _lat == 0 ? null : _lat,
          initialLng: _lng == 0 ? null : _lng,
          focusLat: _cityFocusLat,
          focusLng: _cityFocusLng,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _lat = (result['lat'] as num?)?.toDouble() ?? _lat;
      _lng = (result['lng'] as num?)?.toDouble() ?? _lng;
      _address = result['address']?.toString() ?? _address;
      final name = result['name']?.toString() ?? '';
      final city = result['city']?.toString() ?? '';
      if (_nameCtrl.text.trim().isEmpty && name.isNotEmpty) {
        _nameCtrl.text = name;
      }
      if (city.isNotEmpty) {
        _city = city;
      }
    });
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
      // 行内校验：字段红框+错误文案+滚回字段处（底部 snackbar 会被键盘挡住）
      setState(() => _nameError = '请输入地点名称');
      FocusScope.of(context).requestFocus(_nameFocus);
      if (_formScroll.hasClients) {
        _formScroll.animateTo(0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut);
      }
      HapticFeedback.selectionClick();
      return;
    }
    if (_city.isEmpty) {
      setState(() => _cityError = '请选择城市');
      if (_formScroll.hasClients) {
        _formScroll.animateTo(0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut);
      }
      HapticFeedback.selectionClick();
      return;
    }
    if (_nameError != null || _cityError != null) {
      setState(() {
        _nameError = null;
        _cityError = null;
      });
    }

    setState(() => _saving = true);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'city': _city,
      'address': _address,
      'status': _status,
      'emoji': _statusEmoji,
      'note': _noteCtrl.text.trim(),
      'transportation': _transportationCtrl.text.trim(),
      'nearby': _nearbyCtrl.text.trim(),
      'tips': _tipsCtrl.text.trim(),
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

    if (_lat != 0 || _lng != 0) {
      data['lat'] = _lat;
      data['lng'] = _lng;
    }

    try {
      if (!mounted) return;
      final provider = context.read<TravelProvider>();
      if (_isEditing) {
        await provider.updateSpot(widget.spot!.id, data);
      } else {
        await provider.createSpot(data);
      }

      // 同步写入记账模块：预算 > 0 时自动创建旅行花费记录
      final budgetValue = budgetText.isNotEmpty ? double.tryParse(budgetText) : null;
      if (budgetValue != null && budgetValue > 0) {
        try {
          await ApiService().addFinanceRecord({
            'type': 'expense',
            'category': '旅行',
            'amount': budgetValue,
            'recordDate': _visitedDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'description': '${_nameCtrl.text.trim()}（$_city）',
            'source': 'travel',
          });
        } catch (_) {
          // 记账同步失败不阻断旅行保存流程
        }
      }

      if (mounted) {
        if (_status == 'visited') {
          // 打卡仪式感：票根印章落下 + 彩带 + 震动
          await _playCheckInStamp();
          if (!mounted) return;
        }
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
        final msg = extractServerMessage(e, fallback: '保存失败，请重试');
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

  Future<void> _playCheckInStamp() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (_) => const _CheckInStampOverlay(),
    );
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
          icon: AppIcon('close'),
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
        controller: _formScroll,
        padding: const EdgeInsets.all(16),
        children: [
          // 地点名称
          _label('地点名称', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            onChanged: (v) {
              if (_nameError != null && v.trim().isNotEmpty) {
                setState(() => _nameError = null);
              }
            },
            decoration:
                _inputDecoration('例如：故宫博物院').copyWith(errorText: _nameError),
          ),
          const SizedBox(height: 16),

          // 城市
          _label('城市', required: true),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickCity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.lgBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _cityError != null
                          ? LoveGirlTheme.red
                          : Colors.black.withAlpha(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_city,
                          size: 20, color: context.lgTextMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _city.isEmpty ? '点击选择城市' : _city,
                          style: TextStyle(
                            fontSize: 15,
                            color: _city.isEmpty
                                ? context.lgTextMuted
                                : context.lgTextPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          size: 20, color: context.lgTextMuted),
                    ],
                  ),
                ),
                if (_cityError != null) ...[
                  const SizedBox(height: 6),
                  Text(_cityError!,
                      style: const TextStyle(
                          color: LoveGirlTheme.red, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          _label('地图位置'),
          const SizedBox(height: 6),
          _locationPickerTile(),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.lgBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black.withAlpha(15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 18, color: context.lgInk),
                    const SizedBox(width: 10),
                    Text(
                      _visitedDate ?? '点击选择日期（默认今天）',
                      style: TextStyle(
                        fontSize: 15,
                        color: _visitedDate != null
                            ? context.lgTextPrimary
                            : context.lgTextMuted,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? context.lgInk.withAlpha(20)
                          : context.lgBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: active
                            ? context.lgInk
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Text('${w['emoji']} ${w['label']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: active
                              ? context.lgInk
                              : context.lgTextSecondary,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? context.lgInk.withAlpha(20)
                          : context.lgBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: active
                            ? context.lgInk
                            : Colors.black.withAlpha(10),
                      ),
                    ),
                    child: Text('${m['emoji']} ${m['label']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: active
                              ? context.lgInk
                              : context.lgTextSecondary,
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
                          : context.lgTextMuted,
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
            SizedBox(height: 16),
          ],

          // ===== 心愿单专属 =====
          if (_status == 'wish') ...[
            _sectionTitle('心愿详情'),
            SizedBox(height: 12),
            _label('想去的理由'),
            SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              maxLines: 3,
              decoration: _inputDecoration('为什么想去这里？'),
            ),
            SizedBox(height: 16),
          ],

          // ===== 规划中专属 =====
          if (_status == 'planned') ...[
            _sectionTitle('规划详情'),
            SizedBox(height: 12),
            _label('计划日期'),
            SizedBox(height: 6),
            GestureDetector(
              onTap: _pickPlannedDate,
              child: Container(
                width: double.infinity,
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: context.lgBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black.withAlpha(15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 18, color: Color(0xFF9C27B0)),
                    SizedBox(width: 10),
                    Text(
                      _plannedDate ?? '点击选择计划日期',
                      style: TextStyle(
                        fontSize: 15,
                        color: _plannedDate != null
                            ? context.lgTextPrimary
                            : context.lgTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            _label('行程安排'),
            SizedBox(height: 6),
            TextField(
              controller: _itineraryCtrl,
              maxLines: 4,
              decoration: _inputDecoration('Day1: ...\nDay2: ...'),
            ),
            SizedBox(height: 16),
          ],

          // ===== 预算（所有状态通用） =====
          _sectionTitle('其他信息'),
          SizedBox(height: 12),

          _label('预算（元）'),
          SizedBox(height: 6),
          TextField(
            controller: _budgetCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            decoration: _inputDecoration('例如：5000').copyWith(
              prefixIcon: Icon(Icons.account_balance_wallet_outlined,
                  size: 20, color: context.lgTextMuted),
            ),
          ),
          const SizedBox(height: 16),

          _label('交通方式'),
          const SizedBox(height: 6),
          TextField(
            controller: _transportationCtrl,
            decoration: _inputDecoration('地铁 / 打车 / 步行路线'),
          ),
          const SizedBox(height: 16),

          _label('附近推荐'),
          const SizedBox(height: 6),
          TextField(
            controller: _nearbyCtrl,
            decoration: _inputDecoration('附近餐厅、景点或停车点'),
          ),
          const SizedBox(height: 16),

          _label('小提示'),
          SizedBox(height: 6),
          TextField(
            controller: _tipsCtrl,
            maxLines: 2,
            decoration: _inputDecoration('预约、营业时间或注意事项'),
          ),
          SizedBox(height: 16),

          // 备注
          _label('备注'),
          SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: _inputDecoration('补充说明...'),
          ),
          SizedBox(height: 20),

          // ===== 照片管理（编辑模式） =====
          if (_isEditing) ...[
            _sectionTitle('照片'),
            SizedBox(height: 12),
            TravelPhotoGrid(
              spotId: widget.spot!.id,
              editable: true,
            ),
            SizedBox(height: 20),
          ],

          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _locationPickerTile() {
    final hasLocation = _lat != 0 || _lng != 0;
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.lgBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withAlpha(15)),
        ),
        child: Row(
          children: [
            Icon(
              hasLocation ? Icons.location_on_rounded : Icons.add_location_alt,
              size: 20,
              color:
                  hasLocation ? context.lgInk : context.lgTextMuted,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation ? '已选择地图位置' : '点击搜索或在地图上选点',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasLocation
                          ? context.lgTextPrimary
                          : context.lgTextMuted,
                    ),
                  ),
                  if (hasLocation) ...[
                    SizedBox(height: 3),
                    Text(
                      _address.isNotEmpty
                          ? _address
                          : '${_lat.toStringAsFixed(6)}, ${_lng.toStringAsFixed(6)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.lgTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: context.lgTextMuted),
          ],
        ),
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
            color: context.lgInk,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.lgTextSecondary)),
      ],
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        if (required)
          const Text(' *', style: TextStyle(color: Colors.red, fontSize: 14)),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.lgTextMuted.withAlpha(150)),
      filled: true,
      fillColor: context.lgBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.black.withAlpha(15)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.black.withAlpha(15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.lgInk, width: 1.5),
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
          color: active ? color.withAlpha(30) : context.lgBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? color : Colors.black.withAlpha(10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: active ? color : context.lgTextSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// 打卡成功印章动画：票根印章落下 + 彩带 + 触觉震动
class _CheckInStampOverlay extends StatefulWidget {
  const _CheckInStampOverlay();

  @override
  State<_CheckInStampOverlay> createState() => _CheckInStampOverlayState();
}

class _CheckInStampOverlayState extends State<_CheckInStampOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  late final List<Offset> _directions;
  late final List<Color> _confettiColors;

  @override
  void initState() {
    super.initState();
    final rng = Random(7);
    _directions = List.generate(28, (i) {
      final angle = (i / 28) * 2 * pi + rng.nextDouble() * 0.3;
      final speed = 0.55 + rng.nextDouble() * 0.5;
      return Offset(cos(angle) * speed, sin(angle) * speed - 0.2);
    });
    _confettiColors = [
      context.lgInk,
      LoveGirlTheme.orange,
      LoveGirlTheme.secondary,
      LoveGirlTheme.red,
      LoveGirlTheme.accent,
    ];
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1750), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final drop = Curves.easeInCubic
              .transform((t / 0.28).clamp(0.0, 1.0).toDouble());
          var scale = 2.6 - (2.6 - 0.94) * drop;
          if (t > 0.28) {
            final settle = (t - 0.28) / 0.72;
            scale = 0.94 + 0.06 * Curves.elasticOut.transform(settle);
          }
          final opacity = (t / 0.18).clamp(0.0, 1.0).toDouble();
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  progress: t,
                  directions: _directions,
                  colors: _confettiColors,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -0.32,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withAlpha(235),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withAlpha(70),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          child: const Text(
                            '已打卡 ♥',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: AlwaysStoppedAnimation(
                        ((t - 0.4) / 0.3).clamp(0.0, 1.0).toDouble()),
                    child: const Column(
                      children: [
                        Text('打卡成功',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        SizedBox(height: 6),
                        Text('这枚票根已经收进回忆里',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<Offset> directions;
  final List<Color> colors;

  _ConfettiPainter({
    required this.progress,
    required this.directions,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.24) return;
    final t = ((progress - 0.24) / 0.76).clamp(0.0, 1.0).toDouble();
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final paint = Paint();
    for (var i = 0; i < directions.length; i++) {
      final dir = directions[i];
      final dist = pow(t, 1.6).toDouble() * size.width * 0.36;
      final pos = center + Offset(dir.dx * dist, dir.dy * dist + t * 60);
      final particleSize = 7.0 * (1 - t * 0.55);
      paint.color = colors[i % colors.length]
          .withAlpha((1 - t).clamp(0.0, 1.0).toInt() * 255);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate((i * 1.7) + t * 5);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particleSize,
        height: particleSize * (i.isEven ? 1.8 : 0.7),
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
