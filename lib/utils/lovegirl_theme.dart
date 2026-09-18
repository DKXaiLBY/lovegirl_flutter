import 'package:flutter/material.dart';

/// LoveGirl confirmed visual direction:
/// warm ivory paper, ticket cards, coral accents and soft sage status color.
class LoveGirlTheme {
  static const double radius = 14.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 26.0;

  static const Color primary = Color(0xFFB85C38);
  static const Color primaryLight = Color(0xFFD4876B);
  static const Color primarySoft = Color(0xFFFBE3E3);
  static const Color secondary = Color(0xFF7A9E7E);
  static const Color secondarySoft = Color(0xFFF0F5EC);
  static const Color accent = Color(0xFFE7B78A);
  static const Color red = Color(0xFFE95B4E);
  static const Color orange = Color(0xFFE7A25D);
  static const Color pink = primary;
  static const Color pinkLight = primaryLight;

  static const Color bgLight = Color(0xFFFFF9F5);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperWarm = Color(0xFFFFF5EC);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color bgDark = Color(0xFF1D1917);
  static const Color cardDark = Color(0xFF2A2421);

  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF999999);
  static const Color separator = Color(0xFFEAE4DC);

  static const Color visited = secondary;
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
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
      brightness: Brightness.dark,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: secondary,
        surface: cardDark,
        error: red,
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
