import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/travel.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/memory_controls.dart';
import '../../widgets/travel_photo_grid.dart';
import '../../features/travel/place_editor.dart';
import 'travel_ticket_screen.dart';
import '../../features/travel/travel_screen.dart';

/// 省份、城市和地点共享同一条故事入口，沿用地点与照片数据。
class TravelMemoryScreen extends StatefulWidget {
  final TravelSpot spot;
  final ValueChanged<TravelSpot>? onChanged;
  final ValueChanged<TravelSpot>? onShowOnMap;
  const TravelMemoryScreen(
      {super.key, required this.spot, this.onChanged, this.onShowOnMap});

  @override
  State<TravelMemoryScreen> createState() => _TravelMemoryScreenState();
}

class _TravelMemoryScreenState extends State<TravelMemoryScreen> {
  late TravelSpot _spot = widget.spot;

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<TravelSpot>(
        MaterialPageRoute(builder: (_) => TravelPlaceEditor(spot: _spot)));
    if (saved == null || !mounted) return;
    setState(() => _spot = saved);
    widget.onChanged?.call(saved);
  }

  @override
  Widget build(BuildContext context) {
    final rawDate = _spot.status == 'planned'
        ? _spot.plannedDate
        : _spot.status == 'visited'
            ? _spot.visitedDate
            : null;
    final date = (rawDate ?? '').split('T').first.split(' ').first;
    final paragraphs = <String>[
      if ((_spot.diary ?? '').trim().isNotEmpty) _spot.diary!.trim(),
      if ((_spot.note ?? '').trim().isNotEmpty &&
          _spot.note!.trim() != (_spot.diary ?? '').trim())
        _spot.note!.trim(),
    ];
    return Scaffold(
      backgroundColor: context.lgPaper,
      appBar: AppBar(
        systemOverlayStyle: context.lgIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        backgroundColor: context.lgPaper,
        foregroundColor: context.lgInk,
        elevation: 0,
        title: const Text('照片与故事'),
        actions: [
          IconButton(
            tooltip: '查看地图位置',
            icon: const Icon(Icons.map_outlined),
            onPressed: _spot.lat.isFinite &&
                    _spot.lng.isFinite &&
                    _spot.lat.abs() <= 90 &&
                    _spot.lng.abs() <= 180 &&
                    (_spot.lat != 0 || _spot.lng != 0)
                ? () {
                    if (widget.onShowOnMap != null) {
                      widget.onShowOnMap!(_spot);
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TravelScreen(
                              initialSpot: _spot, embedded: false)));
                    }
                  }
                : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        children: [
          Text(
              [
                _spot.city,
                _spot.status == 'wish'
                    ? '想去'
                    : date.isEmpty
                        ? '日期待补充'
                        : '${_spot.status == 'planned' ? '计划 ' : ''}$date'
              ].where((part) => part.isNotEmpty).join(' · '),
              style: TextStyle(color: context.lgTextSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Text(_spot.name,
              style: TextStyle(
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: context.lgTextPrimary)),
          const SizedBox(height: 20),
          TravelPhotoGrid(spotId: _spot.id, editorial: true),
          const SizedBox(height: 24),
          Text(paragraphs.isEmpty ? '还没有写下这一天的故事。' : paragraphs.join('\n\n'),
              style: TextStyle(
                  fontSize: 16,
                  height: 1.85,
                  color: paragraphs.isEmpty
                      ? context.lgTextMuted
                      : context.lgTextPrimary)),
          if ((_spot.noteMine ?? '').isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('我的备注', style: TextStyle(color: context.lgTextSecondary)),
            const SizedBox(height: 6),
            Text(_spot.noteMine!,
                style: TextStyle(
                    fontSize: 15, height: 1.7, color: context.lgTextPrimary)),
          ],
          if ((_spot.noteHer ?? '').isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('伴侣的备注', style: TextStyle(color: context.lgTextSecondary)),
            const SizedBox(height: 6),
            Text(_spot.noteHer!,
                style: TextStyle(
                    fontSize: 15, height: 1.7, color: context.lgTextPrimary)),
          ],
          const SizedBox(height: 24),
          Wrap(spacing: 16, runSpacing: 10, children: [
            if ((_spot.mood ?? '').isNotEmpty)
              Text('心情 · ${_spot.mood!}',
                  style: TextStyle(color: context.lgTextSecondary)),
            if ((_spot.weather ?? '').isNotEmpty)
              Text('天气 · ${_spot.weather!}',
                  style: TextStyle(color: context.lgTextSecondary)),
          ]),
          if (_spot.address.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_spot.address,
                style: TextStyle(color: context.lgTextSecondary)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
                child: MemoryAction(
                    icon: Icons.edit_outlined,
                    label: '编辑故事',
                    onPressed: _edit)),
            if (_spot.status == 'visited') const SizedBox(width: 12),
            if (_spot.status == 'visited')
              Expanded(
                  child: MemoryAction(
                icon: Icons.confirmation_number_outlined,
                label: '生成票根',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TravelTicketScreen(
                          visitedSpots: [_spot],
                          stats: TravelStats(
                              visited: 1,
                              cities: _spot.city.trim().isEmpty ? 0 : 1,
                              totalBudget: _spot.budget ?? 0))));
                },
              )),
          ]),
        ),
      ),
    );
  }
}
