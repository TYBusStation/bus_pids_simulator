import 'package:latlong2/latlong.dart';
import 'package:turf/turf.dart' as turf;

import '../data/bus_station.dart';

class RouteAnalysisResult {
  final bool isOffRoute;
  final double distanceToRoute;
  final BusStation? prevStation;
  final BusStation? nextStation;
  final double? distToPrevStation;
  final double? distToNextStation;
  final double progress;
  final double? bearing;
  final Map<int, double> stationPositions;

  RouteAnalysisResult({
    required this.isOffRoute,
    required this.distanceToRoute,
    this.prevStation,
    this.nextStation,
    this.distToPrevStation,
    this.distToNextStation,
    required this.progress,
    this.bearing,
    required this.stationPositions,
  });
}

class RouteEngine {
  static const double offRouteThreshold = 200.0;

  static RouteAnalysisResult analyze({
    required LatLng currentPos,
    required List<LatLng> routePoints,
    required List<BusStation> stations,
    double? heading,
  }) {
    final pt = turf.Point(
      coordinates: turf.Position(currentPos.longitude, currentPos.latitude),
    );

    double totalDist = 0;
    List<Map<String, dynamic>> candidates = [];

    for (int i = 0; i < routePoints.length - 1; i++) {
      final p1 = routePoints[i];
      final p2 = routePoints[i + 1];
      final segment = turf.LineString(
        coordinates: [
          turf.Position(p1.longitude, p1.latitude),
          turf.Position(p2.longitude, p2.latitude),
        ],
      );
      final segmentFeature = turf.Feature<turf.LineString>(geometry: segment);

      final snapped = turf.nearestPointOnLine(segment, pt);
      final double distM =
          ((snapped.properties?['dist'] ?? 0.0) as num).toDouble() * 1000;
      final double segBearing = turf
          .bearing(
            turf.Point(coordinates: turf.Position(p1.longitude, p1.latitude)),
            turf.Point(coordinates: turf.Position(p2.longitude, p2.latitude)),
          )
          .toDouble();

      final double locationOnSegment =
          ((snapped.properties?['location'] ?? 0.0) as num).toDouble();

      candidates.add({
        'dist': distM,
        'bearing': (segBearing + 360) % 360,
        'location': totalDist + locationOnSegment,
        'index': i,
      });

      totalDist += turf.length(segmentFeature).toDouble();
    }

    candidates.sort(
      (a, b) => (a['dist'] as double).compareTo(b['dist'] as double),
    );
    Map<String, dynamic> best = candidates.first;

    if (heading != null && candidates.length > 1) {
      List<Map<String, dynamic>> nearby = candidates
          .where((c) => (c['dist'] as double) <= (best['dist'] as double) + 5.0)
          .toList();

      bool hasDirectionConflict = false;
      for (var c in nearby) {
        double diff = (c['bearing'] - best['bearing']).abs();
        if (diff > 180) diff = 360 - diff;
        if (diff > 90) {
          hasDirectionConflict = true;
          break;
        }
      }

      if (hasDirectionConflict) {
        double minDiff = double.infinity;
        for (var c in nearby) {
          double diff = (c['bearing'] - heading).abs();
          if (diff > 180) diff = 360 - diff;
          if (diff < minDiff) {
            minDiff = diff;
            best = c;
          }
        }
      }
    }

    final double distToRouteMeters = best['dist'];
    final bool isOffRoute = distToRouteMeters > offRouteThreshold;
    final double userLocOnLine = best['location'];
    final double? currentBearing = best['bearing'];

    final lineGeom = turf.LineString(
      coordinates: routePoints
          .map((p) => turf.Position(p.longitude, p.latitude))
          .toList(),
    );
    final lineFeature = turf.Feature<turf.LineString>(geometry: lineGeom);
    final double totalLineDist = turf.length(lineFeature).toDouble();

    BusStation? prev;
    BusStation? next;
    double? dPrev;
    double? dNext;
    Map<int, double> stationPositions = {};

    List<Map<String, dynamic>> mappedStations = [];
    for (var s in stations) {
      final sPt = turf.Point(
        coordinates: turf.Position(s.position.longitude, s.position.latitude),
      );
      final sSnapped = turf.nearestPointOnLine(lineGeom, sPt);
      double sLoc = ((sSnapped.properties?['location'] ?? 0.0) as num)
          .toDouble();
      mappedStations.add({'station': s, 'location': sLoc});
      stationPositions[s.order] = sLoc;
    }

    mappedStations.sort(
      (a, b) => (a['location'] as double).compareTo(b['location'] as double),
    );

    for (int i = 0; i < mappedStations.length; i++) {
      double sLoc = mappedStations[i]['location'] as double;
      if (userLocOnLine >= sLoc) {
        prev = mappedStations[i]['station'];
        dPrev = (userLocOnLine - sLoc).abs() * 1000;
      } else {
        next = mappedStations[i]['station'];
        dNext = (sLoc - userLocOnLine).abs() * 1000;
        break;
      }
    }

    return RouteAnalysisResult(
      isOffRoute: isOffRoute,
      distanceToRoute: distToRouteMeters,
      prevStation: prev,
      nextStation: next,
      distToPrevStation: dPrev,
      distToNextStation: dNext,
      progress: totalLineDist > 0
          ? (userLocOnLine / totalLineDist).toDouble()
          : 0.0,
      bearing: currentBearing,
      stationPositions: stationPositions,
    );
  }
}
