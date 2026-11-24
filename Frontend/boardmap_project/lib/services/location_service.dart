import 'location_service_stub.dart'
    if (dart.library.html) 'location_service_web.dart' as platform;
import 'location_position.dart';

Future<BoardMapPosition?> getBoardMapPosition() =>
    platform.getBoardMapPosition();

void openBoardMapDirections(double fromLat, double fromLng, double toLat, double toLng) =>
    platform.openBoardMapDirections(fromLat, fromLng, toLat, toLng);
