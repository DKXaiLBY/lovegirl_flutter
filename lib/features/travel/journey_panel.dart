import '../../widgets/rebuild_controls.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/travel.dart';
import '../../utils/lovegirl_theme.dart';
import '../creations/creation_gallery.dart';
import '../creations/creation_files.dart';
import 'journey.dart';
import 'journey_controller.dart';

// Official URI API: https://lbs.amap.com/api/uri-api/guide/travel/route
Uri journeyNavigationUri(TravelSpot from, TravelSpot to, String mode) =>
    Uri.https('uri.amap.com', '/navigation', {
      'from': '${from.lng},${from.lat},${from.name.replaceAll(',', '，')}',
      'to': '${to.lng},${to.lat},${to.name.replaceAll(',', '，')}',
      'mode': const {
            'walking': 'walk',
            'bicycling': 'ride',
            'transit': 'bus',
            'driving': 'car'
          }[mode] ??
          'car',
      'src': 'LoveGirl',
      'callnative': '1',
    });

Future<void> journeyDetails(BuildContext context, JourneyController controller,
    {bool edit = false}) async {
  final old = edit ? controller.current : null;
  var title = old?.title ?? '我们的旅行';
  var city = old?.city ?? '';
  var days = '${old?.days ?? 3}';
  DateTimeRange? range = old?.startDate == null
      ? null
      : DateTimeRange(
          start: DateTime.parse(old!.startDate!),
          end: DateTime.parse(old.endDate!));
  String? error;
  final result = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
                title: Text(edit ? '行程信息' : '新的旅行'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      initialValue: title,
                      onChanged: (v) => title = v,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: '旅行名称')),
                  TextFormField(
                      initialValue: city,
                      onChanged: (v) => city = v,
                      maxLength: 50,
                      decoration:
                          const InputDecoration(labelText: '主要城市（公交路线使用）')),
                  TextFormField(
                      initialValue: days,
                      onChanged: (v) => days = v,
                      key: ValueKey(range?.start.toIso8601String()),
                      keyboardType: TextInputType.number,
                      readOnly: range != null,
                      decoration: const InputDecoration(labelText: '天数（1—90）')),
                  TextButton.icon(
                      style: rebuildTextStyle(context),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDateRange: range);
                        if (picked == null) return;
                        if (picked.duration.inDays >= 90) {
                          update(() => error = '日期最多跨度90天');
                          return;
                        }
                        update(() {
                          range = picked;
                          days = '${picked.duration.inDays + 1}';
                          error = null;
                        });
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(range == null
                          ? '选择旅行日期（可选）'
                          : '${range!.start.toString().substring(0, 10)} — ${range!.end.toString().substring(0, 10)}')),
                  if (range != null)
                    TextButton(
                        style: rebuildTextStyle(context),
                        onPressed: () => update(() => range = null),
                        child: const Text('暂不定日期')),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ])),
                actions: [
                  TextButton(
                      style: rebuildTextStyle(context),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      style: rebuildFilledStyle(context),
                      onPressed: () {
                        final count = int.tryParse(days);
                        if (title.trim().isEmpty ||
                            count == null ||
                            count < 1 ||
                            count > 90) {
                          update(() => error = '请输入名称和1至90天的天数');
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('完成'))
                ],
              )));
  if (result == true) {
    final count = int.parse(days);
    final start = range?.start.toIso8601String().substring(0, 10);
    final end = range?.end.toIso8601String().substring(0, 10);
    if (old != null) {
      controller.update(old.copyWith(
          title: title.trim(),
          city: city.trim(),
          days: count,
          startDate: start,
          endDate: end,
          clearDates: range == null,
          stops: old.stops
              .map((s) => s.day != null && s.day! >= count
                  ? s.copyWith(unplanned: true)
                  : s)
              .toList()));
      if (controller.day != null && controller.day! >= count) {
        controller.setDay(0);
      }
    } else {
      controller.create(
          title: title.trim(),
          city: city.trim(),
          days: count,
          startDate: start,
          endDate: end);
    }
  }
}

Future<void> showJourneyLibrary(
    BuildContext context, JourneyController controller) async {
  final hostContext = context;
  await controller.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            Row(children: [
                              const Expanded(
                                  child: Text('我们的旅行',
                                      style: TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w700))),
                              FilledButton.icon(
                                  style: rebuildFilledStyle(context),
                                  onPressed: controller.busy
                                      ? null
                                      : () async {
                                          Navigator.pop(context);
                                          await journeyDetails(
                                              hostContext, controller);
                                        },
                                  icon: const Icon(Icons.add),
                                  label: const Text('新建'))
                            ]),
                            ListTile(
                                leading: const Icon(Icons.place_outlined),
                                title: const Text('全部地点与足迹'),
                                onTap: () {
                                  controller.select(null);
                                  Navigator.pop(context);
                                }),
                            if (controller.error != null)
                              Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(controller.error!)),
                            if (controller.localDrafts.isNotEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('本机私密草稿',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700))),
                            ...controller.localDrafts.map((j) => ListTile(
                                leading: const Icon(Icons.edit_note),
                                title: Text(j.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '${j.days}天 · ${j.stops.length}个地点 · 未提交修改'),
                                onTap: () {
                                  controller.select(j, draft: true);
                                  Navigator.pop(context);
                                },
                                trailing: IconButton(
                                    tooltip: '删除本机草稿',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final accepted = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                                  title:
                                                      const Text('删除未提交的修改？'),
                                                  content:
                                                      const Text('已共享的行程不受影响。'),
                                                  actions: [
                                                    TextButton(
                                                        style: rebuildTextStyle(
                                                            context),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child:
                                                            const Text('保留')),
                                                    TextButton(
                                                        style: rebuildTextStyle(
                                                            context),
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child:
                                                            const Text('删除草稿'))
                                                  ]));
                                      if (accepted == true) {
                                        await controller.discardDraft(j);
                                      }
                                    }))),
                            const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('已共享行程',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700))),
                            if (controller.library.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('创建一份行程，把想去的地方安排到每天。')),
                            ...controller.library.map((j) => ListTile(
                                leading: const Icon(Icons.route_outlined),
                                title: Text(j.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '${j.days}天 · ${j.stops.length}个地点${j.startDate == null ? '' : ' · ${j.startDate}'}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  controller.select(j);
                                  Navigator.pop(context);
                                })),
                          ])))));
}

class JourneyPanel extends StatelessWidget {
  final JourneyController controller;
  final ScrollController scrollController;
  final ScrollController cardsController;
  final bool expanded;
  final ValueChanged<JourneyStop> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<TravelSpot> onStory;
  const JourneyPanel(
      {super.key,
      required this.controller,
      required this.scrollController,
      required this.cardsController,
      required this.expanded,
      required this.onSelect,
      required this.onAdd,
      required this.onStory});

  Future<void> _stopMenu(BuildContext context, JourneyStop stop) async {
    final j = controller.current!;
    var note = stop.note;
    final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(stop.place?.name ?? '地点已不可用'),
                      subtitle: const Text('以下修改只影响当前行程中的这一站')),
                  TextFormField(
                      initialValue: note,
                      onChanged: (v) => note = v,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(labelText: '这一站的备注')),
                  FilledButton(
                      style: rebuildFilledStyle(context),
                      onPressed: () => Navigator.pop(context, 'note'),
                      child: const Text('保存备注')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                      value: stop.day ?? -1,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '移动到哪一天'),
                      items: [
                        const DropdownMenuItem(value: -1, child: Text('待计划')),
                        for (var i = 0; i < j.days; i++)
                          DropdownMenuItem(
                              value: i, child: Text('第 ${i + 1} 天'))
                      ],
                      onChanged: (day) {
                        if (day != null) {
                          Navigator.pop(
                              context, day == -1 ? 'pending' : 'day_$day');
                        }
                      }),
                  ListTile(
                      leading: const Icon(Icons.remove_circle_outline),
                      title: const Text('从行程移除'),
                      onTap: () => Navigator.pop(context, 'remove')),
                  if (stop.place != null)
                    ListTile(
                        leading: const Icon(Icons.auto_stories_outlined),
                        title: const Text('照片与故事'),
                        onTap: () => Navigator.pop(context, 'story')),
                ])))));
    if (action == null) return;
    final edited = j.copyWith(
        stops: j.stops
            .map((s) => s.key == stop.key ? s.copyWith(note: note.trim()) : s)
            .toList());
    if (action == 'note') controller.update(edited);
    if (action == 'pending') controller.update(edited.move({stop.key}, null));
    if (action.startsWith('day_')) {
      controller
          .update(edited.move({stop.key}, int.parse(action.substring(4))));
    }
    if (action == 'remove') controller.update(edited.remove({stop.key}));
    if (action == 'story' && stop.place != null) {
      if (note.trim() != stop.note) controller.update(edited);
      onStory(stop.place!);
    }
  }

  Future<void> _mode(BuildContext context, JourneyStop stop) async {
    var selected = stop.mode;
    final estimates = {
      for (final key in journeyModes.keys)
        key: controller.alternative(stop, key)
    };
    final mode = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setSheet) => SafeArea(
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                  const ListTile(
                      title: Text('到达这一站的交通方式'),
                      subtitle: Text('时间与距离来自真实路线规划')),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: context.lgPrimarySoft,
                              borderRadius: BorderRadius.circular(18)),
                          child: Column(children: [
                            _routeEndpoint(
                                context,
                                controller.previousStop(stop)?.place?.name ??
                                    '上一站',
                                false),
                            const SizedBox(height: 12),
                            _routeEndpoint(
                                context, stop.place?.name ?? '地点已不可用', true),
                          ]))),
                  for (final entry in journeyModes.entries)
                    FutureBuilder<JourneyLeg>(
                        future: estimates[entry.key],
                        builder: (context, snapshot) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 4),
                            child: AnimatedContainer(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                    color: selected == entry.key
                                        ? context.lgPrimarySoft
                                        : context.lgPaper,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: selected == entry.key
                                            ? context.lgInk
                                            : context.lgSeparator)),
                                child: RadioListTile<String>(
                                  activeColor: context.lgInk,
                                  value: entry.key,
                                  groupValue: selected,
                                  secondary: Icon(_icon(entry.key)),
                                  title: Text(entry.value),
                                  subtitle: Text(
                                      snapshot.data?.estimate ?? '正在规划…',
                                      style: const TextStyle(fontSize: 12)),
                                  onChanged: (value) =>
                                      setSheet(() => selected = value!),
                                )))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                                style: rebuildFilledStyle(context),
                                onPressed: () =>
                                    Navigator.pop(context, selected),
                                child: Text('采用${journeyModes[selected]}')),
                            TextButton.icon(
                                style: rebuildTextStyle(context),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('在高德地图中查看／导航'),
                                onPressed: () async {
                                  final a =
                                      controller.previousStop(stop)?.place;
                                  final b = stop.place;
                                  if (a == null || b == null) return;
                                  final uri =
                                      journeyNavigationUri(a, b, selected);
                                  try {
                                    if (!await launchUrl(uri,
                                        mode: LaunchMode.externalApplication)) {
                                      throw StateError('无法打开地图');
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('外部地图未能打开，请稍后重试')));
                                    }
                                  }
                                })
                          ])),
                ])))));
    if (mode != null) {
      controller.update(controller.current!.copyWith(
          stops: controller.current!.stops
              .map((s) => s.key == stop.key ? s.copyWith(mode: mode) : s)
              .toList()));
    }
  }

  Widget _routeEndpoint(BuildContext context, String name, bool destination) =>
      Row(children: [
        Icon(destination ? Icons.location_on_outlined : Icons.trip_origin,
            size: 18,
            color: destination
                ? const Color(0xff24798e)
                : context.lgTextSecondary),
        const SizedBox(width: 12),
        Expanded(
            child: Text(name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600))),
      ]);

  String _dateLabel(String start, int day) {
    final date = DateTime.parse(start).add(Duration(days: day));
    return '${date.month}.${date.day}';
  }

  IconData _icon(String mode) => switch (mode) {
        'walking' => Icons.directions_walk,
        'bicycling' => Icons.pedal_bike,
        'transit' => Icons.directions_transit,
        _ => Icons.directions_car_outlined
      };

  @override
  Widget build(BuildContext context) {
    final j = controller.current!;
    final stops = controller.visible;
    return AbsorbPointer(
        absorbing: controller.busy,
        child: CustomScrollView(controller: scrollController, slivers: [
          SliverToBoxAdapter(
              child: Column(children: [
            const SizedBox(height: 10),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: context.lgSeparator,
                    borderRadius: BorderRadius.circular(4))),
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(children: [
                  Expanded(
                      child: InkWell(
                          onTap: () =>
                              journeyDetails(context, controller, edit: true),
                          child: Text(j.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w800)))),
                  if (controller.dirty)
                    FilledButton(
                        style: rebuildFilledStyle(context),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          final saved = await controller.save();
                          if (context.mounted && saved) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('行程已共享')));
                          }
                        },
                        child: const Text('保存')),
                  PopupMenuButton<String>(
                      tooltip: '行程更多',
                      onSelected: (action) async {
                        if (action == 'refresh') {
                          await controller.reloadLatest();
                        }
                        if (action == 'edit' && context.mounted) {
                          await journeyDetails(context, controller, edit: true);
                        }
                        if (action == 'works' && context.mounted) {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CreationGallery(
                                      tripId: j.id, tripTitle: j.title)));
                        }
                        if (action == 'tickets' && context.mounted) {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CreationGallery(
                                      kind: 'ticket',
                                      tripId: j.id,
                                      tripTitle: j.title,
                                      tripDate: j.startDate)));
                        }
                        if (action == 'delete' && context.mounted) {
                          final yes = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                      title: const Text('删除这份行程？'),
                                      content:
                                          const Text('原地点、照片和作品会保留，作品将解除旅行关联。'),
                                      actions: [
                                        TextButton(
                                            style: rebuildTextStyle(context),
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('保留')),
                                        TextButton(
                                            style: rebuildTextStyle(context),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('删除行程'))
                                      ]));
                          if (yes == true) await controller.deleteCurrent();
                        }
                      },
                      itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('行程信息')),
                            const PopupMenuItem(
                                value: 'refresh', child: Text('查看最新版本（保留草稿）')),
                            if (j.id != null)
                              const PopupMenuItem(
                                  value: 'works', child: Text('旅行拍立得')),
                            if (j.id != null)
                              const PopupMenuItem(
                                  value: 'tickets', child: Text('旅行票根')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('删除行程'))
                          ]),
                ])),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          '${j.days} 天 · ${j.stops.length} 站${controller.dirty ? ' · 私密草稿未共享' : ' · 两人共同编辑'}',
                          style: TextStyle(
                              fontSize: 11, color: context.lgTextSecondary))),
                  if (controller.routing)
                    const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2))
                ])),
            if (controller.error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(controller.error!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red)),
                        if (controller.conflict)
                          TextButton(
                              style: rebuildTextStyle(context),
                              onPressed: controller.reloadLatest,
                              child: const Text('保留当前草稿，查看最新版本'))
                      ])),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: RebuildChoiceChip(
                          label: const Text('总览'),
                          selected: controller.overview,
                          onSelected: (_) =>
                              controller.setDay(null, all: true))),
                  for (var d = 0; d < j.days; d++)
                    Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: RebuildChoiceChip(
                            label: Text(j.startDate == null
                                ? '第 ${d + 1} 天'
                                : _dateLabel(j.startDate!, d)),
                            selected:
                                !controller.overview && controller.day == d,
                            onSelected: (_) => controller.setDay(d))),
                  RebuildChoiceChip(
                      label: Text('待计划 ${j.dayStops(null).length}'),
                      selected: !controller.overview && controller.day == null,
                      onSelected: (_) => controller.setDay(null)),
                ])),
          ])),
          if (stops.isEmpty)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Text(
                          controller.day == null && !controller.overview
                              ? '先收藏想去的地方，再安排日期'
                              : '今天想一起去哪里？',
                          style: TextStyle(color: context.lgTextSecondary)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                          style: rebuildFilledStyle(context),
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('添加地点'))
                    ]))),
          if (stops.isNotEmpty && !expanded)
            SliverToBoxAdapter(
              child: SizedBox(
                  height: 170.0 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.8),
                  child: NotificationListener<ScrollEndNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis == Axis.horizontal &&
                            stops.isNotEmpty) {
                          final index = (notification.metrics.pixels / 260)
                              .round()
                              .clamp(0, stops.length - 1);
                          if (controller.selectedKey != stops[index].key) {
                            onSelect(stops[index]);
                          }
                        }
                        return false;
                      },
                      child: ListView.separated(
                          controller: cardsController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                          itemCount: stops.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) => SizedBox(
                              width: 250,
                              child: _card(context, stops[i], i,
                                  compact: true))))),
            ),
          if (expanded)
            SliverReorderableList(
                itemCount: stops.length,
                onReorder: (oldIndex, newIndex) {
                  if (!controller.overview) {
                    controller
                        .update(j.reorder(controller.day, oldIndex, newIndex));
                  }
                },
                itemBuilder: (context, i) => _timelineStop(context, stops, i)),
          if (stops.isNotEmpty)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    child: Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
                              style: rebuildOutlinedStyle(context),
                              onPressed: onAdd,
                              icon: const Icon(Icons.add),
                              label: const Text('添加地点'))),
                      const SizedBox(width: 8),
                      IconButton(
                          tooltip: '重新规划路线',
                          onPressed: () => controller.routes(retry: true),
                          icon: const Icon(Icons.refresh))
                    ]))),
        ]));
  }

  Widget _card(BuildContext context, JourneyStop stop, int index,
      {bool compact = false}) {
    final selected = controller.selectedKey == stop.key;
    final hasPrevious = index > 0 &&
        stop.day != null &&
        controller.visible[index - 1].day == stop.day;
    final city = stop.place?.city ?? '';
    final cover = stop.place?.coverImage;
    final photo = cover?.isNotEmpty == true
        ? cover
        : (stop.place?.photos.isNotEmpty == true
            ? stop.place!.photos.first
            : null);
    final leg = controller.legs.where((l) => l.toKey == stop.key);
    final detailIndent = (photo != null ? (compact ? 54.0 : 70.0) : 0.0) +
        (compact ? 34.0 : 0.0);
    return AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color:
                    selected ? const Color(0xff6396a6) : context.lgSeparator)),
        child: Material(
            color: selected ? context.lgPrimarySoft : context.lgCard,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => onSelect(stop),
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            if (photo != null) ...[
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                      imageUrl: creationUrl(photo),
                                      width: compact ? 44 : 60,
                                      height: compact ? 44 : 60,
                                      memCacheWidth: 180,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                          color: context.lgPrimarySoft,
                                          child: const Icon(
                                              Icons.photo_outlined,
                                              size: 20)))),
                              const SizedBox(width: 10),
                            ],
                            if (compact)
                              CircleAvatar(
                                  radius: 13,
                                  backgroundColor: selected
                                      ? context.lgInk
                                      : const Color(0xff24798e),
                                  foregroundColor:
                                      selected ? context.lgPaper : Colors.white,
                                  child: Text('${index + 1}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700))),
                            if (compact) const SizedBox(width: 8),
                            Expanded(
                                child: Text(stop.place?.name ?? '地点已不可用',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            if (!compact && !controller.overview)
                              ReorderableDragStartListener(
                                  index: index,
                                  child: const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Center(
                                          child: Icon(Icons.drag_handle,
                                              size: 20)))),
                            IconButton(
                                tooltip: '移动、备注或移除',
                                constraints: const BoxConstraints(
                                    minWidth: 48, minHeight: 48),
                                onPressed: () => _stopMenu(context, stop),
                                icon: const Icon(Icons.more_horiz, size: 20)),
                          ]),
                          if (city.isNotEmpty)
                            Padding(
                                padding: EdgeInsets.only(
                                    left: detailIndent, bottom: 4),
                                child: Text(city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.lgTextSecondary))),
                          if (!hasPrevious && !controller.overview)
                            Padding(
                                padding:
                                    EdgeInsets.only(left: detailIndent, top: 6),
                                child: Text(
                                    stop.day == null ? '待安排日期' : '当天第一站',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.lgTextSecondary))),
                          if (controller.overview && compact)
                            Text(
                                stop.day == null
                                    ? '待计划'
                                    : '第 ${stop.day! + 1} 天',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.lgTextSecondary)),
                          if (stop.note.isNotEmpty)
                            Padding(
                                padding: EdgeInsets.only(
                                    left: detailIndent, right: 10),
                                child: Text(stop.note,
                                    maxLines: compact ? 1 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.lgTextSecondary))),
                          if (hasPrevious)
                            TextButton.icon(
                                style: rebuildTextStyle(context),
                                onPressed: () => _mode(context, stop),
                                icon: Icon(_icon(stop.mode), size: 16),
                                label: Text(
                                    leg.isNotEmpty
                                        ? leg.first.summary
                                        : '${journeyModes[stop.mode]} · ${controller.routing ? '规划中' : '选择交通方式'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10))),
                        ])))));
  }

  Widget _timelineStop(
      BuildContext context, List<JourneyStop> stops, int index) {
    final stop = stops[index];
    final newDay = index == 0 || stops[index - 1].day != stop.day;
    final connects = stop.day != null &&
        index + 1 < stops.length &&
        stops[index + 1].day == stop.day;
    final selected = controller.selectedKey == stop.key;
    bool hasPhoto(JourneyStop s) =>
        s.place?.coverImage?.isNotEmpty == true ||
        s.place?.photos.isNotEmpty == true;
    final circleTop = hasPhoto(stop) ? 28.0 : 22.0;
    final nextCircleTop = connects && hasPhoto(stops[index + 1]) ? 28.0 : 22.0;
    return Padding(
        key: ValueKey(stop.key),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (controller.overview && newDay)
            Padding(
                padding: const EdgeInsets.fromLTRB(34, 16, 0, 12),
                child: Text(stop.day == null ? '待计划' : '第 ${stop.day! + 1} 天',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700))),
          Stack(clipBehavior: Clip.none, children: [
            if (connects)
              Positioned(
                  left: 12.5,
                  top: circleTop + 26,
                  bottom: -nextCircleTop,
                  child: Container(
                      width: 1,
                      color: context.lgIsDark
                          ? const Color(0xff4b5865)
                          : const Color(0xffc3d3dc))),
            Padding(
                padding: const EdgeInsets.only(left: 34, bottom: 12),
                child: _card(context, stop, index)),
            Positioned(
                left: 0,
                top: circleTop,
                child: CircleAvatar(
                    radius: 13,
                    backgroundColor:
                        selected ? context.lgInk : const Color(0xff24798e),
                    foregroundColor: selected ? context.lgPaper : Colors.white,
                    child: Text('${index + 1}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)))),
          ]),
        ]));
  }
}
