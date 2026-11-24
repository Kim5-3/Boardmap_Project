import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'location_position.dart';

Future<BoardMapPosition?> getBoardMapPosition() {
  final completion = Completer<BoardMapPosition?>();
  final geolocation = web.window.navigator.geolocation;
  geolocation.getCurrentPosition(
    ((web.GeolocationPosition position) {
      final coords = position.coords;
      if (!completion.isCompleted) {
        completion.complete(BoardMapPosition(coords.latitude, coords.longitude));
      }
    }).toJS,
    ((web.GeolocationPositionError _) {
      if (!completion.isCompleted) completion.complete(null);
    }).toJS,
  );
  return completion.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => null,
  );
}

void openBoardMapDirections(double fromLat, double fromLng, double toLat, double toLng) {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': '$fromLat,$fromLng',
    'destination': '$toLat,$toLng',
    'travelmode': 'walking',
  });
  web.window.open(uri.toString(), '_blank');
}
