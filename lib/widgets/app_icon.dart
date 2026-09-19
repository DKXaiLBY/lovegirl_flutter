import 'package:flutter/material.dart';

/// LoveGirl 图标资源（assets/images/icons/，透明底 PNG，程序化绘制）
///
/// 三色变体：normal 近黑（浅底用） / white 纯白（深色底座用） / grey 次要灰
/// 使用：AppIcon('kitchen', size: 24)
/// 深色底座容器由 UI 层绘制：Container(color: Color(0xFF1A1A1A), ... child: AppIcon('kitchen', variant: AppIconVariant.white))
enum AppIconVariant { normal, white, grey }

class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final AppIconVariant variant;

  const AppIcon(this.name, {super.key, this.size = 24, this.variant = AppIconVariant.normal});

  @override
  Widget build(BuildContext context) {
    final suffix = switch (variant) {
      AppIconVariant.white => '_white',
      AppIconVariant.grey => '_grey',
      AppIconVariant.normal => '',
    };
    return Image.asset(
      'assets/images/icons/icon_$name$suffix.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}
