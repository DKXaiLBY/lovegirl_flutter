import 'package:flutter_test/flutter_test.dart';
import 'package:lovegirl_flutter/main.dart';

void main() {
  testWidgets('App loads without error', (WidgetTester tester) async {
    await tester.pumpWidget(const LoveGirlApp());
    // 验证 App 能正常渲染
    expect(find.byType(LoveGirlApp), findsOneWidget);
  });
}
