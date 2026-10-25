import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/travel.dart';
import '../../utils/lovegirl_theme.dart';
import '../creations/creation_gallery.dart';
import 'journey.dart';
import 'journey_controller.dart';

Future<void> journeyDetails(BuildContext context, JourneyController controller,
    {bool edit = false}) async {
  final old = edit ? controller.current : null;
  final title = TextEditingController(text: old?.title ?? '我们的旅行');
  final city = TextEditingController(text: old?.city ?? '');
  final days = TextEditingController(text: '${old?.days ?? 3}');
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
                  TextField(
                      controller: title,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: '旅行名称')),
                  TextField(
                      controller: city,
                      maxLength: 50,
                      decoration:
                          const InputDecoration(labelText: '主要城市（公交路线使用）')),
                  TextField(
                      controller: days,
                      keyboardType: TextInputType.number,
                      readOnly: range != null,
                      decoration: const InputDecoration(labelText: '天数（1—90）')),
                  TextButton.icon(
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
                          days.text = '${picked.duration.inDays + 1}';
                          error = null;
                        });
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(range == null
                          ? '选择旅行日期（可选）'
                          : '${range!.start.toString().substring(0, 10)} — ${range!.end.toString().substring(0, 10)}')),
                  if (range != null)
                    TextButton(
                        onPressed: () => update(() => range = null),
                        child: const Text('暂不定日期')),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        final count = int.tryParse(days.text);
                        if (title.text.trim().isEmpty ||
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
    final count = int.parse(days.text);
    final start = range?.start.toIso8601String().substring(0, 10);
    final end = range?.end.toIso8601String().substring(0, 10);
    if (old != null) {
      controller.update(old.copyWith(
          title: title.text.trim(),
          city: city.text.trim(),
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
          title: title.text.trim(),
          city: city.text.trim(),
          days: count,
          startDate: start,
          endDate: end);
    }
  }
  title.dispose();
  city.dispose();
  days.dispose();
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
                                title: Text(j.title),
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
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child:
                                                            const Text('保留')),
                                                    TextButton(
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
                                title: Text(j.title),
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
    final note = TextEditingController(text: stop.note);
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
                  TextField(
                      controller: note,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(labelText: '这一站的备注')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, 'note'),
                      child: const Text('保存备注')),
                  Wrap(spacing: 8, children: [
                    ActionChip(
                        label: const Text('移到待计划'),
                        onPressed: () => Navigator.pop(context, 'pending')),
                    for (var i = 0; i < j.days; i++)
                      ActionChip(
                          label: Text('第 ${i + 1} 天'),
                          onPressed: () => Navigator.pop(context, 'day_$i'))
                  ]),
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
    if (action == 'note') {
      controller.update(j.copyWith(
          stops: j.stops
              .map((s) =>
                  s.key == stop.key ? s.copyWith(note: note.text.trim()) : s)
              .toList()));
    }
    if (action == 'pending') controller.update(j.move({stop.key}, null));
    if (action?.startsWith('day_') == true) {
      controller.update(j.move({stop.key}, int.parse(action!.substring(4))));
    }
    if (action == 'remove') controller.update(j.remove({stop.key}));
    if (action == 'story' && stop.place != null) onStory(stop.place!);
    note.dispose();
  }

  Future<void> _mode(BuildContext context, JourneyStop stop) async {
    final mode = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ListTile(
                  title: Text('到达这一站的交通方式'), subtitle: Text('时间与距离来自真实路线规划')),
              for (final entry in journeyModes.entries)
                ListTile(
                    leading: Icon(_icon(entry.key)),
                    title: Text(entry.value),
                    trailing:
                        stop.mode == entry.key ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, entry.key)),
            ])));
    if (mode != null) {
      controller.update(controller.current!.copyWith(
          stops: controller.current!.stops
              .map((s) => s.key == stop.key ? s.copyWith(mode: mode) : s)
              .toList()));
    }
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
                                  builder: (_) =>
                                      CreationGallery(tripId: j.id)));
                        }
                        if (action == 'tickets' && context.mounted) {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CreationGallery(
                                      kind: 'ticket', tripId: j.id)));
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
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('保留')),
                                        TextButton(
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
                              onPressed: controller.reloadLatest,
                              child: const Text('保留当前草稿，查看最新版本'))
                      ])),
            SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                          label: const Text('总览'),
                          selected: controller.overview,
                          onSelected: (_) =>
                              controller.setDay(null, all: true))),
                  for (var d = 0; d < j.days; d++)
                    Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                            label: Text('第 ${d + 1} 天'),
                            selected:
                                !controller.overview && controller.day == d,
                            onSelected: (_) => controller.setDay(d))),
                  ChoiceChip(
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
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('添加地点'))
                    ]))),
          if (stops.isNotEmpty && !expanded)
            SliverToBoxAdapter(
                child: SizedBox(
                    height: 160,
                    child: ListView.separated(
                        controller: cardsController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                        itemCount: stops.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) => SizedBox(
                            width: 250,
                            child:
                                _card(context, stops[i], i, compact: true))))),
          if (expanded)
            SliverReorderableList(
                itemCount: stops.length,
                onReorder: (oldIndex, newIndex) {
                  if (!controller.overview) {
                    controller
                        .update(j.reorder(controller.day, oldIndex, newIndex));
                  }
                },
                itemBuilder: (context, i) => Padding(
                    key: ValueKey(stops[i].key),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: _card(context, stops[i], i))),
          if (stops.isNotEmpty)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    child: Row(children: [
                      Expanded(
                          child: OutlinedButton.icon(
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
    final leg = controller.legs.where((l) => l.toKey == stop.key);
    return Material(
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
                        CircleAvatar(
                            radius: 13,
                            backgroundColor: selected
                                ? context.lgInk
                                : const Color(0xff3398ae),
                            foregroundColor: Colors.white,
                            child: Text('${index + 1}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(stop.place?.name ?? '地点已不可用',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                        if (!compact && !controller.overview)
                          ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle, size: 20))),
                        IconButton(
                            tooltip: '移动、备注或移除',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _stopMenu(context, stop),
                            icon: const Icon(Icons.more_horiz, size: 20)),
                      ]),
                      if (controller.overview)
                        Text(stop.day == null ? '待计划' : '第 ${stop.day! + 1} 天',
                            style: TextStyle(
                                fontSize: 11, color: context.lgTextSecondary)),
                      if (stop.note.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(left: 34, right: 10),
                            child: Text(stop.note,
                                maxLines: compact ? 1 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.lgTextSecondary))),
                      if (index > 0 && stop.day != null)
                        TextButton.icon(
                            onPressed: () => _mode(context, stop),
                            icon: Icon(_icon(stop.mode), size: 16),
                            label: Text(
                                leg.isNotEmpty
                                    ? leg.first.summary
                                    : '${journeyModes[stop.mode]} · ${controller.routing ? '规划中' : '选择交通方式'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10))),
                    ]))));
  }
}
