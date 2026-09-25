import 'package:flutter/material.dart';

/// LoveGirl 插画资源（assets/images/illus/，透明底彩色贴纸插画 PNG）
///
/// 使用：IllusImg('empty_ticket', height: 110)
/// 名称不含 illus_ 前缀与扩展名；只约束高度，宽度按原图比例自适应。
class IllusImg extends StatelessWidget {
  final String name;
  final double height;
  final double? width;

  const IllusImg(this.name, {super.key, required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    // 按展示高度×像素比缓存解码位图，避免 512-768px 原图全尺寸驻留
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 3.0;
    return Image.asset(
      'assets/images/illus/illus_$name.png',
      height: height,
      width: width,
      fit: BoxFit.contain,
      cacheWidth: (height * dpr).round(),
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
