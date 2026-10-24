import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/travel.dart' show TravelSpot;
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import 'map_platform.dart';
import 'place_picker.dart';
import 'travel_workspace.dart';

class TravelPlaceEditor extends StatefulWidget {
  final TravelSpot? spot;
  final TravelSpot? prefill;
  final PlaceChoice? choice;
  final bool gpsPrefill;
  final ApiService? api;
  const TravelPlaceEditor(
      {super.key,
      this.spot,
      this.prefill,
      this.choice,
      this.gpsPrefill = false,
      this.api});
  @override
  State<TravelPlaceEditor> createState() => _TravelPlaceEditorState();
}

class _TravelPlaceEditorState extends State<TravelPlaceEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _story = TextEditingController();
  final _budget = TextEditingController();
  late final ApiService _api = widget.api ?? ApiService();
  double? _lat;
  double? _lng;
  String _status = 'wish';
  String? _visitedDate;
  String? _plannedDate;
  String? get _date => _status == 'planned' ? _plannedDate : _visitedDate;
  set _date(String? value) {
    if (_status == 'planned') {
      _plannedDate = value;
    } else {
      _visitedDate = value;
    }
  }

  String? _weather;
  String? _mood;
  String? _error;
  bool _busy = false;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    final original = widget.spot ?? widget.prefill;
    final choice = widget.choice;
    _name.text = widget.spot?.name ?? choice?.name ?? original?.name ?? '';
    _city.text = original?.city ?? choice?.city ?? '';
    _address.text = original?.address ?? choice?.address ?? '';
    _story.text = original?.diary ?? '';
    _budget.text = original?.budget?.toString() ?? '';
    _status = original?.status ?? 'wish';
    _visitedDate = original?.visitedDate;
    _plannedDate = original?.plannedDate;
    if (widget.spot == null &&
        _status != 'wish' &&
        (_date == null || _date!.isEmpty)) {
      _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    _weather = original?.weather;
    _mood = original?.mood;
    if (original != null && hasMapPosition(original)) {
      _lat = original.lat;
      _lng = original.lng;
    } else if (choice != null) {
      _lat = choice.lat;
      _lng = choice.lng;
    }
    if (widget.gpsPrefill && _lat != null && _lng != null) {
      _converting = true;
      _convertGps(_lat!, _lng!);
    } else if (_lat != null && _city.text.isEmpty) {
      _fillAddress(_lat!, _lng!);
    }
  }

  Future<void> _convertGps(double lat, double lng) async {
    try {
      final point = await TravelMapPlatform.fromGps(lat, lng);
      if (!mounted) return;
      setState(() {
        _lat = point.latitude;
        _lng = point.longitude;
        _converting = false;
      });
      _fillAddress(point.latitude, point.longitude);
    } catch (_) {
      if (mounted) {
        setState(() {
          _lat = null;
          _lng = null;
          _converting = false;
          _error = '照片位置暂时不能转换，请重新选择位置';
        });
      }
    }
  }

  Future<void> _fillAddress(double lat, double lng) async {
    try {
      final response = await _api.regeoAmap(lat, lng);
      if (!mounted || _lat != lat || _lng != lng) return;
      final data = response.data?['data'];
      if (data is Map) {
        if (_city.text.isEmpty) _city.text = data['city']?.toString() ?? '';
        if (_address.text.isEmpty) {
          _address.text = data['address']?.toString() ?? '';
        }
      }
    } catch (_) {/* City and address can be entered manually. */}
  }

  Future<void> _chooseLocation() async {
    final choice = await Navigator.of(context).push<PlaceChoice>(
        MaterialPageRoute(
            builder: (_) => TravelPlacePicker(
                api: _api,
                initial: _lat != null
                    ? PlaceChoice(
                        name: _name.text,
                        city: _city.text,
                        address: _address.text,
                        lat: _lat!,
                        lng: _lng!)
                    : null)));
    if (choice == null || !mounted) return;
    setState(() {
      _lat = choice.lat;
      _lng = choice.lng;
      if (_name.text.trim().isEmpty) _name.text = choice.name;
      if (choice.city.isNotEmpty) _city.text = choice.city;
      _address.text = choice.address;
      _error = null;
    });
    _fillAddress(choice.lat, choice.lng);
  }

  Future<void> _chooseDate() async {
    final parsed = DateTime.tryParse((_date ?? '').split('T').first);
    final value = await showDatePicker(
        context: context,
        builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: context.lgInk, onPrimary: context.lgPaper)),
            child: child!),
        initialDate: parsed ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100, 12, 31));
    if (value != null && mounted) {
      setState(() => _date = DateFormat('yyyy-MM-dd').format(value));
    }
  }

  Future<void> _save() async {
    if (_busy || _converting || !_form.currentState!.validate()) return;
    if (_lat == null && widget.spot == null) {
      setState(() => _error = '请先在地图上选择位置');
      return;
    }
    final budget = double.tryParse(_budget.text.trim());
    if (_budget.text.trim().isNotEmpty &&
        (budget == null || !budget.isFinite || budget < 0)) {
      setState(() => _error = '预算请输入有效的非负金额');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final original = widget.spot;
    final payload = placeWriteData(
        original: original,
        name: _name.text,
        city: _city.text,
        address: _address.text,
        lat: _lat ?? 0,
        lng: _lng ?? 0,
        status: _status,
        diary: _story.text,
        visitedDate:
            original == null && _status != 'visited' ? null : _visitedDate,
        plannedDate:
            original == null && _status != 'planned' ? null : _plannedDate,
        weather: _weather,
        mood: _mood)
      ..['budget'] = budget;
    try {
      int id;
      if (original != null) {
        await _api.updateTravelSpot(original.id, payload);
        id = original.id;
      } else {
        final result = await _api.createTravelSpot(payload);
        id = int.parse(result.data['data']['id'].toString());
      }
      final snapshot = TravelSpot.fromJson({
        ...payload,
        'id': id,
        'photos': original?.photos ?? [],
        'coverImage': original?.coverImage,
        'noteMine': original?.noteMine,
        'noteHer': original?.noteHer,
        'businessHours': original?.businessHours,
        'pinned': original?.pinned ?? 0,
        'createdBy': original?.createdBy,
        'editedByBoth': original?.editedByBoth ?? false,
        'routeId': original?.routeId,
        'routeDay': original?.routeDay,
        'routeOrder': original?.routeOrder,
      });
      if (mounted) Navigator.pop(context, snapshot);
    } catch (failure) {
      if (mounted) {
        setState(() => _error =
            extractServerMessage(failure, fallback: '保存失败，输入已经保留，请重试'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _story.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_busy,
        child: Scaffold(
          backgroundColor: context.lgBg,
          appBar: AppBar(
              systemOverlayStyle: context.lgIsDark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              title: Text(widget.spot == null ? '记下地点' : '编辑地点')),
          body: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!,
                          style: const TextStyle(color: LoveGirlTheme.red))),
                TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                        labelText: '地点名称', hintText: '这是什么地方？'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '请输入地点名称' : null),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: context.lgInk),
                    onPressed: _busy || _converting ? null : _chooseLocation,
                    icon: const Icon(Icons.place_outlined),
                    label: Text(_converting
                        ? '正在确认照片位置'
                        : _lat == null
                            ? '在地图上选择位置'
                            : '已选择位置 · 点此调整')),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _city,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: '城市'),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? '请填写城市' : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _address,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: '地址（可选）')),
                const SizedBox(height: 20),
                Wrap(spacing: 8, children: [
                  for (final state in [
                    ('wish', '想去'),
                    ('planned', '计划中'),
                    ('visited', '已去')
                  ])
                    ChoiceChip(
                        showCheckmark: false,
                        selectedColor: context.lgInk,
                        backgroundColor: context.lgPaper,
                        labelStyle: TextStyle(
                            color: _status == state.$1
                                ? context.lgPaper
                                : context.lgInk),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: context.lgSeparator),
                        label: Text(state.$2),
                        selected: _status == state.$1,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() {
                                  _status = state.$1;
                                  if (widget.spot == null &&
                                      _status != 'wish') {
                                    _date ??= DateFormat('yyyy-MM-dd')
                                        .format(DateTime.now());
                                  }
                                })),
                ]),
                if (_status != 'wish')
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_status == 'planned' ? '计划日期' : '到访日期'),
                      subtitle: Text((_date ?? '未填写').split('T').first),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _busy ? null : _chooseDate),
                const SizedBox(height: 16),
                TextFormField(
                    controller: _story,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 8,
                    decoration:
                        const InputDecoration(labelText: '照片背后的故事（可选）')),
                ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('更多记录'),
                    children: [
                      TextFormField(
                          controller: _budget,
                          enabled: !_busy,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: '预算（可选）',
                              helperText: '仅记录预算，不自动记为支出')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          value: _weather,
                          decoration: const InputDecoration(labelText: '天气'),
                          items: {
                            if (_weather != null) _weather!,
                            '晴天',
                            '多云',
                            '雨天',
                            '雪天',
                            '夜晚',
                            '彩虹'
                          }
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _weather = value)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          value: _mood,
                          decoration: const InputDecoration(labelText: '心情'),
                          items: {
                            if (_mood != null) _mood!,
                            '甜蜜',
                            '开心',
                            '兴奋',
                            '平静',
                            '感动',
                            '酷'
                          }
                              .map((value) => DropdownMenuItem(
                                  value: value, child: Text(value)))
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) => setState(() => _mood = value)),
                    ]),
              ])),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: context.lgInk,
                          foregroundColor: context.lgPaper),
                      onPressed: _busy || _converting ? null : _save,
                      child: Text(_busy ? '正在保存…' : '保存地点')))),
        ));
  }
}
