import 'package:flutter/material.dart';

import '../../utils/lovegirl_theme.dart';

const studyTwoPaneWidth = 840.0;

TextStyle studySerif(TextStyle? style, {FontWeight? weight}) {
  final base = style ?? const TextStyle();
  final emphasis = weight ?? base.fontWeight ?? FontWeight.w400;
  return base.copyWith(
    fontFamily: 'StudyBookSerif',
    fontFamilyFallback: const ['Noto Serif CJK SC', 'Songti SC'],
    fontWeight: emphasis,
    fontVariations: [
      FontVariation('wght', emphasis.value.clamp(400, 700).toDouble()),
    ],
  );
}

class StudyBookTheme extends StatelessWidget {
  const StudyBookTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final dark = base.brightness == Brightness.dark;
    final ink = dark ? const Color(0xfff1f2f4) : const Color(0xff202124);
    final canvas = dark
        ? LoveGirlTheme.neutralCanvasDark
        : LoveGirlTheme.neutralCanvasLight;
    final surface = dark ? const Color(0xff24262b) : Colors.white;
    final primary = dark ? const Color(0xffecedee) : const Color(0xff27282b);
    final selection = dark ? const Color(0xff393c42) : const Color(0xffe8e9eb);
    final rule = dark ? const Color(0xff51545a) : const Color(0xffd6d7da);
    final secondaryInk =
        dark ? const Color(0xffbfc1c7) : const Color(0xff626469);
    final colors = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: dark ? LoveGirlTheme.neutralCanvasDark : Colors.white,
      primaryContainer: selection,
      onPrimaryContainer: ink,
      secondaryContainer: selection,
      onSecondaryContainer: ink,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: secondaryInk,
      surfaceContainerLow: canvas,
      surfaceContainerHighest: selection,
      outline: rule,
      outlineVariant: rule,
    );
    final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);
    final textTheme = text.copyWith(
      headlineMedium: studySerif(text.headlineMedium, weight: FontWeight.w700),
      headlineSmall: studySerif(text.headlineSmall, weight: FontWeight.w700),
      titleLarge: studySerif(text.titleLarge, weight: FontWeight.w700),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: colors,
        scaffoldBackgroundColor: canvas,
        dividerColor: rule,
        textTheme: textTheme,
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: canvas,
          foregroundColor: ink,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        listTileTheme: base.listTileTheme
            .copyWith(textColor: ink, iconColor: secondaryInk),
        progressIndicatorTheme:
            base.progressIndicatorTheme.copyWith(color: primary),
      ),
      child: child,
    );
  }
}
