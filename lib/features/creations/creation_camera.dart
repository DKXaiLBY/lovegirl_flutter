import '../../widgets/rebuild_controls.dart';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
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
  int _delay = 0;
  int _remaining = 0;
  Timer? _timer;

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _remaining = 0;
  }

  void _shutter() {
    if (_remaining > 0) {
      setState(_cancelTimer);
      return;
    }
    if (_delay == 0) {
      unawaited(_capture());
      return;
    }
    setState(() => _remaining = _delay);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        setState(_cancelTimer);
        unawaited(_capture());
      } else {
        setState(() => _remaining--);
        HapticFeedback.selectionClick();
      }
    });
  }

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
      try {
        await controller.setFlashMode(_flash);
      } on CameraException {
        _flash = FlashMode.off;
        await controller.setFlashMode(FlashMode.off);
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() => _error = '相机暂不可用，请检查相机权限，也可以返回后从相册导入');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The permission prompt temporarily removes focus during initialize().
    // Disposing then races the native camera session that is still opening.
    if (_controller != null && !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      setState(_cancelTimer);
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
    final operation = _operation;
    setState(() => _busy = true);
    try {
      HapticFeedback.lightImpact();
      final image = await controller.takePicture();
      if (mounted && operation == _operation) {
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

  Future<void> _import() async {
    if (_busy || _remaining > 0) return;
    setState(() => _busy = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        Navigator.pop(
            context, CreationCapture(image.path, creationLooks[_look].id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('照片未能导入，可以重试或返回后选择')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cancelTimer();
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
          title: const Text('留住这一刻', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xff17191d),
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<int>(
                tooltip: '定时拍摄',
                enabled: !_busy && _remaining == 0,
                initialValue: _delay,
                onSelected: (value) => setState(() => _delay = value),
                icon: Icon(_delay == 3
                    ? Icons.timer_3_outlined
                    : _delay == 10
                        ? Icons.timer_10_outlined
                        : Icons.timer_off_outlined),
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 0, child: Text('关闭定时')),
                      PopupMenuItem(value: 3, child: Text('3 秒')),
                      PopupMenuItem(value: 10, child: Text('10 秒')),
                    ]),
            IconButton(
                tooltip: _flash == FlashMode.off ? '开启闪光灯' : '关闭闪光灯',
                onPressed: controller == null || _busy || _remaining > 0
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
                          TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white),
                              onPressed: _open,
                              child: const Text('重试'))
                        ]))
                    : controller == null || !controller.value.isInitialized
                        ? const CircularProgressIndicator(color: Colors.white)
                        : AspectRatio(
                            aspectRatio: 3 / 4,
                            child: ClipRect(
                                child: ColorFiltered(
                                    colorFilter: ColorFilter.matrix(
                                        creationLooks[_look].matrix(1)),
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      CameraPreview(controller),
                                      if (_remaining > 0)
                                        Center(
                                            child: Semantics(
                                                liveRegion: true,
                                                label: '倒计时 $_remaining 秒',
                                                child: Text('$_remaining',
                                                    style: const TextStyle(
                                                        fontSize: 80,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                              blurRadius: 12,
                                                              color:
                                                                  Colors.black)
                                                        ]))))
                                    ])))))),
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
                itemBuilder: (_, i) => RebuildChoiceChip(
                    label: Text(creationLooks[i].label),
                    selected: _look == i,
                    onSelected: _busy || _remaining > 0
                        ? null
                        : (_) => setState(() => _look = i)))),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      tooltip: '从相册导入',
                      onPressed: _busy || _remaining > 0 ? null : _import,
                      icon: const Icon(Icons.photo_library_outlined,
                          color: Colors.white)),
                  Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xfffbfcfd),
                                Color(0xff9298a0),
                                Color(0xffedf0f3),
                                Color(0xff6b727b)
                              ]),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black45,
                                blurRadius: 8,
                                offset: Offset(0, 3))
                          ]),
                      child: IconButton.filled(
                          tooltip: _remaining > 0 ? '取消定时拍摄' : '拍摄',
                          onPressed:
                              _busy || controller == null || !controller.value.isInitialized
                                  ? null
                                  : _shutter,
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(76, 76)),
                          icon: _busy
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator())
                              : Icon(_remaining > 0 ? Icons.close : Icons.circle_outlined,
                                  size: 54))),
                  IconButton(
                      tooltip: '切换镜头',
                      onPressed: _busy || _remaining > 0 || _cameras.length < 2
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
