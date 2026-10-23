import 'package:flutter/material.dart';

class TravelSpotMoreMenu extends StatelessWidget {
  final VoidCallback onAddRoute;
  final VoidCallback onGenerateTicket;
  final VoidCallback? onDelete;

  const TravelSpotMoreMenu({
    super.key,
    required this.onAddRoute,
    required this.onGenerateTicket,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '更多操作',
      onSelected: (value) {
        switch (value) {
          case 'route':
            onAddRoute();
          case 'ticket':
            onGenerateTicket();
          case 'delete':
            onDelete?.call();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'route', child: Text('加入路线')),
        const PopupMenuItem(value: 'ticket', child: Text('生成票根')),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(value: 'delete', child: Text('删除地点')),
        ],
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded, size: 20),
            SizedBox(width: 4),
            Text('更多'),
          ],
        ),
      ),
    );
  }
}
