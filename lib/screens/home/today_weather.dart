import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/glass_feature_icon.dart';
import '../../widgets/rebuild_controls.dart';
import 'package:lovegirl_flutter/widgets/glass_routes.dart';
class TodayWeather extends StatefulWidget {
  final ApiService api;
  const TodayWeather({super.key, required this.api});

  @override
  State<TodayWeather> createState() => _TodayWeatherState();
}

class _TodayWeatherState extends State<TodayWeather> {
  static const _cityPreference = 'weather_city';
  String? _city;
  Map<String, dynamic>? _weather;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? selection}) async {
    final request = ++_request;
    if (selection != null) {
      setState(() {
        _city = selection;
        _weather = null;
      });
    }
    setState(() => _loading = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (selection != null) {
        await preferences.setString(_cityPreference, selection);
      }
      final city = selection ?? preferences.getString(_cityPreference)?.trim();
      if (!mounted || request != _request || city == null || city.isEmpty) {
        return;
      }
      setState(() => _city = city);
      final response = await widget.api
          .getTodayWeather(city)
          .timeout(const Duration(seconds: 8));
      final data = response.data?['data'];
      if (!mounted || request != _request) return;
      setState(() {
        _weather = data is Map<String, dynamic> &&
                (data['temp'] ??
                        data['temperature'] ??
                        data['weather'] ??
                        data['condition']) !=
                    null
            ? data
            : null;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _weather = null);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  String? get _temperature {
    final text = (_weather?['temp'] ?? _weather?['temperature'])?.toString();
    if (text == null || text.isEmpty) return null;
    return text.contains('°') ? text : '$text°';
  }

  Future<void> _chooseCity() async {
    final city = await showCityPicker(context, currentCity: _city);
    if (mounted && city != null && city.trim().isNotEmpty) {
      await _load(selection: city.trim());
    }
  }

  Future<void> _showDetails() async {
    if (_city == null) {
      await _chooseCity();
      return;
    }
    final action = await showGlassSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        top: false,
        child: RebuildGlass(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_city!}天气',
                    style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  _weather == null
                      ? '暂时未能读取天气'
                      : [
                          (_weather?['weather'] ?? _weather?['condition'])
                              ?.toString(),
                          _temperature
                        ].whereType<String>().join(' · '),
                  style: TextStyle(color: sheet.lgTextSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheet, 'city'),
                      child: const Text('切换城市'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheet, 'refresh'),
                      child: Text(_weather == null ? '重试' : '刷新'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'city') await _chooseCity();
    if (action == 'refresh') await _load();
  }

  @override
  Widget build(BuildContext context) => RebuildGlassButton(
        label: _temperature ?? (_city == null && !_loading ? '选城市' : '天气'),
        icon: Icons.cloud_outlined,
        iconImage: const GlassFeatureIcon(GlassFeature.weather, size: 24),
        showLabel: true,
        onPressed: _loading ? null : _showDetails,
      );
}
