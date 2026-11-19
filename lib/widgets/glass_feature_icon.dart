import 'package:flutter/material.dart';

enum GlassFeature {
  weather,
  polaroid,
  ticket,
  walk,
  footprint,
  packing,
  kitchen,
  mood
}

class GlassFeatureIcon extends StatelessWidget {
  final GlassFeature feature;
  final double size;

  const GlassFeatureIcon(this.feature, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/glass_features/${feature.name}.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
}
