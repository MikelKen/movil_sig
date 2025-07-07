import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _apiKey = 'AIzaSyDbpv3i7Tno3aicF4_1GnUUHGQLFo1GOLY';

  // Obtener direcciones entre múltiples puntos (waypoints)
  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
    bool optimizeWaypoints = true,
    String travelMode = 'driving',
  }) async {
    try {
      String waypointsParam = '';
      if (waypoints != null && waypoints.isNotEmpty) {
        final waypointStrings = waypoints
            .map((point) => '${point.latitude},${point.longitude}')
            .join('|');
        waypointsParam = '&waypoints=${optimizeWaypoints ? 'optimize:true|' : ''}$waypointStrings';
      }

      final url = '$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '$waypointsParam'
          '&mode=$travelMode'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return DirectionsResult.fromJson(data);
        } else {
          print('Directions API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          return null;
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }

  // Decodificar polyline (algoritmo de Google)
  static List<LatLng> decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

class DirectionsResult {
  final List<RouteDirection> routes;
  final String status;
  final String? errorMessage;

  DirectionsResult({
    required this.routes,
    required this.status,
    this.errorMessage,
  });

  factory DirectionsResult.fromJson(Map<String, dynamic> json) {
    return DirectionsResult(
      routes: (json['routes'] as List)
          .map((route) => RouteDirection.fromJson(route))
          .toList(),
      status: json['status'],
      errorMessage: json['error_message'],
    );
  }
}

class RouteDirection {
  final List<LatLng> polylinePoints;
  final String summary;
  final List<RouteLeg> legs;
  final LatLng startLocation;
  final LatLng endLocation;
  final String duration;
  final String distance;
  final int durationValue; // en segundos
  final int distanceValue; // en metros

  RouteDirection({
    required this.polylinePoints,
    required this.summary,
    required this.legs,
    required this.startLocation,
    required this.endLocation,
    required this.duration,
    required this.distance,
    required this.durationValue,
    required this.distanceValue,
  });

  factory RouteDirection.fromJson(Map<String, dynamic> json) {
    final overviewPolyline = json['overview_polyline']['points'];
    final polylinePoints = DirectionsService.decodePolyline(overviewPolyline);

    final legs = (json['legs'] as List)
        .map((leg) => RouteLeg.fromJson(leg))
        .toList();

    // Calcular totales
    int totalDuration = legs.fold(0, (sum, leg) => sum + leg.durationValue);
    int totalDistance = legs.fold(0, (sum, leg) => sum + leg.distanceValue);

    return RouteDirection(
      polylinePoints: polylinePoints,
      summary: json['summary'] ?? '',
      legs: legs,
      startLocation: LatLng(
        json['legs'][0]['start_location']['lat'],
        json['legs'][0]['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['legs'].last['end_location']['lat'],
        json['legs'].last['end_location']['lng'],
      ),
      duration: _formatDuration(totalDuration),
      distance: _formatDistance(totalDistance),
      durationValue: totalDuration,
      distanceValue: totalDistance,
    );
  }

  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  static String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '$meters m';
    }
  }
}

class RouteLeg {
  final LatLng startLocation;
  final LatLng endLocation;
  final String startAddress;
  final String endAddress;
  final String duration;
  final String distance;
  final int durationValue; // en segundos
  final int distanceValue; // en metros
  final List<RouteStep> steps;

  RouteLeg({
    required this.startLocation,
    required this.endLocation,
    required this.startAddress,
    required this.endAddress,
    required this.duration,
    required this.distance,
    required this.durationValue,
    required this.distanceValue,
    required this.steps,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      startLocation: LatLng(
        json['start_location']['lat'],
        json['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['end_location']['lat'],
        json['end_location']['lng'],
      ),
      startAddress: json['start_address'] ?? '',
      endAddress: json['end_address'] ?? '',
      duration: json['duration']['text'],
      distance: json['distance']['text'],
      durationValue: json['duration']['value'],
      distanceValue: json['distance']['value'],
      steps: (json['steps'] as List)
          .map((step) => RouteStep.fromJson(step))
          .toList(),
    );
  }
}

class RouteStep {
  final LatLng startLocation;
  final LatLng endLocation;
  final String htmlInstructions;
  final String distance;
  final String duration;
  final String travelMode;
  final List<LatLng> polylinePoints;

  RouteStep({
    required this.startLocation,
    required this.endLocation,
    required this.htmlInstructions,
    required this.distance,
    required this.duration,
    required this.travelMode,
    required this.polylinePoints,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final polylinePoints = DirectionsService.decodePolyline(
      json['polyline']['points'],
    );

    return RouteStep(
      startLocation: LatLng(
        json['start_location']['lat'],
        json['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['end_location']['lat'],
        json['end_location']['lng'],
      ),
      htmlInstructions: json['html_instructions'] ?? '',
      distance: json['distance']['text'],
      duration: json['duration']['text'],
      travelMode: json['travel_mode'],
      polylinePoints: polylinePoints,
    );
  }
}
