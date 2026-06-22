import 'package:flutter/material.dart';

/// LoveGirl 情侣主题 — 温暖浪漫、干净高级
class LoveGirlTheme {
  // 圆角
  static const double radius = 14.0;
  static const double radiusLg = 20.0;

  // ===== 品牌色（温暖粉金系）=====
  static const Color primary = Color(0xFFFF6B8A);       // 暖粉 — 主色
  static const Color primaryLight = Color(0xFFFF8FA8);  // 浅粉
  static const Color primarySoft = Color(0xFFFFF0F3);   // 极浅粉背景
  static const Color secondary = Color(0xFFFFB347);     // 暖金 — 点缀
  static const Color accent = Color(0xFF4CAF50);        // 翠绿 — 成功/已完成
  static const Color red = Color(0xFFFF4757);
  static const Color orange = Color(0xFFFF9800);
  static const Color pink = Color(0xFFFF6B8A);
  static const Color pinkLight = Color(0xFFFF8FA8);

  // ===== 背景 =====
  static const Color bgLight = Color(0xFFFDF2F4);       // 微粉背景
  static const Color cardLight = Color(0xFFFFFFFF);      // 纯白卡片
  static const Color bgDark = Color(0xFF1A1A2E);
  static const Color cardDark = Color(0xFF252540);

  // ===== 文字 =====
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B6B7B);
  static const Color textMuted = Color(0xFF9E9EAD);

  // ===== 分隔线 =====
  static const Color separator = Color(0xFFF0E8EA);

  // ===== 旅行状态色 =====
  static const Color visited = Color(0xFF4CAF50);
  static const Color wish = Color(0xFFFFB347);
  static const Color planned = Color(0xFFE040FB);

  // ===== 间距 =====
  static const double spaceXxs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  // ===== 渐变预设 =====
  static const List<Color> gradientLove = [primary, primaryLight];
  static const List<Color> gradientSunset = [Color(0xFFFF6B8A), Color(0xFFFFB347)];
  static const List<Color> gradientOcean = [Color(0xFF7B8CFF), Color(0xFF6BD4FF)];
  static const List<Color> gradientForest = [Color(0xFF4CAF50), Color(0xFF81C784)];

  /// 卡片阴影 — 粉色柔光
  static List<BoxShadow> cardShadow() => [
    BoxShadow(
      color: primary.withAlpha(18),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withAlpha(6),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  /// 强卡片阴影
  static List<BoxShadow> cardShadowElevated() => [
    BoxShadow(
      color: primary.withAlpha(28),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withAlpha(10),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // ===== 亮色主题 =====
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: cardLight,
        error: red,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        color: cardLight,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: primary, width: 1.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 0,
      ),
    );
  }

  // ===== 暗色主题 =====
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        color: cardDark,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardDark,
        selectedItemColor: primaryLight,
        unselectedItemColor: Colors.white38,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primaryLight, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        ),
      ),
    );
  }

  /// 毛玻璃卡片装饰
  static BoxDecoration glassDecoration({
    required Color tint,
    double opacity = 0.85,
    double radius = 0,
  }) {
    final r = radius > 0 ? radius : LoveGirlTheme.radius;
    return BoxDecoration(
      color: tint.withAlpha((opacity * 255).round()),
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: Colors.white.withAlpha(40)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(8),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
