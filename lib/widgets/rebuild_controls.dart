import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/lovegirl_theme.dart';

ButtonStyle rebuildFilledStyle(BuildContext context) => FilledButton.styleFrom(
    backgroundColor: context.lgInk,
    foregroundColor: context.lgPaper,
    iconColor: context.lgPaper,
    disabledBackgroundColor: context.lgSeparator,
    disabledForegroundColor: context.lgTextSecondary);

ButtonStyle rebuildTextStyle(BuildContext context) => TextButton.styleFrom(
    foregroundColor: context.lgInk, iconColor: context.lgInk);

ButtonStyle rebuildOutlinedStyle(BuildContext context) =>
    OutlinedButton.styleFrom(
        foregroundColor: context.lgInk, iconColor: context.lgInk);

class RebuildChoiceChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  const RebuildChoiceChip(
      {super.key,
      required this.label,
      required this.selected,
      this.onSelected});
  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: label,
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        selectedColor: context.lgInk,
        backgroundColor: context.lgPaper,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
            color: selected ? context.lgPaper : context.lgInk, fontSize: 12),
        side: BorderSide(color: selected ? context.lgInk : context.lgSeparator),
      );
}

class RebuildGlass extends StatelessWidget {
  final Widget child;
  const RebuildGlass({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child:
                Material(color: context.lgPaper.withAlpha(230), child: child)),
      );
}
