import 'package:flutter/material.dart';
import '../../models/travel.dart';
import '../../features/creations/creation_gallery.dart';

class TravelTicketScreen extends StatelessWidget {
  final List<TravelSpot> visitedSpots;
  final TravelStats stats;
  const TravelTicketScreen(
      {super.key, required this.visitedSpots, required this.stats});
  @override
  Widget build(BuildContext context) => const CreationGallery(kind: 'ticket');
}
