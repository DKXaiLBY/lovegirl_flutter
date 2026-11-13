import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/models/wardrobe.dart';
import 'package:lovegirl_flutter/providers/map_prefs_provider.dart';
import 'package:lovegirl_flutter/providers/wardrobe_provider.dart';
import 'package:lovegirl_flutter/screens/wardrobe/wardrobe_module_screen.dart';
import 'package:lovegirl_flutter/utils/lovegirl_theme.dart';
import 'package:provider/provider.dart';

class _Wardrobe extends WardrobeProvider {
  int retries = 0;

  @override
  Future<void> loadAll() async {
    retries++;
    error = null;
    outfitsError = null;
    items = const [
      WardrobeItem(
          id: 1, imageUrl: '', brand: '蓝色外套', category: '外套', status: '在柜'),
      WardrobeItem(
          id: 2, imageUrl: '', brand: '白色鞋', category: '鞋子', status: '在柜'),
    ];
    notifyListeners();
  }
}

void main() {
  testWidgets(
      'wardrobe and outfits show independent errors and searchable items',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final wardrobe = _Wardrobe();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<WardrobeProvider>.value(value: wardrobe),
        ChangeNotifierProvider(create: (_) => MapPrefsProvider()),
      ],
      child: MaterialApp(
        theme: LoveGirlTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const WardrobeModuleScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    await tester.enterText(search, '蓝色');
    await tester.pumpAndSettle();
    expect(wardrobe.filteredItems.map((item) => item.id), [1]);
    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    expect(wardrobe.filteredItems.map((item) => item.id), [1, 2]);

    wardrobe.outfitsError = '穿搭加载失败，可以重试';
    await tester.tap(find.text('穿搭'));
    await tester.pumpAndSettle();
    expect(find.text('穿搭加载失败，可以重试'), findsOneWidget);
    expect(find.text('还没有穿搭记录'), findsNothing);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(wardrobe.retries, 2);
    expect(find.text('还没有穿搭记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
