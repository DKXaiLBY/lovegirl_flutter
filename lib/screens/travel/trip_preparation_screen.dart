import 'package:cached_network_image/cached_network_image.dart';
import 'package:lovegirl_flutter/services/app_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovegirl_flutter/utils/app_haptics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../features/travel/journey.dart';
import '../../features/travel/trip_preparation.dart';
import '../../models/wardrobe.dart' show wnImgUrl;
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import 'package:lovegirl_flutter/widgets/glass_routes.dart';

class TripPreparationScreen extends StatefulWidget {
  final int tripId;
  final Journey? journey;
  final VoidCallback? onViewJourney;
  final ApiService? api;

  const TripPreparationScreen({
    super.key,
    required this.tripId,
    this.journey,
    this.onViewJourney,
    this.api,
  });

  @override
  State<TripPreparationScreen> createState() => _TripPreparationScreenState();
}

class _TripPreparationScreenState extends State<TripPreparationScreen> {
  late final _api = widget.api ?? ApiService();
  TripPreparation? _data;
  int? _account;
  int _request = 0;
  int _session = 0;
  int _day = 0;
  bool _shared = false;
  String? _category;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String get _path => '/api/travel-preparation/${widget.tripId}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = context.watch<AuthProvider>().userId;
    if (account == _account) return;
    _account = account;
    _request++;
    _session++;
    _data = null;
    _day = 0;
    _shared = false;
    _category = null;
    _saving = false;
    if (account != null) _load();
  }

  bool _sameAccount(int? account) =>
      mounted &&
      account != null &&
      context.read<AuthProvider>().userId == account;

  Future<void> _load() async {
    final account = _account;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.get(_path);
      final data = TripPreparation.fromJson(response.data['data'] as Map);
      if (!_sameAccount(account) || request != _request) return;
      setState(() {
        _data = data;
        if (_day >= data.days &&
            !data.mine.outfits.any((outfit) => outfit.day == _day)) {
          _day = 0;
        }
      });
    } catch (e) {
      if (!_sameAccount(account) || request != _request) return;
      setState(() {
        final status = e is DioException ? e.response?.statusCode : null;
        if ([401, 403, 404].contains(status)) _data = null;
        _error = extractServerMessage(e, fallback: '旅行准备加载失败，可以重试');
      });
    } finally {
      if (_sameAccount(account) && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _write({
    required int? account,
    required bool shared,
    required String? relationship,
    List<PackingItem> Function(PreparationList)? items,
    List<PreparationOutfit> Function(PreparationList)? outfits,
  }) async {
    if (!_sameAccount(account)) return '账号已切换，请重新打开旅行准备';
    final session = _session;
    bool isCurrent() => _session == session && _sameAccount(account);
    final data = _data;
    final list = shared ? data?.shared : data?.mine;
    if (data == null || list == null || data.archived) return '这份清单已无法编辑';
    if (shared && relationship != data.relationshipKey) {
      return '绑定关系已变化，请关闭后重新打开共同清单';
    }
    if (_saving || _loading || _error != null) return '请先读取最新清单';
    setState(() => _saving = true);
    try {
      final response =
          await _api.put('$_path/${shared ? 'shared' : 'private'}', data: {
        'revision': list.revision,
        'items': (items?.call(list) ?? list.items)
            .map((item) => item.toJson())
            .toList(),
        'outfits': (outfits?.call(list) ?? list.outfits)
            .map((outfit) => outfit.toJson())
            .toList(),
        if (shared) 'relationshipKey': relationship,
      });
      if (!isCurrent()) return '账号已切换';
      final saved = PreparationList.fromJson(response.data['data'] as Map);
      setState(() => _data = data.update(saved, isShared: shared));
      return null;
    } catch (e) {
      if (!isCurrent()) return '账号已切换';
      if (e is DioException && [403, 409].contains(e.response?.statusCode)) {
        await _load();
        if (isCurrent() && e.response?.statusCode == 409 && _error == null) {
          if (_data?.archived == true) return '行程已归档，准备记录可以继续查看';
          if (shared && relationship != _data?.relationshipKey) {
            return '绑定关系已变化，请关闭后重新打开共同清单';
          }
          return '清单已刷新，请核对后再保存';
        }
      }
      return extractServerMessage(e, fallback: '保存失败，可以重试');
    } finally {
      if (isCurrent()) setState(() => _saving = false);
    }
  }

  String _person(int? id) {
    if (id == null) return '待分工';
    if (id == _account) return '我携带';
    final name = _data?.people[id];
    return name == null || name.isEmpty ? '对方携带' : '$name 携带';
  }

  void _notice(String? error) {
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _editItem([PackingItem? item]) async {
    final account = _account;
    final session = _session;
    final shared = _shared;
    final data = _data!;
    final key = item?.key ?? const Uuid().v4();
    var label = item?.label ?? '';
    var category = item?.category ?? 'other';
    var carrier = item?.assigneeId;
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (dialog, update) {
        if (dialog.watch<AuthProvider>().userId != account ||
            session != _session) {
          return GlassAlertDialog(title: const Text('账号已切换'), actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialog), child: const Text('关闭'))
          ]);
        }
        return GlassAlertDialog(
          scrollable: true,
          title: Text(item == null ? '添加物品' : '编辑物品'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
                initialValue: label,
                enabled: !saving,
                autofocus: item == null,
                maxLength: 100,
                decoration: const InputDecoration(labelText: '物品名称'),
                onChanged: (text) => label = text),
            DropdownButtonFormField<String>(
                value: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '分类'),
                items: [
                  for (final entry in packingCategories.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value))
                ],
                onChanged: saving ? null : (value) => category = value!),
            if (shared)
              DropdownButtonFormField<int>(
                value: carrier ?? 0,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '携带人'),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('待分工')),
                  for (final id in data.people.keys)
                    DropdownMenuItem(value: id, child: Text(_person(id)))
                ],
                onChanged: saving
                    ? null
                    : (value) => carrier = value == 0 ? null : value,
              ),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(dialog).colorScheme.error))),
          ]),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialog),
                child: const Text('取消')),
            if (_error != null)
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() => saving = true);
                        await _load();
                        if (dialog.mounted) {
                          update(() {
                            saving = false;
                            error = _error ?? '清单已刷新，请核对后再保存';
                          });
                        }
                      },
                child: const Text('刷新清单'),
              ),
            FilledButton(
                style: rebuildFilledStyle(dialog),
                onPressed: saving
                    ? null
                    : () async {
                        final value = label.trim();
                        if (value.isEmpty) {
                          update(() => error = '请填写物品名称');
                          return;
                        }
                        final list = shared ? _data?.shared : _data?.mine;
                        final latest = list?.items
                            .where((entry) => entry.key == key)
                            .firstOrNull;
                        if (item != null && latest == null) {
                          update(() => error = '这件物品已被移除');
                          return;
                        }
                        if ((list?.items.length ?? 0) >= 120 &&
                            latest == null) {
                          update(() => error = '每份清单最多 120 项');
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        final replacement = PackingItem(
                            key: key,
                            label: value,
                            category: category,
                            packed: latest?.packed ?? false,
                            assigneeId: carrier);
                        final message = await _write(
                            account: account,
                            shared: shared,
                            relationship: data.relationshipKey,
                            items: (list) => [
                                  for (final entry in list.items)
                                    if (entry.key == key)
                                      replacement
                                    else
                                      entry,
                                  if (latest == null) replacement
                                ]);
                        if (!dialog.mounted) return;
                        if (message == null) {
                          Navigator.pop(dialog);
                        } else {
                          update(() {
                            error = message;
                            saving = false;
                          });
                        }
                      },
                child: Text(saving ? '保存中' : '保存')),
          ],
        );
      }),
    );
  }

  Future<void> _removeItem(PackingItem item) async {
    final account = _account;
    final shared = _shared;
    final relationship = _data!.relationshipKey;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => GlassAlertDialog(
              title: const Text('移除这件物品？'),
              content: Text(item.label),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('移除')),
              ],
            ));
    if (confirmed != true || !mounted) return;
    _notice(await _write(
        account: account,
        shared: shared,
        relationship: relationship,
        items: (list) =>
            list.items.where((entry) => entry.key != item.key).toList()));
  }

  Future<void> _toggle(PackingItem item, bool? packed) async {
    if (packed == null) return;
    AppHaptics.instance.selectionClick();
    _notice(await _write(
        account: _account,
        shared: _shared,
        relationship: _data!.relationshipKey,
        items: (list) => [
              for (final entry in list.items)
                if (entry.key == item.key)
                  PackingItem(
                      key: entry.key,
                      label: entry.label,
                      category: entry.category,
                      packed: packed,
                      assigneeId: entry.assigneeId)
                else
                  entry
            ]));
  }

  Widget _hero(TripPreparation data) {
    final cover = data.coverUrl ??
        widget.journey?.stops
            .expand((stop) => [stop.place?.coverImage, ...?stop.place?.photos])
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .firstOrNull;
    final hasPhoto = cover != null && !data.archived;
    final start = data.start;
    final date = DateFormat('M月d日');
    final end = start?.add(Duration(days: data.days - 1));
    final dates = start == null
        ? null
        : data.days == 1
            ? date.format(start)
            : '${date.format(start)} – ${date.format(end!)}';
    final ink = hasPhoto ? Colors.white : context.lgInk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(children: [
        if (hasPhoto)
          Positioned.fill(child: _PreparationPhoto(cover, fit: BoxFit.cover)),
        Container(
          constraints: BoxConstraints(minHeight: hasPhoto ? 148 : 110),
          padding: const EdgeInsets.fromLTRB(14, 36, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [.25, 1],
              colors: hasPhoto
                  ? const [Color(0x05112536), Color(0xcd172730)]
                  : [
                      context.lgPaper,
                      context.lgIsDark ? context.lgBg : const Color(0xffd7edfa)
                    ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(data.title,
                  style: TextStyle(
                      fontSize: 27, fontWeight: FontWeight.w800, color: ink)),
              Text(
                  [
                    if (dates != null) dates,
                    '${data.days} 天',
                    if (data.archived) '已归档 · 只读',
                  ].join(' · '),
                  style: TextStyle(color: ink)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _progress(TripPreparation data) {
    final total = data.mine.items.length + (data.shared?.items.length ?? 0);
    final packed = data.mine.packed + (data.shared?.packed ?? 0);
    final ink =
        context.lgIsDark ? const Color(0xffb2c7df) : const Color(0xff526c91);
    return RebuildGlass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(children: [
        Text('已装好 $packed / $total',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Expanded(
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : packed / total,
            minHeight: 5,
            borderRadius: BorderRadius.circular(8),
            color: ink,
            backgroundColor: ink.withAlpha(44),
          ),
        ),
      ]),
    );
  }

  Widget _outfits(TripPreparation data, bool editable) {
    final saved = data.mine.outfits.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    final selected =
        saved.where((entry) => entry.day == _day).firstOrNull ?? saved.first;
    final days = saved.map((entry) => entry.day).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('已有搭配', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final day in days)
                Semantics(
                  selected: selected.day == day,
                  child: TextButton(
                    style: rebuildTextStyle(context).copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                      padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8)),
                    ),
                    onPressed: () {
                      AppHaptics.instance.selectionClick();
                      setState(() => _day = day);
                    },
                    child: Text(
                      day >= data.days
                          ? '第 ${day + 1} 天 · 已移出'
                          : '第 ${day + 1} 天',
                      style: TextStyle(
                        color: selected.day == day
                            ? context.lgInk
                            : context.lgTextSecondary,
                        fontWeight: selected.day == day
                            ? FontWeight.w700
                            : FontWeight.w400,
                        decoration: selected.day == day
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
      if (selected.imageUrl != null)
        AspectRatio(
            aspectRatio: 2,
            child: _PreparationPhoto(selected.imageUrl, fit: BoxFit.cover)),
      if (selected.imageUrl == null ||
          selected.pieces.any((piece) => !piece.available))
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final piece in selected.pieces)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 9),
                child: SizedBox(
                  width: 94,
                  child: Column(children: [
                    SizedBox(
                        height: 90, child: _PreparationPhoto(piece.imageUrl)),
                    Text(
                        piece.available ? piece.label : '${piece.label} · 已不可用',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.available
                        ? selected.label
                        : '${selected.label} · 已不可用',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('仅自己可见',
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextSecondary)),
                ],
              ),
            ),
          ),
          if (editable)
            PopupMenuButton<String>(
              tooltip: '搭配操作',
              onSelected: (_) async => _notice(await _write(
                  account: _account,
                  shared: false,
                  relationship: null,
                  outfits: (list) => list.outfits
                      .where((entry) => entry.day != selected.day)
                      .toList())),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'remove', child: Text('移除搭配关联')),
              ],
            ),
        ]),
      ),
    ]);
  }

  Widget _packing(PreparationList? list, bool editable) {
    final items = list?.items
            .where((item) => _category == null || item.category == _category)
            .toList() ??
        [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('行李清单', style: Theme.of(context).textTheme.titleLarge),
            RebuildChoiceChip(
              label: const Text('个人行李'),
              selected: !_shared,
              onSelected: (_) => setState(() {
                _shared = false;
                _category = null;
              }),
            ),
            RebuildChoiceChip(
              label: const Text('共同物品'),
              selected: _shared,
              onSelected: (_) => setState(() {
                _shared = true;
                _category = null;
              }),
            ),
          ]),
      if (list != null && list.items.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final category
                in <String?, String>{null: '全部', ...packingCategories}.entries)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: RebuildChoiceChip(
                  label: Text(category.value),
                  selected: _category == category.key,
                  onSelected: (_) => setState(() => _category = category.key),
                ),
              ),
          ]),
        ),
      RebuildGlass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(list == null
                  ? '绑定伴侣后可以共用清单、分工和勾选。'
                  : _category == null
                      ? '清单还是空的'
                      : '这个分类还没有物品'),
            ),
          for (final (index, item) in items.indexed) ...[
            if (index > 0)
              Divider(
                  height: 1,
                  indent: 48,
                  endIndent: 9,
                  color: context.lgSeparator),
            Row(children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.label),
                  subtitle: _shared ? Text(_person(item.assigneeId)) : null,
                  secondary: Text(packingCategories[item.category] ?? '',
                      style: TextStyle(
                          fontSize: 12, color: context.lgTextSecondary)),
                  value: item.packed,
                  onChanged: editable ? (value) => _toggle(item, value) : null,
                ),
              ),
              if (editable)
                PopupMenuButton<String>(
                  tooltip: '${item.label}的操作',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _editItem(item);
                    } else {
                      _removeItem(item);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'remove', child: Text('移除')),
                  ],
                ),
            ]),
          ],
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final list = _shared ? data?.shared : data?.mine;
    final editable = data != null &&
        !data.archived &&
        !_loading &&
        !_saving &&
        _error == null;
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        flexibleSpace: const RebuildGlassHeader(),
        title: const Text('旅行准备'),
        centerTitle: true,
        backgroundColor:
            context.lgIsDark ? context.lgBg : const Color(0xffeaf6fd),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: context.lgIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        actions: [
          IconButton(
              tooltip: '刷新清单',
              onPressed: _saving || _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ],
      ),
      body: RebuildPageBackground(
        child: _account == null
            ? const Center(child: Text('登录后查看旅行准备'))
            : data == null && _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      if (_loading || _saving) const LinearProgressIndicator(),
                      if (_error != null)
                        ListTile(
                          title: Text(_error!),
                          trailing: TextButton(
                              onPressed: _load, child: const Text('重试')),
                        ),
                      if (data != null) ...[
                        _hero(data),
                        const SizedBox(height: 8),
                        _progress(data),
                        const SizedBox(height: 14),
                        _packing(list, editable && list != null),
                        if (data.mine.outfits.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _outfits(data, editable),
                        ],
                      ]
                    ],
                  ),
      ),
      bottomNavigationBar: data == null || data.archived
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (widget.onViewJourney != null)
                    RebuildGlassButton(
                      label: '查看行程',
                      icon: Icons.route_outlined,
                      showLabel: true,
                      onPressed: _saving ? null : widget.onViewJourney,
                    ),
                  RebuildGlassButton(
                    label: '添加物品',
                    icon: Icons.add,
                    selected: editable && list != null,
                    showLabel: true,
                    onPressed:
                        editable && list != null ? () => _editItem() : null,
                  ),
                ],
              ),
            ),
    );
  }
}

class _PreparationPhoto extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  const _PreparationPhoto(this.path, {this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    final url = wnImgUrl(path, baseUrl: AppConstants.baseUrl);
    final empty = ColoredBox(
      color: context.lgPaper.withAlpha(170),
      child: Center(
          child: Icon(Icons.image_outlined, color: context.lgTextSecondary)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url.isEmpty
          ? empty
          : CachedNetworkImage(
              cacheManager: MediaCache.instance,
              imageUrl: url,
              fit: fit,
              width: double.infinity,
              memCacheWidth: fit == BoxFit.cover ? 900 : 260,
              placeholder: (_, __) => empty,
              errorWidget: (_, __, ___) => empty,
            ),
    );
  }
}
