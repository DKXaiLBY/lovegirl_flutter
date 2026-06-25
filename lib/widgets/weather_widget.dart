import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../utils/lovegirl_theme.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  String? _temperature;
  String? _weather;
  String? _city;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  /// WGS-84 坐标转 GCJ-02 坐标（高德地图使用）
  List<double> _wgs84ToGcj02(double lat, double lng) {
    const double pi = 3.14159265358979324;
    const double a = 6378245.0;
    const double ee = 0.00669342162296594;

    double dLat = _transformLat(lng - 105.0, lat - 35.0);
    double dLng = _transformLng(lng - 105.0, lat - 35.0);

    double radLat = lat / 180.0 * pi;
    double magic = sin(radLat);
    magic = 1 - ee * magic * magic;
    double sqrtMagic = sqrt(magic);

    dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * pi);
    dLng = (dLng * 180.0) / (a / sqrtMagic * cos(radLat) * pi);

    return [lat + dLat, lng + dLng];
  }

  double _transformLat(double x, double y) {
    const double pi = 3.14159265358979324;
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  double _transformLng(double x, double y) {
    const double pi = 3.14159265358979324;
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x.abs());
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
    return ret;
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      // 获取 GPS 位置
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        // 获取当前位置
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        ).timeout(const Duration(seconds: 10));

        // 转换为 GCJ-02 坐标（高德地图使用）
        final gcj02 = _wgs84ToGcj02(position.latitude, position.longitude);

        // 使用经纬度获取天气
        final res = await ApiService().get('/api/weather/coords', query: {
          'lat': gcj02[0].toString(),
          'lng': gcj02[1].toString(),
        }).timeout(const Duration(seconds: 10));

        final data = res.data?['data'] as Map<String, dynamic>?;
        if (data != null) {
          if (!mounted) return;
          setState(() {
            _temperature = (data['temp'] ?? data['temperature'])?.toString() ?? '--';
            _weather = data['weather']?.toString() ?? '--';
            _city = data['city']?.toString() ?? '未知';
            _loading = false;
          });
          return;
        }
      }

      // 如果 GPS 定位失败，使用默认城市
      final res = await ApiService().get('/api/weather', query: {'city': '北京'}).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('timeout'),
      );

      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) throw Exception('no data');

      if (!mounted) return;
      setState(() {
        _temperature = (data['temp'] ?? data['temperature'])?.toString() ?? '--';
        _weather = data['weather']?.toString() ?? '--';
        _city = data['city']?.toString() ?? '北京';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  IconData _iconForWeather(String weather) {
    if (weather.contains('晴')) return Icons.wb_sunny;
    if (weather.contains('多云')) return Icons.cloud;
    if (weather.contains('阴')) return Icons.cloud_queue;
    if (weather.contains('雨')) return Icons.grain;
    if (weather.contains('雪')) return Icons.ac_unit;
    return Icons.wb_cloudy;
  }

  Color _colorForWeather(String weather) {
    if (weather.contains('晴')) return const Color(0xFFFFB347);
    if (weather.contains('多云')) return const Color(0xFF7B8CFF);
    if (weather.contains('阴')) return const Color(0xFF9E9EAD);
    if (weather.contains('雨')) return const Color(0xFF6BD4FF);
    if (weather.contains('雪')) return const Color(0xFFB3E5FC);
    return LoveGirlTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFFDF2F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
        boxShadow: LoveGirlTheme.cardShadow(),
      ),
      child: _loading
          ? _buildShimmer()
          : _error
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _shimmerBox(36, 36, isCircle: true),
          const SizedBox(width: 14),
          _shimmerBox(60, 24),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _shimmerBox(48, 14),
              const SizedBox(height: 6),
              _shimmerBox(36, 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h, {bool isCircle = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: LoveGirlTheme.separator.withAlpha(120),
        borderRadius: isCircle ? null : BorderRadius.circular(6),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }

  Widget _buildError() {
    return InkWell(
      onTap: _fetchWeather,
      borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 18, color: LoveGirlTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              '天气加载失败，点击重试',
              style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final w = _weather ?? '--';
    final color = _colorForWeather(w);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForWeather(w), size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Text(
            '${_temperature ?? '--'}°C',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: LoveGirlTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _city ?? '北京',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: LoveGirlTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                w,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
