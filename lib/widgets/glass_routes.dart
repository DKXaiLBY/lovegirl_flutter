import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/map_prefs_provider.dart';
import '../utils/lovegirl_theme.dart';
import 'rebuild_controls.dart';

ThemeData glassNavigationTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final surface = dark ? const Color(0xf124303b) : const Color(0xf1f7fcff);
  final border = dark ? const Color(0x536e94ad) : const Color(0xffd8e9f1);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
    side: BorderSide(color: border),
  );
  return base.copyWith(
    colorScheme: dark
        ? base.colorScheme.copyWith(
            primary: LoveGirlTheme.textPrimaryDark,
            onPrimary: LoveGirlTheme.bgDark,
          )
        : base.colorScheme,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    datePickerTheme: base.datePickerTheme.copyWith(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    timePickerTheme:
        base.timePickerTheme.copyWith(backgroundColor: surface, shape: shape),
    dropdownMenuTheme: base.dropdownMenuTheme.copyWith(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(shape),
      ),
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
  );
}

Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
}) {
  final reduce = MediaQuery.disableAnimationsOf(context) ||
      context.read<MapPrefsProvider?>()?.motionEnabled == false;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: reduce
        ? AnimationStyle.noAnimation
        : AnimationStyle(
            duration: const Duration(milliseconds: 230),
            reverseDuration: const Duration(milliseconds: 180),
          ),
    builder: (sheet) => RebuildGlass(radius: 24, child: builder(sheet)),
  );
}

class GlassAlertDialog extends AlertDialog {
  const GlassAlertDialog({
    super.key,
    super.title,
    super.titlePadding,
    super.titleTextStyle,
    super.icon,
    super.content,
    super.contentPadding,
    super.contentTextStyle,
    super.actions,
    super.actionsPadding,
    super.actionsAlignment,
    super.buttonPadding,
    super.backgroundColor,
    super.shape,
    super.insetPadding,
    super.scrollable,
  });

  @override
  Widget build(BuildContext context) {
    final alert = super.build(context);
    if (alert is! Dialog || alert.child == null) return alert;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = backgroundColor ??
        (dark ? const Color(0xff242e38) : const Color(0xfff7fcff));
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: alert.insetPadding,
      alignment: alert.alignment,
      child: RebuildGlass(
          radius: 24,
          child: ColoredBox(
            color: tint.withAlpha(178),
            child: alert.child!,
          )),
    );
  }
}
