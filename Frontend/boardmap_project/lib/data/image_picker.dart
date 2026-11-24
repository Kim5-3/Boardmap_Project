import 'dart:typed_data';

import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart' as platform;

class PickedBoardMapImage {
  const PickedBoardMapImage({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

Future<List<PickedBoardMapImage>> pickBoardMapImages() =>
    platform.pickBoardMapImages();
