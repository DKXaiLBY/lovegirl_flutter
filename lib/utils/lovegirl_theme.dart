import 'package:flutter/material.dart';

/// LoveGirl confirmed visual direction:
/// v3.34 白色简洁（倒数日风）：纯白底、极浅分隔、大数字黑字、彩色插画点缀；
/// 票根隐喻只保留在票根类内容页（旅行票根/时光轴）。情感橘只给"和 TA 有关"的内容。
class LoveGirlTheme {
  static const double radius = 14.0;
  static const double radiusLg = 18.0;
  static const double radiusXl = 26.0;

  // v3.24 主行动黑白化，品牌橘退位
  static const Color primary = Color(0xFF1A1A1A);
  static const Color primaryLight = Color(0xFF4A4A4A);
  static const Color primarySoft = Color(0xFFF4F4F5);
  static const Color secondary = Color(0xFF7A9E7E);
  static const Color secondarySoft = Color(0xFFEFF2EF);
  static const Color accent = Color(0xFFE7B78A);
  static const Color red = Color(0xFFE95B4E);
  static const Color orange = Color(0xFFE7A25D);
  static const Color pink = primary;
  static const Color pinkLight = primaryLight;

  // v3.27 情感色：陶土橘只给"和 TA 有关"的元素（恋爱天数/爱心/对方动态）
  static const Color brandEmotion = Color(0xFFB85C38);

  // v3.34 白色简洁（浅色）与中性深色（深色同步去暖）
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperWarm = Color(0xFFF7F7F8);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color bgDark = Color(0xFF111113);
  static const Color cardDark = Color(0xFF1C1C1E);

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF999999);
  static const Color separator = Color(0xFFECECEC);

  // v3.34 深色模式 token（中性深灰体系）
  static const Color textPrimaryDark = Color(0xFFECECEE);
  static const Color textSecondaryDark = Color(0xFF9E9EA3);
  static const Color textMutedDark = Color(0xFF7C7C82);
  static const Color separatorDark = Color(0xFF2C2C2E);
  static const Color primarySoftDark = Color(0xFF2A2A2D);
  static const Color secondarySoftDark = Color(0xFF232624);

  static const Color visited = Color(0xFF4CAF50); // 与 travel 模块状态绿统一
  static const Color wish = accent;
  static const Color planned = Color(0xFF9E9AD1);

  static const double spaceXxs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const List<Color> gradientLove = [primary, primaryLight];
  static const List<Color> gradientSunset = [primary, accent];
  static const List<Color> gradientOcean = [
    Color(0xFF7B8CFF),
    Color(0xFF6BD4FF)
  ];
  static const List<Color> gradientForest = [secondary, Color(0xFFB8CBA7)];

  static List<BoxShadow> cardShadow() => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  static List<BoxShadow> cardShadowElevated() => [
        const BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: cardLight,
        error: red,
      ),
      fontFamilyFallback: const [
        'MiSans',
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
      ],
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: paper,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.7,
        space: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      brightness: Brightness.dark,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: secondary,
        surface: cardDark,
        error: red,
      ),
      fontFamilyFallback: const [
        'MiSans',
        'PingFang SC',
        'Microsoft YaHei',
        'Noto Sans CJK SC',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimaryDark,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: primaryLight,
        unselectedItemColor: Colors.white38,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textMutedDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: separatorDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: separatorDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: textPrimaryDark, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: textPrimaryDark,
          foregroundColor: bgDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: separatorDark,
        thickness: 0.7,
        space: 0,
      ),
    );
  }

  static BoxDecoration glassDecoration({
    required Color tint,
    double opacity = 0.9,
    double radius = 0,
  }) {
    final resolvedRadius = radius > 0 ? radius : LoveGirlTheme.radius;
    return BoxDecoration(
      color: tint.withAlpha((opacity * 255).round()),
      borderRadius: BorderRadius.circular(resolvedRadius),
      border: Border.all(color: Colors.white.withAlpha(50)),
      boxShadow: cardShadow(),
    );
  }
}

/// v3.26 深色模式接线：语义色按当前亮度解析。
/// 页面代码用 `context.lgXxx` 取代硬编码浅色 token，深浅模式自动切换。
extension LoveGirlSemanticColors on BuildContext {
  bool get lgIsDark => Theme.of(this).brightness == Brightness.dark;

  Color get lgBg =>
      lgIsDark ? LoveGirlTheme.bgDark : LoveGirlTheme.bgLight;

  Color get lgCard =>
      lgIsDark ? LoveGirlTheme.cardDark : LoveGirlTheme.cardLight;

  Color get lgPaper =>
      lgIsDark ? LoveGirlTheme.cardDark : LoveGirlTheme.paper;

  Color get lgPaperWarm =>
      lgIsDark ? LoveGirlTheme.cardDark : LoveGirlTheme.paperWarm;

  Color get lgSeparator =>
      lgIsDark ? LoveGirlTheme.separatorDark : LoveGirlTheme.separator;

  Color get lgTextPrimary => lgIsDark
      ? LoveGirlTheme.textPrimaryDark
      : LoveGirlTheme.textPrimary;

  Color get lgTextSecondary => lgIsDark
      ? LoveGirlTheme.textSecondaryDark
      : LoveGirlTheme.textSecondary;

  Color get lgTextMuted =>
      lgIsDark ? LoveGirlTheme.textMutedDark : LoveGirlTheme.textMuted;

  Color get lgPrimarySoft => lgIsDark
      ? LoveGirlTheme.primarySoftDark
      : LoveGirlTheme.primarySoft;

  Color get lgSecondarySoft => lgIsDark
      ? LoveGirlTheme.secondarySoftDark
      : LoveGirlTheme.secondarySoft;

  /// “墨色”：浅色=品牌黑 primary，深色=米白 textPrimaryDark。
  /// 用于文字/图标/描边等原本写死 primary 的位置（黑底座容器勿用）。
  Color get lgInk =>
      lgIsDark ? LoveGirlTheme.textPrimaryDark : LoveGirlTheme.primary;

  /// “情感色”：浅色=陶土橘（恋爱天数/爱心/对方相关），深色=米白（dark 红线：不引入暖色文字）
  Color get lgEmotion =>
      lgIsDark ? LoveGirlTheme.textPrimaryDark : LoveGirlTheme.brandEmotion;
}
