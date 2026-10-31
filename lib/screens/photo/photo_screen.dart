import 'package:flutter/material.dart';
import '../../features/creations/creation_gallery.dart';

class PhotoScreen extends StatelessWidget {
  final bool createOnOpen;
  const PhotoScreen({super.key, this.createOnOpen = false});
  @override
  Widget build(BuildContext context) =>
      CreationGallery(createOnOpen: createOnOpen);
}
