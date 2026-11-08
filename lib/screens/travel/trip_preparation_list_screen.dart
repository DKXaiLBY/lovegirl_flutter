import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/travel/journey.dart';
import '../../features/travel/travel_screen.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'trip_preparation_screen.dart';

class TripPreparationListScreen extends StatefulWidget {
  final ApiService? api;
  const TripPreparationListScreen({super.key, this.api});

  @override
  State<TripPreparationListScreen> createState() =>
      _TripPreparationListScreenState();
}

class _TripPreparationListScreenState extends State<TripPreparationListScreen> {
  late final _api = widget.api ?? ApiService();
  int? _account;
  int _request = 0;
  bool _loading = true;
  List<Journey>? _journeys;
  List<({int id, String title})>? _archives;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = context.watch<AuthProvider>().userId;
    if (account == _account) return;
    _account = account;
    _request++;
    _journeys = null;
    _archives = null;
    if (account != null) _load();
  }

  Future<void> _load() async {
    final account = _account;
    final request = ++_request;
    setState(() => _loading = true);
    Future<List<Map<String, dynamic>>?> read(Future<dynamic> request) async {
      try {
        final response = await request;
        return (response.data['data'] as List).cast<Map<String, dynamic>>();
      } catch (_) {
        return null;
      }
    }

    final result = await Future.wait([
      read(_api.getJourneys()),
      read(_api.get('/api/travel-preparation/archives')),
    ]);
    if (!mounted ||
        context.read<AuthProvider>().userId != account ||
        request != _request) {
      return;
    }
    setState(() {
      _journeys = result[0]?.map(Journey.fromJson).toList();
      _archives = result[1]
          ?.map((row) => (id: row['id'] as int, title: row['title'] as String))
          .toList();
      _loading = false;
    });
  }

  Future<void> _open(int id, [Journey? journey]) async {
    final navigator = Navigator.of(context);
    await navigator.push<void>(MaterialPageRoute(
        builder: (_) => TripPreparationScreen(
              api: _api,
              tripId: id,
              journey: journey,
              onViewJourney: journey == null
                  ? null
                  : () => navigator.push<void>(MaterialPageRoute(
                      builder: (_) =>
                          TravelScreen(embedded: false, initialJourneyId: id))),
            )));
    if (mounted && _account != null) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.lgBg,
        appBar: AppBar(title: const Text('旅行准备')),
        body: RebuildPageBackground(
          child: _account == null
              ? const Center(child: Text('登录后查看旅行准备'))
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('选择一份行程',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          if (_journeys == null)
                            ListTile(
                              title: const Text('行程暂未加载'),
                              trailing: TextButton(
                                  onPressed: _load, child: const Text('重试')),
                            )
                          else if (_journeys!.isEmpty)
                            ListTile(
                              title: const Text('还没有已保存的行程'),
                              subtitle: const Text('在旅行页创建行程后，就可以准备行李和搭配。'),
                              trailing: IconButton(
                                tooltip: '打开旅行',
                                onPressed: () => Navigator.push<void>(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const TravelScreen(
                                            embedded: false))),
                                icon: const Icon(Icons.arrow_forward),
                              ),
                            )
                          else
                            for (final journey in _journeys!)
                              if (journey.id != null)
                                _tile(
                                    journey.title,
                                    [
                                      if (journey.startDate != null)
                                        journey.startDate!,
                                      '${journey.days} 天'
                                    ].join(' · '),
                                    Icons.luggage_outlined,
                                    () => _open(journey.id!, journey)),
                          if (_archives?.isNotEmpty == true) ...[
                            const SizedBox(height: 18),
                            const Text('归档记录',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            for (final archive in _archives!)
                              _tile(
                                  archive.title,
                                  '已归档 · 只读',
                                  Icons.inventory_2_outlined,
                                  () => _open(archive.id)),
                          ],
                          if (_archives == null)
                            ListTile(
                              title: const Text('归档暂未加载'),
                              trailing: TextButton(
                                  onPressed: _load, child: const Text('重试')),
                            ),
                        ],
                      ),
                    ),
        ),
      );

  Widget _tile(
          String title, String subtitle, IconData icon, VoidCallback open) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: RebuildGlass(
          radius: 20,
          child: ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: open,
          ),
        ),
      );
}
