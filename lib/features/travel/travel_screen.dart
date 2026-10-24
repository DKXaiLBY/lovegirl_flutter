import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/travel.dart' show TravelSpot;
import '../../screens/travel/china_memory_map_screen.dart';
import '../../screens/travel/travel_memory_screen.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import 'place_editor.dart';
import 'place_picker.dart';
import 'place_search.dart';
import 'travel_map_canvas.dart';
import 'travel_workspace.dart';

class TravelScreen extends StatefulWidget {
  final TravelSpot? initialSpot;
  final bool embedded;
  final VoidCallback? onMapReady;
  const TravelScreen(
      {super.key, this.initialSpot, this.embedded = true, this.onMapReady});
  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final _map = GlobalKey<TravelMapCanvasState>();
  final _sheet = DraggableScrollableController();
  final _extent = ValueNotifier<double>(0.30);
  late TravelWorkspace _workspace;
  bool _locating = false;
  bool _deleting = false;
  bool _recording = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _workspace = context.read<TravelWorkspace>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialSpot != null) {
        _workspace.select(widget.initialSpot);
        final place = widget.initialSpot!;
        if (hasMapPosition(place)) {
          _workspace.camera = TravelCamera(place.lat, place.lng, 15);
        }
      }
      unawaited(_workspace.load());
    });
  }

  @override
  void dispose() {
    _sheet.dispose();
    _extent.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), behavior: SnackBarBehavior.floating));
  }

  void _select(TravelSpot place, {bool focus = false}) {
    _workspace.select(place);
    if (_sheet.isAttached) {
      _sheet.animateTo(0.30,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
    if (focus && hasMapPosition(place)) {
      _map.currentState?.focus(place.lat, place.lng);
    }
  }

  Future<void> _record([PlaceChoice? point]) async {
    if (_recording) return;
    _recording = true;
    try {
      final choice = point ??
          await Navigator.of(context).push<PlaceChoice>(MaterialPageRoute(
              builder: (_) => TravelPlacePicker(
                  api: _workspace.api, initialCamera: _workspace.camera)));
      if (choice == null || !mounted) return;
      final saved = await Navigator.of(context).push<TravelSpot>(
          MaterialPageRoute(
              builder: (_) =>
                  TravelPlaceEditor(choice: choice, api: _workspace.api)));
      if (saved == null || !mounted) return;
      _workspace.upsert(saved);
      _select(saved, focus: true);
      _message('地点已保存，照片可以在故事页添加');
      unawaited(_workspace.load(refresh: true));
    } finally {
      _recording = false;
    }
  }

  Future<void> _edit(TravelSpot place) async {
    final saved = await Navigator.of(context).push<TravelSpot>(
        MaterialPageRoute(
            builder: (_) =>
                TravelPlaceEditor(spot: place, api: _workspace.api)));
    if (saved == null || !mounted) return;
    _workspace.upsert(saved);
    _select(saved, focus: true);
    _message('修改已保存');
    unawaited(_workspace.load(refresh: true));
  }

  Future<void> _search() async {
    final result = await Navigator.of(context).push<PlaceChoice>(
        MaterialPageRoute(
            builder: (_) => TravelPlaceSearch(workspace: _workspace)));
    if (result == null || !mounted) return;
    if (result.saved != null) {
      _select(result.saved!, focus: true);
    } else {
      _map.currentState?.focus(result.lat, result.lng);
      _previewNew(result);
    }
  }

  void _previewNew(PlaceChoice place) {
    showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(place.name.isEmpty ? '选中的位置' : place.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      if (place.address.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(place.address)),
                      const SizedBox(height: 16),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: context.lgInk,
                              foregroundColor: context.lgPaper),
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _record(place);
                          },
                          child: const Text('记下这个地点')),
                    ]))));
  }

  Future<void> _locate() async {
    if (_locating || !_mapReady) return;
    setState(() => _locating = true);
    try {
      await _map.currentState?.locate();
    } catch (failure) {
      _message(failure is StateError ? failure.message : '定位暂时不可用，可搜索地点');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showOnMap(TravelSpot place) {
    final route = ModalRoute.of(context);
    Navigator.of(context).popUntil((value) => value == route);
    _select(place, focus: true);
  }

  Future<void> _overview() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChinaMemoryMapScreen(
            spots: _workspace.places,
            onChanged: _workspace.upsert,
            onShowOnMap: _showOnMap)));
    if (mounted) unawaited(_workspace.load(refresh: true));
  }

  Future<void> _story(TravelSpot place) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TravelMemoryScreen(
            spot: place,
            onChanged: _workspace.upsert,
            onShowOnMap: _showOnMap)));
    if (mounted) unawaited(_workspace.load(refresh: true));
  }

  Future<void> _delete(TravelSpot place) async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('删除地点？'),
                content: Text('将移除“${place.name}”及其旅行记录。'),
                actions: [
                  TextButton(
                      style:
                          TextButton.styleFrom(foregroundColor: context.lgInk),
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('取消')),
                  TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: LoveGirlTheme.red),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('删除')),
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _workspace.delete(place);
      _message('地点已删除');
    } catch (_) {
      _message('删除失败，记录仍然保留');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialSpot;
    final initialCamera = _workspace.camera ??
        (initial != null && hasMapPosition(initial)
            ? TravelCamera(initial.lat, initial.lng, 15)
            : const TravelCamera(35.86, 104.20, 4));
    return Scaffold(
      body: LayoutBuilder(
          builder: (context, constraints) => Stack(children: [
                Positioned.fill(
                    child: AnimatedBuilder(
                        animation: _workspace,
                        builder: (context, _) => TravelMapCanvas(
                            key: _map,
                            initialCamera: initialCamera,
                            places: _workspace.visiblePlaces,
                            selectedId: _workspace.selectedId,
                            onCameraSettled: (value) =>
                                _workspace.camera = value,
                            onSelect: _select,
                            onPick: _previewNew,
                            onReady: () {
                              if (mounted) setState(() => _mapReady = true);
                              widget.onMapReady?.call();
                            }))),
                Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: SafeArea(
                        bottom: false,
                        child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Material(
                                color: context.lgPaper,
                                elevation: 3,
                                borderRadius: BorderRadius.circular(22),
                                child: Row(children: [
                                  if (!widget.embedded)
                                    IconButton(
                                        tooltip: '返回',
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.arrow_back)),
                                  Expanded(
                                      child: InkWell(
                                          onTap: _search,
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 17),
                                              child: Row(children: [
                                                Icon(Icons.search,
                                                    color: context.lgInk),
                                                const SizedBox(width: 10),
                                                Flexible(
                                                    child: Text('搜索地点或城市',
                                                        style: TextStyle(
                                                            color: context
                                                                .lgTextSecondary))),
                                              ])))),
                                  IconButton(
                                      tooltip: '足迹总览',
                                      onPressed: _overview,
                                      icon: const Icon(Icons.public_outlined)),
                                ]))))),
                ValueListenableBuilder<double>(
                    valueListenable: _extent,
                    builder: (context, extent, _) => Positioned(
                        right: 16,
                        bottom: constraints.maxHeight * extent + 14,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FloatingActionButton.small(
                                  heroTag: 'travel_location',
                                  tooltip: '定位到我',
                                  backgroundColor: context.lgPaper,
                                  foregroundColor: context.lgInk,
                                  onPressed:
                                      _locating || !_mapReady ? null : _locate,
                                  child: _locating
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.my_location_outlined)),
                              const SizedBox(height: 10),
                              FloatingActionButton.extended(
                                  heroTag: 'travel_record',
                                  backgroundColor: context.lgInk,
                                  foregroundColor: context.lgPaper,
                                  onPressed: _record,
                                  icon: const Icon(
                                      Icons.add_location_alt_outlined),
                                  label: const Text('记地点')),
                            ]))),
                NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    _extent.value = notification.extent;
                    return true;
                  },
                  child: DraggableScrollableSheet(
                      controller: _sheet,
                      initialChildSize: .30,
                      minChildSize: .16,
                      maxChildSize: .72,
                      snap: true,
                      snapSizes: const [.16, .30, .72],
                      builder: (context, scrollController) => Material(
                          color: context.lgPaper,
                          elevation: 8,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(26)),
                          clipBehavior: Clip.antiAlias,
                          child: AnimatedBuilder(
                              animation: _workspace,
                              builder: (context, _) {
                                final places = _workspace.visiblePlaces;
                                final selected = _workspace.selected;
                                return CustomScrollView(
                                    controller: scrollController,
                                    slivers: [
                                      SliverToBoxAdapter(
                                          child: Column(children: [
                                        const SizedBox(height: 10),
                                        Container(
                                            width: 36,
                                            height: 4,
                                            decoration: BoxDecoration(
                                                color: context.lgSeparator,
                                                borderRadius:
                                                    BorderRadius.circular(4))),
                                        Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                20, 12, 10, 4),
                                            child: Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      selected == null
                                                          ? '我的地点'
                                                          : selected.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: context
                                                              .lgTextPrimary))),
                                              if (selected != null)
                                                IconButton(
                                                    tooltip: '返回地点列表',
                                                    onPressed: () =>
                                                        _workspace.select(null),
                                                    icon:
                                                        const Icon(Icons.close))
                                              else
                                                IconButton(
                                                    tooltip: '刷新地点',
                                                    onPressed: _workspace
                                                            .loading
                                                        ? null
                                                        : () => _workspace.load(
                                                            refresh: true),
                                                    icon: const Icon(
                                                        Icons.refresh)),
                                            ])),
                                        if (_workspace.loading)
                                          const LinearProgressIndicator(
                                              minHeight: 2),
                                        if (_workspace.error != null)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              child: Row(children: [
                                                Expanded(
                                                    child: Text(
                                                        _workspace.error!,
                                                        style: const TextStyle(
                                                            color: LoveGirlTheme
                                                                .red))),
                                                TextButton(
                                                    onPressed: () => _workspace
                                                        .load(refresh: true),
                                                    child: const Text('重试')),
                                              ])),
                                        if (selected == null)
                                          SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              child: Row(children: [
                                                for (final filter in [
                                                  ('', '全部'),
                                                  ('wish', '想去'),
                                                  ('planned', '计划中'),
                                                  ('visited', '已去')
                                                ])
                                                  Padding(
                                                      padding: const EdgeInsets.only(
                                                          right: 8),
                                                      child: ChoiceChip(
                                                          showCheckmark: false,
                                                          selectedColor:
                                                              context.lgInk,
                                                          backgroundColor:
                                                              context.lgPaper,
                                                          labelStyle: TextStyle(
                                                              color: _workspace.status == filter.$1
                                                                  ? context
                                                                      .lgPaper
                                                                  : context
                                                                      .lgInk),
                                                          shape:
                                                              const StadiumBorder(),
                                                          side: BorderSide(
                                                              color: context
                                                                  .lgSeparator),
                                                          label:
                                                              Text(filter.$2),
                                                          selected:
                                                              _workspace.status ==
                                                                  filter.$1,
                                                          onSelected: (_) =>
                                                              _workspace.setStatus(filter.$1))),
                                              ])),
                                      ])),
                                      if (selected != null)
                                        SliverToBoxAdapter(
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        20, 8, 20, 32),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      _PlaceRow(
                                                          place: selected,
                                                          onTap: () =>
                                                              _story(selected)),
                                                      const SizedBox(
                                                          height: 12),
                                                      FilledButton(
                                                          style: FilledButton.styleFrom(
                                                              backgroundColor:
                                                                  context.lgInk,
                                                              foregroundColor:
                                                                  context
                                                                      .lgPaper),
                                                          onPressed: () =>
                                                              _story(selected),
                                                          child: const Text(
                                                              '照片与故事')),
                                                      Row(children: [
                                                        TextButton.icon(
                                                            style: TextButton.styleFrom(
                                                                foregroundColor:
                                                                    context
                                                                        .lgInk),
                                                            onPressed: () =>
                                                                _edit(selected),
                                                            icon: const Icon(Icons
                                                                .edit_outlined),
                                                            label: const Text(
                                                                '编辑地点')),
                                                        const Spacer(),
                                                        TextButton.icon(
                                                            style: TextButton.styleFrom(
                                                                foregroundColor:
                                                                    context
                                                                        .lgInk),
                                                            onPressed: _deleting
                                                                ? null
                                                                : () => _delete(
                                                                    selected),
                                                            icon: const Icon(Icons
                                                                .delete_outline),
                                                            label: Text(
                                                                _deleting
                                                                    ? '删除中…'
                                                                    : '删除')),
                                                      ]),
                                                    ])))
                                      else if (places.isEmpty)
                                        const SliverToBoxAdapter(
                                            child: Padding(
                                                padding: EdgeInsets.fromLTRB(
                                                    24, 20, 24, 40),
                                                child: Text(
                                                    '还没有这些地点。搜索或长按地图，就可以记下想去的地方。')))
                                      else
                                        SliverList.builder(
                                            itemCount: places.length,
                                            itemBuilder: (context, index) =>
                                                _PlaceRow(
                                                    place: places[index],
                                                    onTap: () => _select(
                                                        places[index],
                                                        focus: true))),
                                      const SliverToBoxAdapter(
                                          child: SizedBox(height: 24)),
                                    ]);
                              }))),
                ),
              ])),
    );
  }
}

class _PlaceRow extends StatelessWidget {
  final TravelSpot place;
  final VoidCallback onTap;
  const _PlaceRow({required this.place, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final image =
        place.coverImage ?? (place.photos.isEmpty ? null : place.photos.first);
    final date = place.status == 'planned'
        ? place.plannedDate
        : place.status == 'visited'
            ? place.visitedDate
            : null;
    final status = place.status == 'visited'
        ? '已去'
        : place.status == 'planned'
            ? '计划中'
            : '想去';
    return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
                width: 48,
                height: 48,
                child: image == null
                    ? ColoredBox(
                        color: context.lgPrimarySoft,
                        child: Icon(Icons.place_outlined, color: context.lgInk))
                    : CachedNetworkImage(
                        imageUrl: image.startsWith('http')
                            ? image
                            : AppConstants.baseUrl + image,
                        fit: BoxFit.cover,
                        memCacheWidth: 160,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.image_not_supported_outlined)))),
        title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            [
              place.city,
              status,
              if (!hasMapPosition(place)) '未设置地图位置',
              if (date != null && date.isNotEmpty)
                date.split('T').first.split(' ').first
            ].where((part) => part.isNotEmpty).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap);
  }
}
