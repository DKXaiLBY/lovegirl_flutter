import 'package:flutter/material.dart';

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
    final ink = dark ? const Color(0xffe9eef6) : const Color(0xff162846);
    final canvas = dark ? const Color(0xff161e2a) : const Color(0xfff8f7f2);
    final primary = dark ? const Color(0xffb8cef0) : const Color(0xff254878);
    final selection = dark ? const Color(0xff2b3d55) : const Color(0xffe3ebf6);
    final rule = dark ? const Color(0xff495566) : const Color(0xffbac5d2);
    final secondaryInk =
        dark ? const Color(0xffbecadb) : const Color(0xff465974);
    final colors = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: dark ? const Color(0xff152641) : Colors.white,
      primaryContainer: selection,
      onPrimaryContainer: ink,
      surface: canvas,
      onSurface: ink,
      onSurfaceVariant: secondaryInk,
      surfaceContainerLow:
          dark ? const Color(0xff202938) : const Color(0xfff1f0eb),
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
