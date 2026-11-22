import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_globe/flutter_globe.dart';

/// Orthographic surface aligned with the same rotation used for the place markers.
class FootprintLand extends GlobeLayer {
  final ui.Image _mask;
  final ui.FragmentShader _shader;
  final Paint _paint = Paint();
  bool dark = false;

  FootprintLand._(this._mask, this._shader) : super(zIndex: 11) {
    _shader.setImageSampler(0, _mask);
    _paint.shader = _shader;
  }

  static Future<FootprintLand> load() async {
    final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/footprint_land.frag');
    // Public-domain Natural Earth 1:110m land polygons, rasterized as a mask.
    // https://www.naturalearthdata.com/downloads/110m-physical-vectors/110m-land/
    final data = await rootBundle.load('assets/geo/world_land.png');
    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    try {
      return FootprintLand._(
          (await codec.getNextFrame()).image, program.fragmentShader());
    } finally {
      codec.dispose();
    }
  }

  void dispose() {
    _shader.dispose();
    _mask.dispose();
  }

  @override
  void paint(GlobeRenderContext context) {
    final camera = context.camera;
    final rotate = context.rotation.conjugate;
    final x = rotate.rotateVector(Vector3D.unitX);
    final y = rotate.rotateVector(Vector3D.unitY);
    final z = rotate.rotateVector(Vector3D.unitZ);
    final ocean = dark ? const Color(0xff386182) : const Color(0xffa8dcf3);
    final land = dark ? const Color(0xff76ad99) : const Color(0xffc9e8bf);
    _shader
      ..setFloat(0, camera.center.dx)
      ..setFloat(1, camera.center.dy)
      ..setFloat(2, camera.radius)
      ..setFloat(3, x.x)
      ..setFloat(4, x.y)
      ..setFloat(5, x.z)
      ..setFloat(6, y.x)
      ..setFloat(7, y.y)
      ..setFloat(8, y.z)
      ..setFloat(9, z.x)
      ..setFloat(10, z.y)
      ..setFloat(11, z.z)
      ..setFloat(12, ocean.r)
      ..setFloat(13, ocean.g)
      ..setFloat(14, ocean.b)
      ..setFloat(15, land.r)
      ..setFloat(16, land.g)
      ..setFloat(17, land.b);
    context.canvas.drawCircle(camera.center, camera.radius, _paint);
  }
}
