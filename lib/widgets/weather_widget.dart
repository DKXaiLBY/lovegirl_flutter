import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/api_service.dart';
import '../services/log_service.dart';
import '../utils/lovegirl_theme.dart';
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

    try {
      final data = await _fetchLocationWeather();

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
    } catch (e) {
      if (_disposed || !mounted) return;
      if (_restoreFromCache()) return;
      LogService().error('Weather', '天气加载失败: $e');
      if (!_disposed && mounted) {
        setState(() {
          _loading = false;
          _errorType = _errorType ?? WeatherErrorType.network;
        });
      }
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
      final response = await ApiService().get(
        '/api/weather/coords',
        query: {'lat': position.latitude, 'lng': position.longitude},
      ).timeout(const Duration(seconds: 8));
      return _typedMap(response.data?['data']);
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
              : _buildContent(),
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
    VoidCallback? onTap;

    switch (_errorType) {
      case WeatherErrorType.permission:
        label = '--°';
        subLabel = '去开启定位';
        icon = Icons.location_disabled_rounded;
        onTap = Geolocator.openAppSettings;
        break;
      case WeatherErrorType.location:
        label = '--°';
        subLabel = '定位一下天气';
        icon = Icons.refresh_rounded;
        onTap = _fetchWeather;
        break;
      case WeatherErrorType.network:
        label = '--°';
        subLabel = '点我重试';
        icon = Icons.refresh_rounded;
        onTap = _fetchWeather;
        break;
      case WeatherErrorType.data:
        label = '--°';
        subLabel = '天气暂未更新';
        icon = Icons.refresh_rounded;
        onTap = _fetchWeather;
        break;
      default:
        label = '--°';
        subLabel = '点我重试';
        icon = Icons.refresh_rounded;
        onTap = _fetchWeather;
    }

    return InkWell(
      onTap: onTap,
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
      onTap: _errorType == WeatherErrorType.permission
          ? Geolocator.openAppSettings
          : _fetchWeather,
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

    return SizedBox(
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
