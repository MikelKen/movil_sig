import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/delivery_route.dart';
import '../models/order.dart';
import '../config/api_config.dart';

class RouteOptimizationService {
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _distanceMatrixBaseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

  /// Optimiza una ruta de entregas usando el algoritmo del viajante más cercano
  Future<DeliveryRoute> optimizeDeliveryRoute({
    required LatLng startLocation,
    required List<Order> orders,
    LatLng? endLocation,
  }) async {
    if (orders.isEmpty) {
      throw Exception('No hay órdenes para optimizar');
    }

    if (!ApiConfig.isApiKeyConfigured) {
      throw Exception('API Key de Google Maps no configurada. '
          'Por favor configura tu API key en lib/config/api_config.dart');
    }

    try {
      // 1. Crear matriz de distancias
      final distanceMatrix = await _getDistanceMatrix(
        startLocation,
        orders.map((o) => o.deliveryLocation).toList(),
        endLocation,
      );

      // 2. Aplicar algoritmo de optimización (Nearest Neighbor TSP)
      final optimizedOrder = _nearestNeighborTSP(distanceMatrix);

      // 3. Reorganizar órdenes según la optimización
      final optimizedOrders = optimizedOrder
          .map((index) => orders[index])
          .toList();

      // 4. Calcular ruta completa con Google Directions API
      final routeData = await _getOptimizedRoute(
        startLocation,
        optimizedOrders.map((o) => o.deliveryLocation).toList(),
        endLocation,
      );

      // 5. Crear objeto DeliveryRoute
      return DeliveryRoute(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orders: optimizedOrders,
        polylinePoints: routeData['polylinePoints'] ?? [],
        totalDistance: routeData['totalDistance'] ?? 0.0,
        estimatedDuration: routeData['estimatedDuration'] ?? 0,
        startLocation: startLocation,
        endLocation: endLocation,
        optimizationMethod: 'Nearest Neighbor TSP',
        createdAt: DateTime.now(),
        isOptimized: true,
      );
    } catch (e) {
      throw Exception('Error optimizando ruta: $e');
    }
  }

  /// Obtiene matriz de distancias usando Google Distance Matrix API
  Future<List<List<double>>> _getDistanceMatrix(
    LatLng start,
    List<LatLng> destinations,
    LatLng? end,
  ) async {
    final List<LatLng> allPoints = [start, ...destinations];
    if (end != null) allPoints.add(end);

    final origins = allPoints.map((p) => '${p.latitude},${p.longitude}').join('|');
    final destinationsStr = allPoints.map((p) => '${p.latitude},${p.longitude}').join('|');

    final url = Uri.parse('$_distanceMatrixBaseUrl?'
        'origins=$origins&'
        'destinations=$destinationsStr&'
        'units=metric&'
        'mode=driving&'
        'key=${ApiConfig.getApiKey()}');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final rows = data['rows'] as List;
        final matrix = <List<double>>[];

        for (int i = 0; i < rows.length; i++) {
          final row = <double>[];
          final elements = rows[i]['elements'] as List;

          for (int j = 0; j < elements.length; j++) {
            final element = elements[j];
            if (element['status'] == 'OK') {
              // Usar distancia en metros
              final distance = (element['distance']['value'] as int).toDouble();
              row.add(distance);
            } else {
              // Si no hay ruta, usar distancia euclidiana aproximada
              final distance = _calculateEuclideanDistance(
                allPoints[i],
                allPoints[j]
              );
              row.add(distance);
            }
          }
          matrix.add(row);
        }

        return matrix;
      } else {
        throw Exception('Error en Distance Matrix API: ${data['status']}');
      }
    } else {
      throw Exception('Error HTTP: ${response.statusCode}');
    }
  }

  /// Calcula distancia euclidiana aproximada entre dos puntos
  double _calculateEuclideanDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros

    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Algoritmo Nearest Neighbor para TSP (Traveling Salesman Problem)
  List<int> _nearestNeighborTSP(List<List<double>> distanceMatrix) {
    final n = distanceMatrix.length - 1; // Excluir punto de inicio
    final visited = List<bool>.filled(n + 1, false);
    final route = <int>[];

    int currentCity = 0; // Empezar desde el punto de inicio
    visited[currentCity] = true;

    for (int i = 0; i < n; i++) {
      double minDistance = double.infinity;
      int nextCity = -1;

      // Encontrar la ciudad más cercana no visitada
      for (int j = 1; j <= n; j++) { // Empezar desde 1 (skip punto de inicio)
        if (!visited[j] && distanceMatrix[currentCity][j] < minDistance) {
          minDistance = distanceMatrix[currentCity][j];
          nextCity = j;
        }
      }

      if (nextCity != -1) {
        visited[nextCity] = true;
        route.add(nextCity - 1); // Ajustar índice para órdenes (sin contar inicio)
        currentCity = nextCity;
      }
    }

    return route;
  }

  /// Obtiene ruta optimizada usando Google Directions API
  Future<Map<String, dynamic>> _getOptimizedRoute(
    LatLng start,
    List<LatLng> waypoints,
    LatLng? end,
  ) async {
    String waypointsStr = '';
    if (waypoints.isNotEmpty) {
      waypointsStr = waypoints
          .map((point) => '${point.latitude},${point.longitude}')
          .join('|');
    }

    final destination = end ?? start; // Si no hay punto final, volver al inicio

    final url = Uri.parse('$_directionsBaseUrl?'
        'origin=${start.latitude},${start.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        '${waypointsStr.isNotEmpty ? 'waypoints=$waypointsStr&' : ''}'
        'mode=driving&'
        'units=metric&'
        'key=${ApiConfig.getApiKey()}');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final route = routes[0];
          final legs = route['legs'] as List;

          // Extraer información de la ruta
          double totalDistance = 0;
          int totalDuration = 0;
          final List<LatLng> polylinePoints = [];

          for (final leg in legs) {
            totalDistance += (leg['distance']['value'] as int).toDouble();
            totalDuration += leg['duration']['value'] as int;

            // Decodificar polyline de cada tramo
            final steps = leg['steps'] as List;
            for (final step in steps) {
              final polyline = step['polyline']['points'] as String;
              polylinePoints.addAll(_decodePolyline(polyline));
            }
          }

          return {
            'polylinePoints': polylinePoints,
            'totalDistance': totalDistance,
            'estimatedDuration': totalDuration,
          };
        }
      } else {
        throw Exception('Error en Directions API: ${data['status']}');
      }
    }

    throw Exception('Error obteniendo ruta optimizada');
  }

  /// Decodifica polyline de Google Maps
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> polylinePoints = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      polylinePoints.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polylinePoints;
  }

  /// Calcula estadísticas de la ruta
  Map<String, dynamic> calculateRouteStatistics(DeliveryRoute route) {
    final totalOrders = route.orders.length;
    final totalValue = route.orders.fold<double>(
      0,
      (sum, order) => sum + order.totalAmount
    );

    final estimatedTimeFormatted = _formatDuration(route.estimatedDuration);
    final distanceKm = (route.totalDistance / 1000).toStringAsFixed(2);

    return {
      'totalOrders': totalOrders,
      'totalValue': totalValue,
      'estimatedTime': estimatedTimeFormatted,
      'totalDistance': '$distanceKm km',
      'averageTimePerDelivery': _formatDuration(
        route.estimatedDuration ~/ (totalOrders > 0 ? totalOrders : 1)
      ),
    };
  }

  /// Formatea duración en segundos a texto legible
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  /// Verifica si la API key está configurada
  bool isApiKeyConfigured() {
    return ApiConfig.isApiKeyConfigured;
  }
}
