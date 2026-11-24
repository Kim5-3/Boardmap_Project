import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OpenStreetMap foot routing through the FOSSGIS OSRM service.
class WalkingRoute {
  const WalkingRoute({required this.points, required this.distanceMeters});

  final List<LatLng> points;
  final double distanceMeters;
}

class WalkingRouteService {
  static const _host = 'routing.openstreetmap.de';
  static Future<void> _requestQueue = Future<void>.value();
  static DateTime? _lastRequestAt;

  static Future<T> _request<T>(Future<T> Function() send) {
    final result = Completer<T>();
    _requestQueue = _requestQueue.then((_) async {
      final last = _lastRequestAt;
      if (last != null) {
        final delay = const Duration(seconds: 1) - DateTime.now().difference(last);
        if (delay > Duration.zero) await Future<void>.delayed(delay);
      }
      try {
        result.complete(await send());
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _lastRequestAt = DateTime.now();
      }
    });
    return result.future;
  }

  static String _coordinate(LatLng point) =>
      '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}';

  /// Returns road-network distances for one origin and many destinations.
  static Future<List<double?>> distances(LatLng origin, List<LatLng> destinations) async {
    if (destinations.isEmpty) return const [];
    final result = <double?>[];
    for (var start = 0; start < destinations.length; start += 90) {
      final chunk = destinations.skip(start).take(90).toList(growable: false);
      result.addAll(await _distanceChunk(origin, chunk));
    }
    return result;
  }

  static Future<List<double?>> _distanceChunk(
    LatLng origin,
    List<LatLng> destinations,
  ) async {
    final points = [origin, ...destinations];
    final destinationIndexes = List.generate(destinations.length, (index) => index + 1);
    final uri = Uri.https(
      _host,
      '/routed-foot/table/v1/driving/${points.map(_coordinate).join(';')}',
      {'sources': '0', 'destinations': destinationIndexes.join(';'), 'annotations': 'distance'},
    );
    final response = await _request(() => http.get(uri).timeout(const Duration(seconds: 15)));
    if (response.statusCode != 200) throw Exception('Walking distance service returned ${response.statusCode}.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') throw Exception('No walking routes are available for these locations.');
    final rows = data['distances'] as List?;
    final row = rows?.isNotEmpty == true ? rows!.first as List? : null;
    return List<double?>.generate(destinations.length, (index) {
      final value = row != null && index < row.length ? row[index] : null;
      return value is num ? value.toDouble() : null;
    });
  }

  /// Returns the walking path geometry and road distance for one selected house.
  static Future<WalkingRoute> route(LatLng origin, LatLng destination) async {
    final uri = Uri.https(
      _host,
      '/routed-foot/route/v1/driving/${_coordinate(origin)};${_coordinate(destination)}',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
        'alternatives': '3',
      },
    );
    final response = await _request(() => http.get(uri).timeout(const Duration(seconds: 15)));
    if (response.statusCode != 200) throw Exception('Walking route service returned ${response.statusCode}.');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') throw Exception('No walking route is available for this location.');
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) throw Exception('No walking route is available for this location.');
    final alternatives = routes.cast<Map<String, dynamic>>();
    alternatives.sort(
      (a, b) => (a['distance'] as num).compareTo(b['distance'] as num),
    );
    final shortestReturnedRoute = alternatives.first;
    final geometry = shortestReturnedRoute['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;
    return WalkingRoute(
      distanceMeters: (shortestReturnedRoute['distance'] as num).toDouble(),
      points: coordinates.map((item) {
        final coordinate = item as List;
        return LatLng((coordinate[1] as num).toDouble(), (coordinate[0] as num).toDouble());
      }).toList(growable: false),
    );
  }
}
