import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'image_picker.dart';

Future<List<PickedBoardMapImage>> pickBoardMapImages() {
  final completion = Completer<List<PickedBoardMapImage>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/jpeg,image/webp'
    ..multiple = true;
  input.addEventListener(
    'change',
    ((web.Event _) {
      () async {
        try {
          final files = input.files;
          final result = <PickedBoardMapImage>[];
          if (files != null) {
            for (var index = 0; index < files.length; index++) {
              final file = files.item(index);
              if (file == null) continue;
              final buffer = await file.arrayBuffer().toDart;
              result.add(PickedBoardMapImage(
                name: file.name,
                bytes: Uint8List.view(buffer.toDart),
              ));
            }
          }
          if (!completion.isCompleted) completion.complete(result);
        } catch (error) {
          if (!completion.isCompleted) completion.completeError(error);
        }
      }();
    }).toJS,
  );
  input.click();
  return completion.future;
}
