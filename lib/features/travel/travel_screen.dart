import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/travel.dart' show TravelSpot;
import '../../providers/auth_provider.dart';
import '../../screens/travel/china_memory_map_screen.dart';
import '../../screens/travel/travel_memory_screen.dart';
import '../../utils/constants.dart';
import '../../widgets/rebuild_controls.dart';
import '../../utils/lovegirl_theme.dart';
import 'place_editor.dart';
import 'place_picker.dart';
import 'place_search.dart';
import 'travel_map_canvas.dart';
import 'travel_workspace.dart';
import 'journey_controller.dart';
import 'journey.dart';
import 'journey_panel.dart';

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
  final _cards = ScrollController();
  final _extent = ValueNotifier<double>(0.30);
  late TravelWorkspace _workspace;
  late JourneyController _journeys;
  bool _locating = false;
  bool _deleting = false;
  bool _recording = false;
  bool _adding = false;
  bool _mapReady = false;
  bool _placesOpen = false;
  bool _fitOnLoad = false;
  int _lastJourneyView = -1;
  List<TravelSpot>? _seenPlaces;

  @override
  void initState() {
    super.initState();
    _workspace = context.read<TravelWorkspace>();
    _fitOnLoad = widget.initialSpot == null && _workspace.camera == null;
    _journeys = JourneyController(context.read<AuthProvider>().userId ?? 0,
        api: _workspace.api);
    _journeys.addListener(_journeyChanged);
    _workspace.addListener(_placesChanged);
    unawaited(_journeys.load());
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
    _cards.dispose();
    _workspace.removeListener(_placesChanged);
    _journeys.removeListener(_journeyChanged);
    _journeys.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), behavior: SnackBarBehavior.floating));
  }

  void _journeyChanged() {
    if (mounted) setState(() {});
    final j = _journeys.current;
    final view = _journeys.viewRevision;
    if (view == _lastJourneyView) return;
    _lastJourneyView = view;
    if (j == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || view != _lastJourneyView) return;
      if (_sheet.isAttached) {
        _sheet.animateTo(.42,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic);
      }
      if (_cards.hasClients) _cards.jumpTo(0);
      if (_workspace.loaded) _journeys.syncPlaces(_workspace.places);
      final points = _journeys.visible
          .map((s) => s.place)
          .whereType<TravelSpot>()
          .where(hasMapPosition)
          .toList();
      if (points.isEmpty) return;
      final minLat = points.map((p) => p.lat).reduce(math.min);
      final maxLat = points.map((p) => p.lat).reduce(math.max);
      final minLng = points.map((p) => p.lng).reduce(math.min);
      final maxLng = points.map((p) => p.lng).reduce(math.max);
      final span = math.max(maxLng - minLng, maxLat - minLat).clamp(.005, 180);
      _map.currentState?.focus(minLat, (minLng + maxLng) / 2,
          zoom: (math.log(360 / span) / math.ln2 - 1).clamp(3, 15));
    });
  }

  void _placesChanged() {
    if (mounted) setState(() {});
    _fitInitialPlaces();
    if (identical(_seenPlaces, _workspace.places)) return;
    _seenPlaces = _workspace.places;
    if (_workspace.loaded) _journeys.syncPlaces(_workspace.places);
  }

  void _fitInitialPlaces() {
    if (!_fitOnLoad || !_mapReady || !_workspace.loaded) return;
    final points = _workspace.places.where(hasMapPosition).toList();
    if (points.isEmpty) return;
    _fitOnLoad = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final minLat = points.map((p) => p.lat).reduce(math.min);
      final maxLat = points.map((p) => p.lat).reduce(math.max);
      final minLng = points.map((p) => p.lng).reduce(math.min);
      final maxLng = points.map((p) => p.lng).reduce(math.max);
      final span = math.max(maxLat - minLat, maxLng - minLng).clamp(.01, 180);
      _map.currentState?.focus((minLat + maxLat) / 2, (minLng + maxLng) / 2,
          zoom: (math.log(360 / span) / math.ln2 +
                  math.log(MediaQuery.sizeOf(context).width / 256) / math.ln2 -
                  .6)
              .clamp(3, 15));
    });
  }

  Future<void> _selectStop(JourneyStop stop) async {
    _journeys.selectedKey = stop.key;
    if (mounted) setState(() {});
    final place = stop.place;
    if (place != null && hasMapPosition(place)) {
      _map.currentState?.focus(place.lat, place.lng);
    }
    if (_sheet.isAttached && _extent.value > .52) {
      await _sheet.animateTo(.42,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _journeys.selectedKey != stop.key || !_cards.hasClients) {
        return;
      }
      final index = _journeys.visible.indexWhere((s) => s.key == stop.key);
      if (index >= 0) {
        _cards.animateTo(
            (index * 260.0).clamp(0, _cards.position.maxScrollExtent),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _addJourneyPlace() async {
    if (_adding || _journeys.busy) return;
    _adding = true;
    try {
      final result = await Navigator.of(context).push<PlaceChoice>(
          MaterialPageRoute(
              builder: (_) => TravelPlaceSearch(workspace: _workspace)));
      if (result == null || !mounted) return;
      if (result.saved != null) {
        _journeys.add(result.saved!);
        _selectStop(_journeys.current!.stops.last);
      } else {
        await _record(result);
      }
    } finally {
      _adding = false;
    }
  }

  void _select(TravelSpot place, {bool focus = false}) {
    setState(() => _placesOpen = false);
    _workspace.select(place);
    if (focus && hasMapPosition(place)) {
      _map.currentState?.focus(place.lat, place.lng);
    }
  }

  Future<void> _record([PlaceChoice? point]) async {
    if (_recording || _journeys.busy) return;
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
      if (_journeys.current != null) {
        _journeys.add(saved);
        _selectStop(_journeys.current!.stops.last);
      } else {
        _select(saved, focus: true);
      }
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
    _fitOnLoad = false;
    if (_journeys.busy) return;
    if (_journeys.current != null) return _addJourneyPlace();
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
    _fitOnLoad = false;
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
      _journeys.syncPlaces(_workspace.places);
      _message('地点已删除');
    } catch (_) {
      _message('删除失败，记录仍然保留');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _openPlaces() {
    _journeys.select(null);
    _workspace.select(null);
    _extent.value = .42;
    setState(() => _placesOpen = true);
  }

  Future<void> _addToJourney(TravelSpot place) async {
    await showJourneyLibrary(context, _journeys);
    if (!mounted || _journeys.current == null || _journeys.busy) return;
    _journeys.add(place);
    _selectStop(_journeys.current!.stops.last);
  }

  Future<void> _mapOptions() async {
    final option = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.public_outlined),
                  title: const Text('省市足迹'),
                  subtitle: const Text('查看去过的地方与照片故事'),
                  onTap: () => Navigator.pop(sheet, 'overview')),
              ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('刷新地点'),
                  onTap: () => Navigator.pop(sheet, 'refresh')),
            ])));
    if (!mounted) return;
    if (option == 'overview') await _overview();
    if (option == 'refresh') await _workspace.load(refresh: true);
  }

  Widget _mapHeader() => SafeArea(
      bottom: false,
      child: Column(children: [
        Row(children: [
          if (!widget.embedded) ...[
            RebuildGlassButton(
                label: '返回',
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: RebuildGlass(
                  child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: _journeys.busy ? null : _search,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(children: [
                                const Icon(Icons.search, size: 23),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text('搜索地点或城市',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                context.lgInk.withAlpha(210)))),
                              ])))))),
          const SizedBox(width: 10),
          RebuildGlassButton(
              label: '地图选项',
              icon: Icons.layers_outlined,
              onPressed: _mapOptions),
        ]),
        if (_workspace.selected == null || _journeys.current != null) ...[
          const SizedBox(height: 12),
          RebuildGlass(
              radius: 30,
              padding: const EdgeInsets.all(3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final item in [('地点', false), ('行程', true)])
                  Semantics(
                      selected: (_journeys.current != null) == item.$2,
                      child: TextButton(
                          style: TextButton.styleFrom(
                              minimumSize: const Size(72, 48),
                              foregroundColor:
                                  (_journeys.current != null) == item.$2
                                      ? context.lgInk
                                      : context.lgTextSecondary,
                              backgroundColor:
                                  (_journeys.current != null) == item.$2
                                      ? context.lgPaper.withAlpha(230)
                                      : Colors.transparent,
                              shape: const StadiumBorder()),
                          onPressed: _journeys.busy
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  if (item.$2) {
                                    showJourneyLibrary(context, _journeys);
                                  } else {
                                    _journeys.select(null);
                                    setState(() => _placesOpen = false);
                                  }
                                },
                          child: Text(item.$1))),
              ])),
        ],
        if (_workspace.error != null) ...[
          const SizedBox(height: 8),
          RebuildGlass(
              padding: const EdgeInsets.only(left: 14),
              child: Row(children: [
                Expanded(
                    child: Text(_workspace.error!,
                        style: TextStyle(
                            fontSize: 12, color: context.lgTextPrimary))),
                TextButton(
                    style: rebuildTextStyle(context),
                    onPressed: _workspace.loading
                        ? null
                        : () => _workspace.load(refresh: true),
                    child: const Text('重试')),
              ])),
        ],
      ]));

  Widget _placeCard(TravelSpot place) {
    final image =
        place.coverImage ?? (place.photos.isEmpty ? null : place.photos.first);
    final date =
        place.status == 'visited' ? place.visitedDate : place.plannedDate;
    final status = const {
          'visited': '已去',
          'planned': '计划中',
          'wish': '想去'
        }[place.status] ??
        '想去';
    final large = MediaQuery.textScalerOf(context).scale(14) > 19;
    return Material(
        color: context.lgPaper.withAlpha(245),
        elevation: 5,
        shadowColor: Colors.black.withAlpha(35),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                  flex: large ? 2 : 4,
                  child: InkWell(
                      onTap: () => _story(place),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: image == null
                              ? ColoredBox(
                                  color: context.lgPrimarySoft,
                                  child: Icon(Icons.place_outlined,
                                      size: 36, color: context.lgTextSecondary))
                              : CachedNetworkImage(
                                  imageUrl: image.startsWith('http')
                                      ? image
                                      : AppConstants.baseUrl + image,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 450,
                                  errorWidget: (_, __, ___) => const Icon(
                                      Icons.image_not_supported_outlined))))),
              const SizedBox(width: 12),
              Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(place.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700))),
                          SizedBox(
                              width: 48,
                              height: 48,
                              child: PopupMenuButton<String>(
                                  tooltip: '地点操作',
                                  icon: const Icon(Icons.more_horiz, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') _edit(place);
                                    if (value == 'delete') _delete(place);
                                    if (value == 'close') {
                                      _workspace.select(null);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                        PopupMenuItem(
                                            value: 'edit', child: Text('编辑地点')),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child: Text('删除地点')),
                                        PopupMenuItem(
                                            value: 'close',
                                            child: Text('收起地点')),
                                      ])),
                        ]),
                        Text(
                            [
                              status,
                              if (date?.isNotEmpty == true)
                                date!.split('T').first.split(' ').first
                            ].join(' · '),
                            style: TextStyle(
                                fontSize: 11, color: context.lgTextSecondary)),
                        const SizedBox(height: 6),
                        Text(
                            place.note?.isNotEmpty == true
                                ? place.note!
                                : place.city,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: context.lgTextSecondary)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: context.lgInk,
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10)),
                              onPressed: _journeys.busy
                                  ? null
                                  : () => _addToJourney(place),
                              child: const Text('加入行程',
                                  style: TextStyle(fontSize: 11))),
                          FilledButton(
                              style: rebuildFilledStyle(context).copyWith(
                                  padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 10))),
                              onPressed: () => _story(place),
                              child: const Text('照片故事',
                                  style: TextStyle(fontSize: 11))),
                        ]),
                      ]))),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final showingSheet = _placesOpen || _journeys.current != null;
    final selected =
        _journeys.current == null && !_placesOpen ? _workspace.selected : null;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    final initial = widget.initialSpot;
    final initialCamera = _workspace.camera ??
        (initial != null && hasMapPosition(initial)
            ? TravelCamera(initial.lat, initial.lng, 15)
            : const TravelCamera(35.86, 104.20, 4));
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: context.lgIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: LayoutBuilder(
              builder: (context, constraints) => Stack(children: [
                    Positioned.fill(
                        child: AnimatedBuilder(
                            animation: _workspace,
                            builder: (context, _) => TravelMapCanvas(
                                key: _map,
                                initialCamera: initialCamera,
                                bottomOverlay: showingSheet
                                    ? constraints.maxHeight * _extent.value + 8
                                    : selected != null
                                        ? (largeText ? 290 : 200) + 20
                                        : 0,
                                places: _workspace.visiblePlaces,
                                journeyStops: _journeys.current == null
                                    ? null
                                    : _journeys.visible,
                                journeyLegs: _journeys.legs,
                                selectedStopKey: _journeys.selectedKey,
                                onStopSelect: _selectStop,
                                selectedId: _workspace.selectedId,
                                onCameraSettled: (value) =>
                                    _workspace.camera = value,
                                onSelect: _select,
                                onPick: _previewNew,
                                onReady: () {
                                  if (mounted) setState(() => _mapReady = true);
                                  _fitInitialPlaces();
                                  widget.onMapReady?.call();
                                }))),
                    Positioned(
                        top: 10, left: 14, right: 14, child: _mapHeader()),
                    ValueListenableBuilder<double>(
                        valueListenable: _extent,
                        builder: (context, extent, _) => showingSheet &&
                                extent > .60
                            ? const SizedBox.shrink()
                            : Positioned(
                                right: 16,
                                bottom: showingSheet
                                    ? constraints.maxHeight * extent + 14
                                    : selected != null
                                        ? (largeText ? 290.0 : 200.0) + 24
                                        : 84,
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      RebuildGlassButton(
                                          label: _locating ? '正在定位' : '定位到我',
                                          icon: Icons.my_location_outlined,
                                          onPressed: _locating || !_mapReady
                                              ? null
                                              : _locate),
                                      if (_locating)
                                        const Padding(
                                            padding: EdgeInsets.all(14),
                                            child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))),
                                      const SizedBox(height: 10),
                                      RebuildGlassButton(
                                          onPressed: _journeys.current == null
                                              ? _record
                                              : _addJourneyPlace,
                                          icon: Icons.add,
                                          label: _journeys.current == null
                                              ? '添加地点'
                                              : '加一站'),
                                    ]))),
                    if (!showingSheet && selected == null)
                      Positioned(
                          right: 16,
                          bottom: 16,
                          child: RebuildGlassButton(
                              label: '地点清单',
                              icon: Icons.format_list_bulleted,
                              showLabel: true,
                              onPressed: _openPlaces)),
                    if (selected != null)
                      Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          height: largeText ? 290 : 200,
                          child: _placeCard(selected)),
                    if (showingSheet)
                      NotificationListener<DraggableScrollableNotification>(
                        onNotification: (notification) {
                          _extent.value = notification.extent;
                          unawaited(_map.currentState?.setBottomOverlay(
                              constraints.maxHeight * notification.extent + 8));
                          return true;
                        },
                        child: DraggableScrollableSheet(
                            controller: _sheet,
                            initialChildSize: .42,
                            minChildSize: .16,
                            maxChildSize: .78,
                            snap: true,
                            snapSizes: const [.16, .30, .42, .78],
                            builder: (context, scrollController) => Material(
                                color: context.lgPaper,
                                elevation: 8,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(26)),
                                clipBehavior: Clip.antiAlias,
                                child: _journeys.current != null
                                    ? ValueListenableBuilder<double>(
                                        valueListenable: _extent,
                                        builder: (context, extent, _) =>
                                            JourneyPanel(
                                                controller: _journeys,
                                                scrollController:
                                                    scrollController,
                                                cardsController: _cards,
                                                expanded: extent > .52,
                                                onSelect: _selectStop,
                                                onAdd: _addJourneyPlace,
                                                onStory: _story))
                                    : AnimatedBuilder(
                                        animation: _workspace,
                                        builder: (context, _) {
                                          final places =
                                              _workspace.visiblePlaces;
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
                                                          color: context
                                                              .lgSeparator,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      4))),
                                                  Padding(
                                                      padding: const EdgeInsets
                                                          .fromLTRB(
                                                          20, 12, 10, 4),
                                                      child: Row(children: [
                                                        Expanded(
                                                            child: Text(
                                                                selected == null
                                                                    ? '我的地点'
                                                                    : selected
                                                                        .name,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: context
                                                                        .lgTextPrimary))),
                                                        if (selected != null)
                                                          IconButton(
                                                              tooltip: '返回地点列表',
                                                              onPressed: () =>
                                                                  _workspace
                                                                      .select(
                                                                          null),
                                                              icon: const Icon(
                                                                  Icons.close))
                                                        else
                                                          IconButton(
                                                              tooltip: '收起地点清单',
                                                              onPressed: () =>
                                                                  setState(() =>
                                                                      _placesOpen =
                                                                          false),
                                                              icon: const Icon(Icons
                                                                  .keyboard_arrow_down)),
                                                        IconButton(
                                                            tooltip: '刷新地点',
                                                            onPressed: _workspace
                                                                    .loading
                                                                ? null
                                                                : () => _workspace
                                                                    .load(
                                                                        refresh:
                                                                            true),
                                                            icon: const Icon(
                                                                Icons.refresh)),
                                                      ])),
                                                  if (_workspace.loading)
                                                    const LinearProgressIndicator(
                                                        minHeight: 2),
                                                  if (_workspace.error != null)
                                                    Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 16),
                                                        child: Row(children: [
                                                          Expanded(
                                                              child: Text(
                                                                  _workspace
                                                                      .error!,
                                                                  style: const TextStyle(
                                                                      color: LoveGirlTheme
                                                                          .red))),
                                                          TextButton(
                                                              onPressed: () =>
                                                                  _workspace.load(
                                                                      refresh:
                                                                          true),
                                                              child: const Text(
                                                                  '重试')),
                                                        ])),
                                                  if (selected == null)
                                                    SingleChildScrollView(
                                                        scrollDirection:
                                                            Axis.horizontal,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 16),
                                                        child: Row(children: [
                                                          for (final filter in [
                                                            ('', '全部'),
                                                            ('wish', '想去'),
                                                            ('planned', '计划中'),
                                                            ('visited', '已去')
                                                          ])
                                                            Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                        right:
                                                                            8),
                                                                child: ChoiceChip(
                                                                    showCheckmark:
                                                                        false,
                                                                    selectedColor:
                                                                        context
                                                                            .lgInk,
                                                                    backgroundColor: context
                                                                        .lgPaper,
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
                                                                    label: Text(
                                                                        filter.$2),
                                                                    selected: _workspace.status == filter.$1,
                                                                    onSelected: (_) => _workspace.setStatus(filter.$1))),
                                                        ])),
                                                ])),
                                                if (selected != null)
                                                  SliverToBoxAdapter(
                                                      child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .fromLTRB(20,
                                                                  8, 20, 32),
                                                          child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                _PlaceRow(
                                                                    place:
                                                                        selected,
                                                                    onTap: () =>
                                                                        _story(
                                                                            selected)),
                                                                const SizedBox(
                                                                    height: 12),
                                                                FilledButton(
                                                                    style: FilledButton.styleFrom(
                                                                        backgroundColor:
                                                                            context
                                                                                .lgInk,
                                                                        foregroundColor:
                                                                            context
                                                                                .lgPaper),
                                                                    onPressed: () =>
                                                                        _story(
                                                                            selected),
                                                                    child: const Text(
                                                                        '照片与故事')),
                                                                Row(children: [
                                                                  TextButton.icon(
                                                                      style: TextButton.styleFrom(
                                                                          foregroundColor: context
                                                                              .lgInk),
                                                                      onPressed: () =>
                                                                          _edit(
                                                                              selected),
                                                                      icon: const Icon(
                                                                          Icons
                                                                              .edit_outlined),
                                                                      label: const Text(
                                                                          '编辑地点')),
                                                                  const Spacer(),
                                                                  TextButton.icon(
                                                                      style: TextButton.styleFrom(
                                                                          foregroundColor: context
                                                                              .lgInk),
                                                                      onPressed: _deleting
                                                                          ? null
                                                                          : () => _delete(
                                                                              selected),
                                                                      icon: const Icon(
                                                                          Icons
                                                                              .delete_outline),
                                                                      label: Text(_deleting
                                                                          ? '删除中…'
                                                                          : '删除')),
                                                                ]),
                                                              ])))
                                                else if (places.isEmpty)
                                                  const SliverToBoxAdapter(
                                                      child: Padding(
                                                          padding: EdgeInsets
                                                              .fromLTRB(24, 20,
                                                                  24, 40),
                                                          child: Text(
                                                              '还没有这些地点。搜索或长按地图，就可以记下想去的地方。')))
                                                else
                                                  SliverList.builder(
                                                      itemCount: places.length,
                                                      itemBuilder: (context,
                                                              index) =>
                                                          _PlaceRow(
                                                              place:
                                                                  places[index],
                                                              onTap: () => _select(
                                                                  places[index],
                                                                  focus:
                                                                      true))),
                                                const SliverToBoxAdapter(
                                                    child:
                                                        SizedBox(height: 24)),
                                              ]);
                                        }))),
                      ),
                  ])),
        ));
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
