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
  String? _tempHigh;
  String? _tempLow;
  String? _weather;
  String? _city;
  String? _humidity;
  String? _wind;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

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
    setState(() { _loading = true; _error = false; });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Map<String, dynamic>? data;
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium).timeout(const Duration(seconds: 10));
        final gcj02 = _wgs84ToGcj02(position.latitude, position.longitude);
        final res = await ApiService().get('/api/weather/coords', query: {'lat': gcj02[0].toString(), 'lng': gcj02[1].toString()}).timeout(const Duration(seconds: 10));
        data = res.data?['data'] as Map<String, dynamic>?;
      }
      if (data == null) {
        final res = await ApiService().get('/api/weather', query: {'city': '北京'}).timeout(const Duration(seconds: 10));
        data = res.data?['data'] as Map<String, dynamic>?;
      }
      if (data == null) throw Exception('no data');
      if (!mounted) return;
      setState(() {
        _temperature = (data!['temp'] ?? data['temperature'])?.toString() ?? '--';
        _tempHigh = data['tempHigh']?.toString();
        _tempLow = data['tempLow']?.toString();
        _weather = data['weather']?.toString() ?? '--';
        _city = data['city']?.toString() ?? '未知';
        _humidity = data['humidity']?.toString();
        _wind = data['wind']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  IconData _iconForWeather(String w) {
    if (w.contains('晴')) return Icons.wb_sunny_rounded;
    if (w.contains('多云')) return Icons.cloud_rounded;
    if (w.contains('阴')) return Icons.cloud_queue_rounded;
    if (w.contains('雷')) return Icons.flash_on_rounded;
    if (w.contains('暴雨') || w.contains('大雨')) return Icons.thunderstorm_rounded;
    if (w.contains('雨')) return Icons.water_drop_rounded;
    if (w.contains('雪')) return Icons.ac_unit_rounded;
    if (w.contains('雾') || w.contains('霾')) return Icons.cloud_circle_rounded;
    return Icons.wb_cloudy_rounded;
  }

  Color _colorForWeather(String w) {
    if (w.contains('晴')) return const Color(0xFFFFB347);
    if (w.contains('多云')) return const Color(0xFF7B8CFF);
    if (w.contains('阴')) return const Color(0xFF9E9EAD);
    if (w.contains('雷')) return const Color(0xFFFF6B6B);
    if (w.contains('雨')) return const Color(0xFF6BD4FF);
    if (w.contains('雪')) return const Color(0xFFB3E5FC);
    return LoveGirlTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFDF2F4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(LoveGirlTheme.radius),
        boxShadow: LoveGirlTheme.cardShadow(),
      ),
      child: _loading ? _buildShimmer() : _error ? _buildError() : _buildContent(),
    );
  }

  Widget _buildShimmer() {
    return Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: LoveGirlTheme.separator.withAlpha(120), shape: BoxShape.circle)),
      const SizedBox(width: 14),
      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 60, height: 20, decoration: BoxDecoration(color: LoveGirlTheme.separator.withAlpha(120), borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 6),
        Container(width: 40, height: 14, decoration: BoxDecoration(color: LoveGirlTheme.separator.withAlpha(120), borderRadius: BorderRadius.circular(6))),
      ]),
    ]);
  }

  Widget _buildError() {
    return InkWell(onTap: _fetchWeather, borderRadius: BorderRadius.circular(LoveGirlTheme.radius), child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.refresh_rounded, size: 18, color: LoveGirlTheme.textMuted),
      const SizedBox(width: 6),
      Text('天气加载失败，点击重试', style: TextStyle(fontSize: 13, color: LoveGirlTheme.textMuted)),
    ])));
  }

  Widget _buildContent() {
    final w = _weather ?? '--';
    final color = _colorForWeather(w);
    // 构建温度范围文字
    final rangeText = (_tempLow != null && _tempHigh != null) ? '$_tempLow°~$_tempHigh°' : '';
    // 构建详情文字
    final detailParts = <String>[];
    if (_humidity != null) detailParts.add(_humidity!);
    if (_wind != null) detailParts.add(_wind!);
    final detailText = detailParts.join(' ');

    return Row(children: [
      // 天气图标
      Container(width: 50, height: 50, decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
        child: Icon(_iconForWeather(w), size: 28, color: color)),
      const SizedBox(width: 12),
      // 温度 + 天气
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_temperature ?? '--'}°', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: LoveGirlTheme.textPrimary, height: 1)),
          if (rangeText.isNotEmpty) ...[
            const SizedBox(width: 6),
            Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(rangeText, style: TextStyle(fontSize: 12, color: LoveGirlTheme.textMuted))),
          ],
        ]),
        const SizedBox(height: 2),
        Text(w, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(width: 8),
      // 城市 + 详情
      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_city ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LoveGirlTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (detailText.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(detailText, style: TextStyle(fontSize: 11, color: LoveGirlTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ]),
    ]);
  }
}
