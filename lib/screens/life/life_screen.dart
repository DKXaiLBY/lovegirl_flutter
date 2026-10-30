import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';
import '../../widgets/rebuild_controls.dart';
import '../health/health_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../wardrobe/wardrobe_module_screen.dart';
import 'widgets/finance_list.dart';
import 'widgets/schedule_list.dart';
import 'widgets/todo_list.dart';

class LifeScreen extends StatefulWidget {
  final ApiService? api;
  const LifeScreen({super.key, this.api});

  @override
  State<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends State<LifeScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  int? _account;
  int _request = 0;
  bool _loading = true;
  List<Map<String, dynamic>>? _todos;
  List<Map<String, dynamic>>? _dishes;
  List<Map<String, dynamic>>? _clothes;
  num? _expense;
  final Set<int> _savingTodos = {};
  List<String> _failed = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = context.watch<AuthProvider>().userId;
    if (_request == 0 || account != _account) {
      _account = account;
      _todos = _dishes = _clothes = null;
      _expense = null;
      _loading = true;
      _load();
    }
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList()
      : [];

  Future<void> _load() async {
    final request = ++_request;
    final failures = <String>[];
    Future<dynamic> read(Future<dynamic> future, String name) async {
      try {
        final response = await future;
        return response.data['data'];
      } catch (_) {
        failures.add(name);
        return null;
      }
    }

    final values = await Future.wait([
      read(_api.getTodos(), '待办'),
      read(_api.getFinanceStats(DateFormat('yyyy-MM').format(DateTime.now())),
          '账本'),
      read(_api.getKitchenMenu(), '厨房'),
      read(_api.getWardrobeItems(), '衣橱'),
    ]);
    if (!mounted || request != _request) return;
    setState(() {
      _loading = false;
      _failed = failures;
      _todos = values[0] == null ? null : _rows(values[0]);
      final finance = values[1];
      _expense =
          finance is Map ? num.tryParse('${finance['expense'] ?? 0}') : null;
      final kitchen = values[2];
      _dishes = kitchen is Map
          ? [..._rows(kitchen['mine']), ..._rows(kitchen['partner_dishes'])]
          : null;
      _clothes = values[3] == null ? null : _rows(values[3]);
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  Widget _tool(String title, Widget child) =>
      LifeToolScreen(title: title, child: child);

  Future<void> _toggle(Map<String, dynamic> todo) async {
    final id = int.tryParse('${todo['id']}');
    if (id == null || _savingTodos.contains(id)) return;
    final account = _account;
    setState(() => _savingTodos.add(id));
    try {
      await _api.toggleTodo(id);
      if (mounted && account == _account) await _load();
    } catch (_) {
      if (mounted && account == _account) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('没有修改成功，请再试一次')));
      }
    } finally {
      if (mounted) setState(() => _savingTodos.remove(id));
    }
  }

  void _quickAdd() {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final action in [
                (
                  Icons.add_task_outlined,
                  '添加待办',
                  _tool('待办', const TodoListWidget(createOnOpen: true))
                ),
                (
                  Icons.receipt_long_outlined,
                  '记一笔收支',
                  _tool('记账', const FinanceListWidget(createOnOpen: true))
                ),
              ])
                ListTile(
                    leading: Icon(action.$1),
                    title: Text(action.$2),
                    onTap: () {
                      Navigator.pop(sheet);
                      _open(action.$3);
                    }),
            ])));
  }

  String? _photo(List<Map<String, dynamic>>? rows, String field,
      [int index = 0]) {
    final photos = rows
            ?.map((row) => row[field]?.toString() ?? '')
            .where((path) => path.isNotEmpty)
            .toList() ??
        [];
    return index < photos.length ? photos[index] : null;
  }

  Widget _image(String? path, String fallback, {double? height}) {
    final placeholder =
        Image.asset(fallback, fit: BoxFit.cover, height: height);
    if (path == null) return placeholder;
    final url = path.startsWith('http') ? path : '${AppConstants.baseUrl}$path';
    return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        height: height,
        memCacheWidth: 900,
        errorWidget: (_, __, ___) => ColoredBox(
            color: context.lgPrimarySoft,
            child: Center(
                child: Icon(Icons.image_not_supported_outlined,
                    color: context.lgTextSecondary))));
  }

  Widget _surface(Widget child) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color:
              context.lgIsDark ? context.lgCard : Colors.white.withAlpha(145),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Colors.white.withAlpha(context.lgIsDark ? 14 : 190))),
      child: child);

  Widget _summary() {
    final active = _todos
        ?.where((row) => row['completed'] != true && row['completed'] != 1)
        .toList();
    final todo = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
          onTap: () => _open(_tool('待办', const TodoListWidget())),
          child: const SizedBox(
              height: 40,
              child: Row(children: [
                Icon(Icons.checklist_outlined, size: 21),
                SizedBox(width: 8),
                Text('待办',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Spacer(),
                Icon(Icons.chevron_right, size: 18)
              ]))),
      Text(
          _loading
              ? '正在加载…'
              : active == null
                  ? '暂时无法读取'
                  : active.isEmpty
                      ? '今天从容一点'
                      : '还有${active.length}件小事',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      if (active?.isNotEmpty == true)
        for (final row in active!.take(2))
          InkWell(
              onTap: _savingTodos.contains(int.tryParse('${row['id']}'))
                  ? null
                  : () => _toggle(row),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(children: [
                    const Icon(Icons.check_box_outline_blank, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('${row['title'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12))),
                  ])))
      else
        TextButton(
            onPressed: () =>
                _open(_tool('待办', const TodoListWidget(createOnOpen: true))),
            child: const Text('记一件事')),
    ]));
    final finance = _surface(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
          onTap: () => _open(_tool('记账', const FinanceListWidget())),
          child: const SizedBox(
              height: 40,
              child: Row(children: [
                Icon(Icons.account_balance_wallet_outlined, size: 21),
                SizedBox(width: 8),
                Text('本月账本',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))
              ]))),
      FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
              _loading
                  ? '—'
                  : _expense == null
                      ? '暂未读取'
                      : '¥${NumberFormat('#,##0.##').format(_expense)}',
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
      Text('本月支出',
          style: TextStyle(fontSize: 12, color: context.lgTextSecondary)),
      const SizedBox(height: 12),
      Align(
          alignment: Alignment.centerRight,
          child: RebuildGlassButton(
              label: '记一笔',
              icon: Icons.add,
              showLabel: true,
              onPressed: () => _open(
                  _tool('记账', const FinanceListWidget(createOnOpen: true))))),
    ]));
    return LayoutBuilder(
        builder: (context, bounds) => bounds.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.35
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [todo, const SizedBox(height: 10), finance])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: todo),
                const SizedBox(width: 10),
                Expanded(child: finance)
              ]));
  }

  Widget _kitchen() => ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
          aspectRatio: 1.28,
          child: Stack(fit: StackFit.expand, children: [
            _image(_photo(_dishes, 'photo_url'),
                'assets/images/clear_app/kitchen_cover.png'),
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x65000000), Colors.transparent]))),
            Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('情侣厨房',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          _dishes?.isEmpty == true
                              ? '添一道拿手菜，等下次开饭'
                              : '今晚，想吃什么？',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    ])),
            Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: RebuildGlass(
                    radius: 22,
                    child: Row(children: [
                      Expanded(
                          child: TextButton.icon(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(48, 50)),
                              onPressed: () => _open(const KitchenScreen()),
                              icon: const Icon(Icons.restaurant_outlined),
                              label: const Text('去点菜'))),
                      Container(
                          width: 1,
                          height: 22,
                          color: Colors.white.withAlpha(150)),
                      Expanded(
                          child: TextButton.icon(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(48, 50)),
                              onPressed: () =>
                                  _open(const KitchenScreen(initialTab: 1)),
                              icon: const Icon(Icons.menu_book_outlined),
                              label: const Text('看菜单'))),
                    ]))),
          ])));

  Widget _wardrobe() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('我的衣橱',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          TextButton(
              onPressed: () => _open(_tool('衣橱', const WardrobeModuleScreen())),
              child: const Text('查看全部 ›'))
        ]),
        InkWell(
            onTap: () => _open(_tool('衣橱', const WardrobeModuleScreen())),
            borderRadius: BorderRadius.circular(16),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                    aspectRatio: 3.1,
                    child: _photo(_clothes, 'image_url') == null
                        ? _image(
                            null, 'assets/images/clear_app/wardrobe_cover.png')
                        : Row(children: [
                            for (var i = 0;
                                i <
                                    (_clothes
                                            ?.where((row) =>
                                                '${row['image_url'] ?? ''}'
                                                    .isNotEmpty)
                                            .take(2)
                                            .length ??
                                        0);
                                i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                  child: SizedBox.expand(
                                      child: _image(
                                          _photo(_clothes, 'image_url', i),
                                          'assets/images/clear_app/wardrobe_cover.png'))),
                            ]
                          ])))),
        const SizedBox(height: 5),
        Text(_clothes?.isEmpty == true ? '还没有衣物，收好第一件喜欢的衣服' : '明天穿什么',
            style: TextStyle(fontSize: 12, color: context.lgTextSecondary)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      body: DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.lgIsDark
                      ? [context.lgBg, context.lgBg]
                      : const [
                          Color(0xfff3fbff),
                          Colors.white,
                          Color(0xffedf7ff)
                        ])),
          child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('生活',
                                  style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800))),
                          RebuildGlassButton(
                              label: '添加生活记录',
                              icon: Icons.add,
                              onPressed: _quickAdd)
                        ]),
                        const SizedBox(height: 5),
                        Text('把日子过成喜欢的样子',
                            style: TextStyle(
                                fontSize: 13, color: context.lgTextSecondary)),
                        const SizedBox(height: 16),
                        if (_failed.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(children: [
                                Expanded(
                                    child: Text('${_failed.join('、')}暂未加载',
                                        style: TextStyle(
                                            color: context.lgTextSecondary,
                                            fontSize: 12))),
                                TextButton(
                                    onPressed: _load, child: const Text('重试'))
                              ])),
                        _summary(),
                        const SizedBox(height: 12),
                        _kitchen(),
                        const SizedBox(height: 10),
                        _wardrobe(),
                        const SizedBox(height: 12),
                        _surface(ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.calendar_month_outlined),
                            title: const Text('课程表',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: const Text('查看本周安排'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(
                                _tool('课程', const ScheduleListWidget())))),
                        if (context.watch<AuthProvider>().isOriginalGirl) ...[
                          const SizedBox(height: 10),
                          _surface(ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.lock_outline),
                              title: const Text('经期记录'),
                              subtitle: const Text('仅自己可见'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _open(const HealthScreen()))),
                        ],
                      ])))),
    );
  }
}

class LifeToolScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const LifeToolScreen({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.lgBg,
      appBar: AppBar(
        title: Text(title),
        systemOverlayStyle: context.lgIsDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}
