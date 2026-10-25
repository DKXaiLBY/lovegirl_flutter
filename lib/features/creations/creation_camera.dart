import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'creation_catalog.dart';

class CreationCapture {
  final String path;
  final String lookId;
  const CreationCapture(this.path, this.lookId);
}

class CreationCamera extends StatefulWidget {
  const CreationCamera({super.key});
  @override
  State<CreationCamera> createState() => _CreationCameraState();
}

class _CreationCameraState extends State<CreationCamera>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _lens = 0;
  int _look = 0;
  int _operation = 0;
  bool _busy = false;
  String? _error;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final operation = ++_operation;
    final old = _controller;
    _controller = null;
    if (mounted) setState(() => _error = null);
    await old?.dispose();
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) throw StateError('没有找到相机，可以从相册导入照片');
      if (!mounted || operation != _operation) return;
      final controller = CameraController(
          _cameras[_lens], ResolutionPreset.high,
          enableAudio: false);
      _controller = controller;
      await controller.initialize();
      if (!mounted || operation != _operation) return;
      await controller.setFlashMode(_flash);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() => _error = '相机暂不可用，请检查相机权限，也可以返回后从相册导入');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _operation++;
      final controller = _controller;
      _controller = null;
      unawaited(controller?.dispose());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_open());
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      HapticFeedback.lightImpact();
      final image = await controller.takePicture();
      if (mounted) {
        Navigator.pop(
            context, CreationCapture(image.path, creationLooks[_look].id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('拍摄失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _operation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: const Color(0xff17191d),
      appBar: AppBar(
          title: const Text('留住这一刻'),
          backgroundColor: const Color(0xff17191d),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
                tooltip: _flash == FlashMode.off ? '开启闪光灯' : '关闭闪光灯',
                onPressed: controller == null
                    ? null
                    : () async {
                        final next = _flash == FlashMode.off
                            ? FlashMode.always
                            : FlashMode.off;
                        try {
                          await controller.setFlashMode(next);
                          if (mounted) setState(() => _flash = next);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('这个镜头不支持闪光灯')));
                          }
                        }
                      },
                icon: Icon(
                    _flash == FlashMode.off ? Icons.flash_off : Icons.flash_on))
          ]),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!,
                              style: const TextStyle(color: Colors.white)),
                          TextButton(onPressed: _open, child: const Text('重试'))
                        ]))
                    : controller == null || !controller.value.isInitialized
                        ? const CircularProgressIndicator(color: Colors.white)
                        : AspectRatio(
                            aspectRatio: 3 / 4,
                            child: ClipRect(
                                child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix(
                                        creationLooks[_look].matrix(1)),
                                    child: CameraPreview(controller)))))),
        const Padding(
            padding: EdgeInsets.all(8),
            child: Text('成像风格实时预览 · 颗粒与纸感在成片中呈现',
                style: TextStyle(color: Colors.white60, fontSize: 11))),
        SizedBox(
            height: 64,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: creationLooks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(
                    label: Text(creationLooks[i].label),
                    selected: _look == i,
                    onSelected: (_) => setState(() => _look = i)))),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  IconButton.filled(
                      tooltip: '拍摄',
                      onPressed: _busy ? null : _capture,
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(76, 76)),
                      icon: _busy
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator())
                          : const Icon(Icons.circle_outlined, size: 54)),
                  IconButton(
                      tooltip: '切换镜头',
                      onPressed: _busy || _cameras.length < 2
                          ? null
                          : () {
                              _lens = (_lens + 1) % _cameras.length;
                              unawaited(_open());
                            },
                      icon: const Icon(Icons.cameraswitch_outlined,
                          color: Colors.white))
                ]))
      ])),
    );
  }
}
