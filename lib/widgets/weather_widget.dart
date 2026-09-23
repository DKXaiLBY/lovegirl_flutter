import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/log_service.dart';
import '../utils/lovegirl_theme.dart';
import 'city_picker.dart';
import 'lovegirl_ui.dart';

enum WeatherErrorType { permission, location, network, data }

class WeatherWidget extends StatefulWidget {
  final bool compact;

  const WeatherWidget({super.key, this.compact = false});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  static Map<String, dynamic>? _lastWeatherCache;

  // 兜底用持久化：上次定位成功/手动选择过的城市坐标
  static const _prefCity = 'weather_city';
  static const _prefLat = 'weather_lat';
  static const _prefLng = 'weather_lng';

  String? _temperature;
  String? _tempHigh;
  String? _tempLow;
  String? _weather;
  String? _city;
  String? _humidity;
  String? _wind;
  String? _feelsLike;
  bool _loading = true;
  bool _disposed = false;
  WeatherErrorType? _errorType;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    if (_disposed || !mounted) return;
    setState(() {
      _loading = true;
      _errorType = null;
    });

    final data = await _fetchLocationWeather();

    if (!_hasUsableWeather(data)) {
      // 兜底1：定位/权限失败时用上次成功或手动选过的城市坐标查天气
      final fallback = await _fetchSavedCityWeather();
      if (_hasUsableWeather(fallback)) {
        if (_disposed || !mounted) return;
        _lastWeatherCache = Map<String, dynamic>.from(fallback);
        setState(() {
          _applyPayload(fallback);
        });
        return;
      }

      // 兜底2：首次使用（无任何历史城市）→ 默认城市，不让新用户卡在错误态
      final def = await _fetchCityWeather('广州');
      if (_hasUsableWeather(def)) {
        if (_disposed || !mounted) return;
        _lastWeatherCache = Map<String, dynamic>.from(def);
        setState(() {
          _applyPayload(def);
        });
        return;
      }
    }

    if (data.isEmpty || !_hasUsableWeather(data)) {
      if (_restoreFromCache()) return;
      if (!_disposed && mounted) {
        setState(() {
          _loading = false;
          _errorType = _errorType ?? WeatherErrorType.data;
        });
      }
      return;
    }

    if (_disposed || !mounted) return;
    final payload = data;
    _lastWeatherCache = Map<String, dynamic>.from(payload);
    setState(() {
      _applyPayload(payload);
    });
  }

  /// 定位失败时的兜底：用上次成功/手动选过的城市坐标查天气
  Future<Map<String, dynamic>> _fetchSavedCityWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_prefLat);
      final lng = prefs.getDouble(_prefLng);
      if (lat == null || lng == null) return const {};
      final response = await ApiService()
          .get('/api/weather/coords', query: {'lat': lat, 'lng': lng})
          .timeout(const Duration(seconds: 8));
      final payload = _typedMap(response.data?['data']);
      if (!_hasUsableWeather(payload)) return const {};
      final city = prefs.getString(_prefCity);
      if (city != null && city.isNotEmpty && (payload['city'] == null || payload['city'].toString().isEmpty)) {
        payload['city'] = city;
      }
      return payload;
    } catch (e) {
      LogService().error('Weather', '城市兜底天气失败: $e');
      return const {};
    }
  }

  /// 兜底2：默认城市天气（首次使用、无任何历史记录时）
  Future<Map<String, dynamic>> _fetchCityWeather(String city) async {
    try {
      final response = await ApiService()
          .get('/api/weather', query: {'city': city})
          .timeout(const Duration(seconds: 8));
      final payload = _typedMap(response.data?['data']);
      if (!_hasUsableWeather(payload)) return const {};
      payload['city'] = city;
      return payload;
    } catch (e) {
      LogService().error('Weather', '默认城市兜底失败: $e');
      return const {};
    }
  }

  Future<void> _rememberLocation(double lat, double lng, String? city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefLat, lat);
      await prefs.setDouble(_prefLng, lng);
      if (city != null && city.trim().isNotEmpty) {
        await prefs.setString(_prefCity, city.trim());
      }
    } catch (_) {
      // 持久化失败只影响下次兜底，不阻断本次展示
    }
  }

  /// 手动选城市：城市名 → 逆编码拿坐标 → coords 查天气 → 持久化为兜底城市
  Future<void> _pickCityManually() async {
    final city = await showCityPicker(context);
    if (city == null || city.trim().isEmpty || _disposed || !mounted) return;
    final picked = city.trim();

    setState(() {
      _loading = true;
      _errorType = null;
    });
    try {
      final geo = await ApiService().geocodeAmap(picked);
      final d = geo.data?['data'];
      final lat = d is Map ? (d['lat'] as num?)?.toDouble() : null;
      final lng = d is Map ? (d['lng'] as num?)?.toDouble() : null;
      if (lat == null || lng == null) {
        throw Exception('geocode failed');
      }
      final response = await ApiService()
          .get('/api/weather/coords', query: {'lat': lat, 'lng': lng})
          .timeout(const Duration(seconds: 8));
      final payload = _typedMap(response.data?['data']);
      if (!_hasUsableWeather(payload)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorType = WeatherErrorType.data;
        });
        return;
      }
      payload['city'] = picked;
      await _rememberLocation(lat, lng, picked);
      if (_disposed || !mounted) return;
      _lastWeatherCache = Map<String, dynamic>.from(payload);
      setState(() {
        _applyPayload(payload);
      });
    } catch (e) {
      if (_disposed || !mounted) return;
      LogService().error('Weather', '手动选城市失败: $e');
      setState(() {
        _loading = false;
        _errorType = WeatherErrorType.data;
      });
    }
  }

  /// 天气操作面板：权限引导 / 重新定位 / 手动选城市
  Future<void> _showWeatherActions() async {
    final isPermission = _errorType == WeatherErrorType.permission;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetCtx).brightness == Brightness.dark
                ? const Color(0xFF1E1B18)
                : const Color(0xFFFFF8F3),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              if (isPermission)
                ListTile(
                  leading: const Icon(Icons.location_disabled_rounded),
                  title: const Text('去开启定位权限'),
                  subtitle: const Text('开启后自动显示当地天气'),
                  onTap: () => Navigator.pop(sheetCtx, 'settings'),
                ),
              ListTile(
                leading: const Icon(Icons.my_location_rounded),
                title: const Text('重新定位'),
                onTap: () => Navigator.pop(sheetCtx, 'retry'),
              ),
              ListTile(
                leading: const Icon(Icons.location_city_rounded),
                title: const Text('手动选城市'),
                onTap: () => Navigator.pop(sheetCtx, 'city'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (action == null || _disposed || !mounted) return;
    switch (action) {
      case 'settings':
        await Geolocator.openAppSettings();
        break;
      case 'retry':
        await _fetchWeather();
        break;
      case 'city':
        await _pickCityManually();
        break;
    }
  }

  Future<Map<String, dynamic>> _fetchLocationWeather() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!_disposed && mounted) {
        setState(() => _errorType = WeatherErrorType.permission);
      }
      return const {};
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      ).timeout(const Duration(seconds: 6));
      final response = await ApiService()
          .get('/api/weather/coords', query: {'lat': position.latitude, 'lng': position.longitude})
          .timeout(const Duration(seconds: 8));
      final payload = _typedMap(response.data?['data']);
      if (_hasUsableWeather(payload)) {
        // 记住这次成功定位，权限被拒/定位失败时兜底用
        await _rememberLocation(
            position.latitude, position.longitude, payload['city']?.toString());
      }
      return payload;
    } catch (e) {
      if (!_disposed && mounted) {
        setState(() => _errorType = WeatherErrorType.location);
      }
      LogService().error('Weather', '定位天气失败: $e');
      return const {};
    }
  }

  bool _restoreFromCache() {
    final cache = _lastWeatherCache;
    if (cache == null || _disposed || !mounted) return false;
    setState(() {
      _applyPayload(cache);
    });
    return true;
  }

  bool _hasUsableWeather(Map<String, dynamic> payload) {
    final temp = _safeNumberText(payload['temp'] ?? payload['temperature']);
    final weather = payload['weather']?.toString().trim();
    return temp != null ||
        (weather != null &&
            weather.isNotEmpty &&
            weather != '--' &&
            weather != '未知');
  }

  void _applyPayload(Map<String, dynamic> payload) {
    _temperature =
        _safeNumberText(payload['temp'] ?? payload['temperature']) ?? '--';
    _tempHigh = _safeNumberText(payload['tempHigh']);
    _tempLow = _safeNumberText(payload['tempLow']);
    _weather = payload['weather']?.toString() ?? '--';
    _city = payload['city']?.toString() ?? '\u5f53\u524d\u4f4d\u7f6e';
    _humidity = payload['humidity']?.toString();
    _wind = payload['wind']?.toString();
    _feelsLike = _safeNumberText(
      payload['feelsLike'] ??
          payload['feels_like'] ??
          payload['apparentTemperature'] ??
          payload['apparent_temperature'] ??
          payload['realFeel'] ??
          payload['real_feel'],
    );
    _loading = false;
    _errorType = null;
  }

  IconData _iconForWeather(String weather) {
    if (weather.contains('\u6674')) return Icons.wb_sunny_rounded;
    if (weather.contains('\u591a\u4e91')) return Icons.cloud_rounded;
    if (weather.contains('\u9634')) return Icons.cloud_queue_rounded;
    if (weather.contains('\u96f7')) return Icons.thunderstorm_rounded;
    if (weather.contains('\u96e8')) return Icons.water_drop_rounded;
    if (weather.contains('\u96ea')) return Icons.ac_unit_rounded;
    if (weather.contains('\u96fe') || weather.contains('\u973e')) {
      return Icons.cloud_circle_rounded;
    }
    return Icons.wb_cloudy_rounded;
  }

  Color _colorForWeather(String weather) {
    if (weather.contains('\u6674')) return const Color(0xFFE7A25D);
    if (weather.contains('\u4e91') || weather.contains('\u9634')) {
      return const Color(0xFF8FAE8B);
    }
    if (weather.contains('\u96f7') || weather.contains('\u96e8')) {
      return const Color(0xFF7A9BB8);
    }
    if (weather.contains('\u96ea')) return const Color(0xFF9DBED0);
    return context.lgInk;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      if (_loading) return _buildCompactLoading();
      if (_errorType != null) return _buildCompactError();
      return _buildCompactContent();
    }

    return LovePaper(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: context.lgPaper,
      child: _loading
          ? _buildLoading()
          : _errorType != null
              ? _buildError()
              : InkWell(
                  onTap: _showWeatherActions,
                  borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            '\u6b63\u5728\u52a0\u8f7d\u5929\u6c14...',
            style: TextStyle(color: context.lgTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLoading() {
    return const SizedBox(
      width: 118,
      height: 72,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildCompactError() {
    String label;
    String subLabel;
    IconData icon;

    switch (_errorType) {
      case WeatherErrorType.permission:
        label = '--°';
        subLabel = '去开启定位';
        icon = Icons.location_disabled_rounded;
        break;
      case WeatherErrorType.location:
        label = '--°';
        subLabel = '定位一下天气';
        icon = Icons.refresh_rounded;
        break;
      case WeatherErrorType.network:
        label = '--°';
        subLabel = '点我重试';
        icon = Icons.refresh_rounded;
        break;
      case WeatherErrorType.data:
        label = '--°';
        subLabel = '选个城市看看';
        icon = Icons.refresh_rounded;
        break;
      default:
        label = '--°';
        subLabel = '点我重试';
        icon = Icons.refresh_rounded;
    }

    return InkWell(
      onTap: _showWeatherActions,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 118,
        height: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: context.lgInk.withAlpha(12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: context.lgTextMuted),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: context.lgTextPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.lgTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    String message;
    switch (_errorType) {
      case WeatherErrorType.permission:
        message =
            '\u5b9a\u4f4d\u6743\u9650\u672a\u5f00\u542f\uff0c\u70b9\u51fb\u53bb\u8bbe\u7f6e';
        break;
      case WeatherErrorType.location:
        message = '\u5b9a\u4f4d\u5931\u8d25\uff0c\u70b9\u51fb\u91cd\u8bd5';
        break;
      case WeatherErrorType.network:
        message =
            '\u5929\u6c14\u52a0\u8f7d\u5931\u8d25\uff0c\u70b9\u51fb\u91cd\u8bd5';
        break;
      case WeatherErrorType.data:
        message = '\u6682\u65e0\u5929\u6c14\u6570\u636e';
        break;
      default:
        message =
            '\u5929\u6c14\u6682\u65f6\u6ca1\u6709\u52a0\u8f7d\u51fa\u6765\uff0c\u70b9\u51fb\u91cd\u8bd5';
    }

    return InkWell(
      onTap: _showWeatherActions,
      borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Icon(
              _errorType == WeatherErrorType.permission
                  ? Icons.settings_rounded
                  : Icons.refresh_rounded,
              size: 20,
              color: context.lgTextMuted,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.lgTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final weather = _weather ?? '--';
    final color = _colorForWeather(weather);
    final range = (_tempLow != null && _tempHigh != null)
        ? '${_formatDegree(_tempLow)} ~ ${_formatDegree(_tempHigh)}'
        : null;
    final details = <_WeatherChipData>[];

    if (_feelsLike != null && _feelsLike!.isNotEmpty) {
      details.add(
        _WeatherChipData(
          Icons.thermostat_rounded,
          '\u4f53\u611f ${_formatDegree(_feelsLike)}',
        ),
      );
    }
    if (_humidity != null && _humidity!.isNotEmpty) {
      details.add(
        _WeatherChipData(
          Icons.water_drop_rounded,
          '\u6e7f\u5ea6 $_humidity',
        ),
      );
    }
    if (_wind != null && _wind!.isNotEmpty) {
      details.add(_WeatherChipData(Icons.air_rounded, _wind!));
    }
    if (range != null) {
      details.add(_WeatherChipData(Icons.device_thermostat_rounded, range));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconForWeather(weather), color: color, size: 28),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDegree(_temperature),
                    style: TextStyle(
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: context.lgTextPrimary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        '${_city ?? '\u5f53\u524d\u4f4d\u7f6e'} \u00b7 $weather',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.lgTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 5),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: details
                    .map((item) => _WeatherDetailChip(data: item))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContent() {
    final weather = _weather ?? '--';
    final color = _colorForWeather(weather);
    final city = _city ?? '\u5f53\u524d\u4f4d\u7f6e';
    final feelsLike = (_feelsLike == null || _feelsLike!.isEmpty)
        ? null
        : '体感 ${_formatDegree(_feelsLike)}';

    return InkWell(
      onTap: _showWeatherActions,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 118,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconForWeather(weather), color: color, size: 16),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatDegree(_temperature),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: context.lgTextPrimary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          weather,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.lgTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.lgTextMuted,
                    ),
                  ),
                  if (feelsLike != null) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          feelsLike,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _formatDegree(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text == '--') return '--\u00b0';
    return text.endsWith('\u00b0') ? text : '$text\u00b0';
  }

  String? _safeNumberText(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= -100 || parsed >= 100) return null;
    return parsed.round().toString();
  }

  Map<String, dynamic> _typedMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }
}

class _WeatherChipData {
  final IconData icon;
  final String label;

  _WeatherChipData(this.icon, this.label);
}

class _WeatherDetailChip extends StatelessWidget {
  final _WeatherChipData data;

  const _WeatherDetailChip({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: context.lgPaperWarm,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 13, color: context.lgTextMuted),
          SizedBox(width: 4),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.lgTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
