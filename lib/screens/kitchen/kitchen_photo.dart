import 'package:flutter/material.dart';

import '../../providers/kitchen_provider.dart';
import '../../utils/constants.dart';
import '../../utils/lovegirl_theme.dart';

class KitchenPhoto extends StatefulWidget {
  final String? path;
  final int cacheWidth;
  const KitchenPhoto({super.key, required this.path, this.cacheWidth = 600});

  @override
  State<KitchenPhoto> createState() => _KitchenPhotoState();
}

class _KitchenPhotoState extends State<KitchenPhoto> {
  int _attempt = 0;
  bool _retrying = false;

  Widget _surface(BuildContext context, Widget child) =>
      ColoredBox(color: context.lgPrimarySoft, child: Center(child: child));

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (path == null || path.isEmpty) {
      return _surface(
          context,
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.restaurant_outlined,
                color: context.lgTextMuted, size: 28),
            const SizedBox(height: 6),
            Text('还没有照片',
                style: TextStyle(fontSize: 11, color: context.lgTextMuted)),
          ]));
    }
    final image = ResizeImage.resizeIfNeeded(widget.cacheWidth, null,
        NetworkImage(kitchenPhotoUrl(path, AppConstants.baseUrl)));
    return Image(
      key: ValueKey((path, _attempt)),
      image: image,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, synchronous) => synchronous ||
              frame != null
          ? child
          : _surface(
              context,
              Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(height: 8),
                Text('照片载入中',
                    style: TextStyle(fontSize: 11, color: context.lgTextMuted)),
              ])),
      errorBuilder: (context, _, __) => _surface(
          context,
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('照片暂未载入',
                style: TextStyle(fontSize: 11, color: context.lgTextMuted)),
            TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: _retrying
                    ? null
                    : () async {
                        setState(() => _retrying = true);
                        await image.evict();
                        if (mounted) {
                          setState(() {
                            _attempt++;
                            _retrying = false;
                          });
                        }
                      },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('重试照片')),
          ])),
    );
  }
}
