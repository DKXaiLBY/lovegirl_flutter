import 'package:flutter/material.dart';

/// LoveGirl confirmed visual direction:
/// v4.0 冷灰工具风（参考图 8 张定稿）：浅灰渐变底（LovePage 135° surfaceGradient）+
/// 纯白卡 1px 细线描边（阴影≈0）、中性近黑字阶、主行动黑底白字、蜜桃降格（仅徽章浅底/
/// 关键数字/回忆卡）。深色=中性冷深灰。票根隐喻只保留在票根类内容页（旅行票根/时光轴）。
class LoveGirlTheme {
  // v4.0 参考图②：行/小卡 16、卡片 20、弹层 28
  static const double radius = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;

  // v3.24 主行动黑白化，品牌橘退位
  static const Color primary = Color(0xFF1A1A1A);
  static const Color primaryLight = Color(0xFF4A4A4A);
  // v4.0 冷灰浅底（v3.41 曾为暖米 #F0EAE0；DESIGN_SYSTEM 曾误写 #F4F4F5）
  static const Color primarySoft = Color(0xFFF1F3F5);
  static const Color secondary = Color(0xFF7A9E7E);
  static const Color secondarySoft = Color(0xFFEFF2EF);

  // v3.41 accent 蜜桃珊瑚；v4.0 角色降格：只做 softOrangeBg 徽章前景/关键数字/
  // 回忆卡图标级小面积，不再上大面积底色；文字场景一律 peachText（对白 4.5:1）；
  // 蜜桃与功能红同族，删除按钮同屏需真机验证
  static const Color accent = Color(0xFFF2704F);
  static const Color peach = Color(0xFFF2704F);
  static const Color peachText = Color(0xFFC9502E);
  // v4.0 深色态蜜桃文字档（卡 #232529 上 6.62:1；记账收入等深色关键数字用）
  static const Color peachTextDark = Color(0xFFF2916E);
  static const Color red = Color(0xFFE95B4E);
  static const Color orange = Color(0xFF8E8E93);
  static const Color pink = primary;
  static const Color pinkLight = primaryLight;

  // v3.37 情感色黑化：恋爱天数/爱心与正文同黑（回滚点=独立 commit）
  static const Color brandEmotion = Color(0xFF1A1A1A);

  // v4.0 冷灰（浅色）：LovePage 135° 渐变底，bgLight=Scaffold 纯色回退
  static const Color bgLight = Color(0xFFF2F4F6);
  static const Color surfaceGradientStart = Color(0xFFF7F8FA);
  static const Color surfaceGradientEnd = Color(0xFFECEEF2);
  static const List<Color> surfaceGradient = [
    surfaceGradientStart,
    surfaceGradientEnd,
  ];
  static const Color paper = Color(0xFFFFFFFF);
  // v4.0 暖米退役转冷浅灰（名字保留不改 22 处调用点，后续批次渐改名 surfaceSubtle）
  static const Color paperWarm = Color(0xFFF6F7F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color bgDark = Color(0xFF17181B);
  static const Color cardDark = Color(0xFF232529);

  // v4.0 中性近黑字阶（浅色）+ 分隔线比卡描边浅一档
  static const Color textPrimary = Color(0xFF1F2126);
  static const Color textSecondary = Color(0xFF5C6066);
  static const Color textMuted = Color(0xFF686D75);
  static const Color separator = Color(0xFFECEEF1);
  // v4.0 卡片 1px 细线描边（比分隔线重一档，参考图②）
  static const Color cardBorder = Color(0xFFE5E7EC);

  // v4.0 深色模式 token（中性冷深灰体系）
  static const Color textPrimaryDark = Color(0xFFECEDEF);
  static const Color textSecondaryDark = Color(0xFF9BA0A8);
  static const Color textMutedDark = Color(0xFF9095A0);
  static const Color separatorDark = Color(0xFF2F3237);
  static const Color cardBorderDark = Color(0xFF33363C);
  static const Color primarySoftDark = Color(0xFF2C2F34);
  static const Color secondarySoftDark = Color(0xFF262B28);

  // v4.0 中性计数徽章（浅色常量；深色走 lgBadgeBg/lgBadgeText getter）
  static const Color badgeBg = Color(0xFFEEF0F3);
  static const Color badgeText = Color(0xFF3A3D45);

  // v4.0 语义浅底徽章六族（浅色常量；深色 bg 统一 primarySoftDark，
  // fg 见 LoveGirlSemanticColors 语义 getter）
  static const Color softGreenBg = Color(0xFFE1F1E7);
  static const Color softGreenText = Color(0xFF356B47);
  static const Color softOrangeBg = Color(0xFFFBE9DE);
  static const Color softOrangeText = Color(0xFFA8431F);
  static const Color softBlueBg = Color(0xFFE3EEF9);
  static const Color softBlueText = Color(0xFF3A689F);
  static const Color softPurpleBg = Color(0xFFECEAF6);
  static const Color softPurpleText = Color(0xFF63609E);
  static const Color softYellowBg = Color(0xFFFBF2DC);
  static const Color softYellowText = Color(0xFF7E6424);

  // v3.41 蜜桃日出渐变——v4.0 已退役：白名单三处 hero 全改 surfaceGradient，
  // 常量保留仅供 git 历史回滚参照，勿在新代码使用（灯下勿加 @Deprecated：
  // 现存 2 处旧调用未迁移，注解会炸 analyze）
  static const List<Color> gradientSunrise = [
    Color(0xFFFFE3C8),
    Color(0xFFFFD9E3),
  ];

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
  static const List<Color> gradientSunset = [primary, Color(0xFF6E6E73)];
  static const List<Color> gradientOcean = [
    Color(0xFF7B8CFF),
    Color(0xFF6BD4FF)
  ];
  static const List<Color> gradientForest = [secondary, Color(0xFFB8CBA7)];

  // v4.2 软实体卡阴影（参考图灵魂：大 blur 柔影+远环境影，卡片"浮起来"而非线框）
  static List<BoxShadow> cardShadow() => [
        const BoxShadow(
          color: Color(0x141A1D26),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
        const BoxShadow(
          color: Color(0x081A1D26),
          blurRadius: 40,
          offset: Offset(0, 16),
        ),
      ];

  static List<BoxShadow> cardShadowElevated() => [
        const BoxShadow(
          color: Color(0x1E1A1D26),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
        const BoxShadow(
          color: Color(0x0D1A1D26),
          blurRadius: 56,
          offset: Offset(0, 22),
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

  /// v4.0 弹层玻璃化统一口径基准（radiusXl 28 / 白 72% / blur 24）：
  /// 白 72% = withAlpha(184)，配合调用点 BackdropFilter blur 24 使用。
  /// 注：全库现无调用点，此方法仅作口径基准保留；弹层改造随后续批次落地。
  static BoxDecoration glassDecoration({
    required Color tint,
    double opacity = 0.72,
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

  /// v4.0 卡片 1px 细线描边（LovePaper/LoveIconButton/票根描边默认）
  Color get lgCardBorder =>
      lgIsDark ? LoveGirlTheme.cardBorderDark : LoveGirlTheme.cardBorder;

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

  /// v4.0 蜜桃文字档：浅色=peachText，深色=peachTextDark（卡上 6.62:1）。
  /// 记账收入等关键数字深色态必须走此 getter，勿直用 peachText。
  Color get lgPeachText =>
      lgIsDark ? LoveGirlTheme.peachTextDark : LoveGirlTheme.peachText;

  // ---- v4.0 徽章六族（必须走 getter：深色 bg 统一 primarySoftDark，
  // 禁止直引浅色 softXxxBg 常量导致深色徽章回亮）----

  /// 中性计数徽章（LoveBadge 默认/LovePill 默认底）
  Color get lgBadgeBg => lgIsDark
      ? LoveGirlTheme.primarySoftDark
      : LoveGirlTheme.badgeBg;

  Color get lgBadgeText => lgIsDark
      ? const Color(0xFFC7CBD1)
      : LoveGirlTheme.badgeText;

  /// 完成/健康浅底徽章
  Color get lgSoftGreenBg => lgIsDark
      ? LoveGirlTheme.primarySoftDark
      : LoveGirlTheme.softGreenBg;

  Color get lgSoftGreenText =>
      lgIsDark ? const Color(0xFF8CC9A3) : LoveGirlTheme.softGreenText;

  /// 蜜桃族浅底徽章（蜜桃暖意的合法出口之一）
  Color get lgSoftOrangeBg => lgIsDark
      ? LoveGirlTheme.primarySoftDark
      : LoveGirlTheme.softOrangeBg;

  Color get lgSoftOrangeText =>
      lgIsDark ? const Color(0xFFF2916E) : LoveGirlTheme.softOrangeText;

  /// 信息蓝浅底徽章
  Color get lgSoftBlueBg => lgIsDark
      ? LoveGirlTheme.primarySoftDark
      : LoveGirlTheme.softBlueBg;

  Color get lgSoftBlueText =>
      lgIsDark ? const Color(0xFF8FB8E8) : LoveGirlTheme.softBlueText;

  /// 计划紫浅底徽章
  Color get lgSoftPurpleBg => lgIsDark
      ? LoveGirlTheme.primarySoftDark
      : LoveGirlTheme.softPurpleBg;

  Color get lgSoftPurpleText =>
      lgIsDark ? const Color(0xFFB0ACDD) : LoveGirlTheme.softPurpleText;

  /// 提醒黄浅底徽章
  Color get lgSoftYellowBg => lgIsDark
      ? LoveGirlTheme.primarySoftDark
      : LoveGirlTheme.softYellowBg;

  Color get lgSoftYellowText =>
      lgIsDark ? const Color(0xFFD9C07E) : LoveGirlTheme.softYellowText;
}
