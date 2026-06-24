import 'package:flutter/material.dart';
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

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final res = await ApiService().get('/api/weather', query: {'city': '北京'});
      final data = res.data['data'] as Map<String, dynamic>?;
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
