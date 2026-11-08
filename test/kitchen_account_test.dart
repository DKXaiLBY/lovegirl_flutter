import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/providers/kitchen_provider.dart';
import 'package:lovegirl_flutter/services/api_service.dart';

class _Api implements ApiService {
  int actor = 71;
  final menus = <Completer<Response>>[];
  final orders = <Completer<Response>>[];
  final writes = <Completer<Response>>[];
  Completer<Response>? dishWrite;
  int menuReads = 0;
  int orderReads = 0;
  Response response(dynamic value) => Response(
      requestOptions: RequestOptions(), data: {'code': 200, 'data': value});
  Map<String, dynamic> menu(String name) => {
        'bound': true,
        'partner': {'id': actor == 71 ? 72 : 71, 'nickname': name},
        'mine': [
          {'id': 1, 'user_id': actor, 'name': name}
        ],
        'partner_dishes': [],
      };
  @override
  Future<Response> getKitchenMenu() {
    menuReads++;
    return menus.isEmpty
        ? Future.value(response(menu('current')))
        : menus.removeAt(0).future;
  }

  @override
  Future<Response> getKitchenOrders() {
    orderReads++;
    return orders.isEmpty
        ? Future.value(response({'incoming': [], 'outgoing': []}))
        : orders.removeAt(0).future;
  }

  @override
  Future<Response> getKitchenSummary() async => response({'bound': true});
  @override
  Future<Response> createKitchenOrder(Map data) => writes.removeAt(0).future;
  @override
  Future<Response> createKitchenDish(Map data) => dishWrite!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(response({}));
}

void main() {
  test(
      'switching account clears kitchen data, selection and badges before reload',
      () async {
    final api = _Api();
    final kitchen = KitchenProvider(api: api)..setAccount(71);
    await kitchen.loadMenu();
    kitchen.cart[1] = 2;
    kitchen.incomingNew = 3;
    kitchen.setAccount(72);
    expect(kitchen.mine, isEmpty);
    expect(kitchen.partnerDishes, isEmpty);
    expect(kitchen.partnerName, isNull);
    expect(kitchen.bound, isFalse);
    expect(kitchen.cart, isEmpty);
    expect(kitchen.incomingNew, 0);
    kitchen.dispose();
  });

  test(
      'late menu and orders from an old account cannot populate the new kitchen',
      () async {
    final api = _Api();
    final menu = Completer<Response>();
    final orders = Completer<Response>();
    api.menus.add(menu);
    api.orders.add(orders);
    final kitchen = KitchenProvider(api: api)..setAccount(71);
    final pending = kitchen.refreshAll();
    kitchen.setAccount(72);
    menu.complete(api.response(api.menu('old-private-menu')));
    orders.complete(api.response({
      'incoming': [
        {'id': 8, 'status': 'placed'}
      ],
      'outgoing': []
    }));
    await pending;
    expect(kitchen.mine, isEmpty);
    expect(kitchen.incoming, isEmpty);
    expect(kitchen.partnerName, isNull);
    expect(kitchen.bound, isFalse);
    kitchen.dispose();
  });

  test('a slow refresh cannot overwrite a newer menu for the same account',
      () async {
    final api = _Api();
    final first = Completer<Response>();
    final second = Completer<Response>();
    api.menus.addAll([first, second]);
    final kitchen = KitchenProvider(api: api)..setAccount(71);
    final old = kitchen.loadMenu();
    final current = kitchen.loadMenu();
    second.complete(api.response(api.menu('current-menu')));
    await current;
    first.complete(api.response(api.menu('stale-menu')));
    await old;
    expect(kitchen.mine.single.name, 'current-menu');
    kitchen.dispose();
  });

  test(
      'old checkout cannot clear a new account cart or release its pending checkout',
      () async {
    final api = _Api();
    final first = Completer<Response>();
    final second = Completer<Response>();
    api.writes.addAll([first, second]);
    final kitchen = KitchenProvider(api: api)
      ..setAccount(71)
      ..bound = true
      ..partnerId = 72
      ..menuLoaded = true
      ..cart[1] = 1;
    final old = kitchen.placeOrder('old note');
    kitchen.setAccount(72);
    api.actor = 72;
    kitchen.bound = true;
    kitchen.partnerId = 71;
    kitchen.menuLoaded = true;
    kitchen.cart[2] = 1;
    final current = kitchen.placeOrder('new note');
    first.complete(api.response({'id': 8}));
    expect(await old, '账号已切换，请在当前账号重新操作');
    expect(kitchen.cart, {2: 1});
    expect(kitchen.placingOrder, isTrue);
    expect(api.menuReads, 0);
    second.complete(api.response({'id': 9}));
    expect(await current, isNull);
    expect(kitchen.placingOrder, isFalse);
    kitchen.dispose();
  });

  test('old dish save cannot trigger a refresh in the newly signed-in account',
      () async {
    final api = _Api()..dishWrite = Completer<Response>();
    final kitchen = KitchenProvider(api: api)..setAccount(71);
    final save = kitchen.createDish({'name': 'private dish'});
    kitchen.setAccount(72);
    api.dishWrite!.complete(api.response({'id': 8}));
    expect(await save, '账号已切换，请在当前账号重新操作');
    expect(api.menuReads, 0);
    kitchen.dispose();
  });

  test('disposed kitchen ignores a pending read without notifying listeners',
      () async {
    final api = _Api();
    final menu = Completer<Response>();
    api.menus.add(menu);
    final kitchen = KitchenProvider(api: api)..setAccount(71);
    final read = kitchen.loadMenu();
    kitchen.dispose();
    menu.complete(api.response(api.menu('late')));
    await read;
    expect(kitchen.mine, isEmpty);
  });
}
