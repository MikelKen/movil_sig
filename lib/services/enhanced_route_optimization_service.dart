// services/enhanced_route_optimization_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/enhanced_route_models.dart'; // Importar desde el archivo separado
import '../models/order.dart';
import '../config/api_config.dart';

class EnhancedRouteOptimizationService {
  static const String _directionsBaseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _distanceMatrixBaseUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';

  // Configuración para delivery service
  static const int _serviceTimePerStop = 300; // 5 minutos por entrega en segundos
  static const double _averageSpeed = 30.0; // 30 km/h velocidad promedio en ciudad

  /// Optimiza una ruta de entregas con información detallada de cada parada
  Future<EnhancedDeliveryRoute> optimizeDeliveryRouteEnhanced({
    required LatLng startLocation,
    required List<Order> orders,
    LatLng? endLocation,
    DateTime? startTime,
  }) async {
    if (orders.isEmpty) {
      throw Exception('No hay órdenes para optimizar');
    }

    if (!ApiConfig.isApiKeyConfigured) {
      throw Exception('API Key de Google Maps no configurada');
    }

    final actualStartTime = startTime ?? DateTime.now();

    try {
      print('🚀 Iniciando optimización avanzada de ruta...');

      // 1. Obtener matriz de distancias y tiempos
      final routeMatrix = await _getEnhancedDistanceMatrix(
        startLocation,
        orders.map((o) => o.deliveryLocation).toList(),
        endLocation,
      );

      print('📊 Matriz de distancias obtenida');

      // 2. Aplicar algoritmo de optimización mejorado
      final optimizedIndices = _nearestNeighborTSPEnhanced(routeMatrix);

      // 3. Reorganizar órdenes según la optimización
      final optimizedOrders = optimizedIndices
          .map((index) => orders[index])
          .toList();

      print('🎯 Orden optimizado calculado: ${optimizedIndices.length} paradas');

      // 4. Obtener ruta detallada con Google Directions API
      final routeDetails = await _getDetailedRoute(
        startLocation,
        optimizedOrders.map((o) => o.deliveryLocation).toList(),
        endLocation,
      );

      // 5. Calcular información detallada de cada parada
      final stopInfos = _calculateStopInfos(
        startLocation,
        optimizedOrders,
        routeDetails,
        actualStartTime,
      );

      print('✅ Ruta optimizada generada con ${stopInfos.length} paradas');

      // 6. Crear objeto EnhancedDeliveryRoute
      return EnhancedDeliveryRoute(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orders: optimizedOrders,
        stopInfos: stopInfos,
        polylinePoints: routeDetails['polylinePoints'] ?? [],
        totalDistance: routeDetails['totalDistance'] ?? 0.0,
        estimatedDuration: routeDetails['estimatedDuration'] ?? 0,
        startLocation: startLocation,
        endLocation: endLocation,
        optimizationMethod: 'Enhanced Nearest Neighbor TSP',
        createdAt: DateTime.now(),
        plannedStartTime: actualStartTime,
        isOptimized: true,
      );
    } catch (e) {
      print('❌ Error en optimización: $e');
      throw Exception('Error optimizando ruta: $e');
    }
  }

  /// Obtiene matriz de distancias y tiempos mejorada
  Future<Map<String, dynamic>> _getEnhancedDistanceMatrix(
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
        'traffic_model=best_guess&'
        'departure_time=now&'
        'key=${ApiConfig.getApiKey()}');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final rows = data['rows'] as List;
        final distanceMatrix = <List<double>>[];
        final timeMatrix = <List<int>>[];

        for (int i = 0; i < rows.length; i++) {
          final distanceRow = <double>[];
          final timeRow = <int>[];
          final elements = rows[i]['elements'] as List;

          for (int j = 0; j < elements.length; j++) {
            final element = elements[j];
            if (element['status'] == 'OK') {
              distanceRow.add((element['distance']['value'] as int).toDouble());
              timeRow.add(element['duration']['value'] as int);
            } else {
              // Usar distancia euclidiana como fallback
              final distance = _calculateEuclideanDistance(allPoints[i], allPoints[j]);
              distanceRow.add(distance);
              timeRow.add((distance / 1000 / _averageSpeed * 3600).round());
            }
          }
          distanceMatrix.add(distanceRow);
          timeMatrix.add(timeRow);
        }

        return {
          'distances': distanceMatrix,
          'times': timeMatrix,
          'points': allPoints,
        };
      } else {
        throw Exception('Error en Distance Matrix API: ${data['status']}');
      }
    } else {
      throw Exception('Error HTTP: ${response.statusCode}');
    }
  }

  /// Algoritmo TSP mejorado que considera tanto distancia como tiempo
  List<int> _nearestNeighborTSPEnhanced(Map<String, dynamic> routeMatrix) {
    final distanceMatrix = routeMatrix['distances'] as List<List<double>>;
    final timeMatrix = routeMatrix['times'] as List<List<int>>;

    final n = distanceMatrix.length - 1; // Excluir punto de inicio
    final visited = List<bool>.filled(n + 1, false);
    final route = <int>[];

    int currentCity = 0; // Empezar desde el punto de inicio
    visited[currentCity] = true;

    for (int i = 0; i < n; i++) {
      double bestScore = double.infinity;
      int nextCity = -1;

      // Encontrar la siguiente ciudad con mejor puntuación (distancia + tiempo)
      for (int j = 1; j <= n; j++) {
        if (!visited[j]) {
          // Combinar distancia y tiempo en una puntuación
          final distance = distanceMatrix[currentCity][j];
          final time = timeMatrix[currentCity][j];

          // Normalizar y combinar (70% distancia, 30% tiempo)
          final score = (distance * 0.7) + (time * 100 * 0.3);

          if (score < bestScore) {
            bestScore = score;
            nextCity = j;
          }
        }
      }

      if (nextCity != -1) {
        visited[nextCity] = true;
        route.add(nextCity - 1); // Ajustar índice para órdenes
        currentCity = nextCity;
      }
    }

    return route;
  }

  /// Obtiene ruta detallada con waypoints y direcciones paso a paso
  Future<Map<String, dynamic>> _getDetailedRoute(
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

    final destination = end ?? start;

    final url = Uri.parse('$_directionsBaseUrl?'
        'origin=${start.latitude},${start.longitude}&'
        'destination=${destination.latitude},${destination.longitude}&'
        '${waypointsStr.isNotEmpty ? 'waypoints=$waypointsStr&' : ''}'
        'mode=driving&'
        'units=metric&'
        'traffic_model=best_guess&'
        'departure_time=now&'
        'key=${ApiConfig.getApiKey()}');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final route = routes[0];
          final legs = route['legs'] as List;

          double totalDistance = 0;
          int totalDuration = 0;
          final List<LatLng> polylinePoints = [];
          final List<Map<String, dynamic>> legDetails = [];

          for (int i = 0; i < legs.length; i++) {
            final leg = legs[i];
            final legDistance = (leg['distance']['value'] as int).toDouble();
            final legDuration = leg['duration']['value'] as int;

            totalDistance += legDistance;
            totalDuration += legDuration;

            legDetails.add({
              'distance': legDistance,
              'duration': legDuration,
              'startAddress': leg['start_address'],
              'endAddress': leg['end_address'],
            });

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
            'legDetails': legDetails,
          };
        }
      } else {
        throw Exception('Error en Directions API: ${data['status']}');
      }
    }

    throw Exception('Error obteniendo ruta detallada');
  }

  /// Calcula información detallada de cada parada
  List<RouteStopInfo> _calculateStopInfos(
      LatLng startLocation,
      List<Order> optimizedOrders,
      Map<String, dynamic> routeDetails,
      DateTime startTime,
      ) {
    final stopInfos = <RouteStopInfo>[];
    final legDetails = routeDetails['legDetails'] as List<Map<String, dynamic>>;

    double cumulativeDistance = 0;
    int cumulativeTime = 0;
    DateTime currentTime = startTime;

    for (int i = 0; i < optimizedOrders.length; i++) {
      final order = optimizedOrders[i];

      // Obtener detalles del tramo actual
      final legDetail = i < legDetails.length ? legDetails[i] : {
        'distance': 0.0,
        'duration': 0,
      };

      final segmentDistance = legDetail['distance'] as double;
      final segmentTime = legDetail['duration'] as int;

      // Añadir tiempo de servicio de la parada anterior
      if (i > 0) {
        cumulativeTime += _serviceTimePerStop;
        currentTime = currentTime.add(Duration(seconds: _serviceTimePerStop));
      }

      // Añadir tiempo de viaje al punto actual
      cumulativeTime += segmentTime;
      cumulativeDistance += segmentDistance;
      currentTime = currentTime.add(Duration(seconds: segmentTime));

      final stopInfo = RouteStopInfo(
        sequence: i + 1,
        order: order,
        distanceFromStart: cumulativeDistance,
        distanceFromPrevious: segmentDistance,
        cumulativeTime: cumulativeTime,
        timeFromPrevious: segmentTime + (i > 0 ? _serviceTimePerStop : 0),
        estimatedArrival: currentTime,
        location: order.deliveryLocation,
      );

      stopInfos.add(stopInfo);
    }

    return stopInfos;
  }

  /// Calcula distancia euclidiana aproximada entre dos puntos
  double _calculateEuclideanDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000;

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

  /// Calcula estadísticas de la ruta mejoradas
  Map<String, dynamic> calculateEnhancedRouteStatistics(EnhancedDeliveryRoute route) {
    final totalOrders = route.orders.length;
    final totalValue = route.orders.fold<double>(0, (sum, order) => sum + order.totalAmount);

    final estimatedTimeFormatted = _formatDuration(route.estimatedDuration);
    final distanceKm = (route.totalDistance / 1000).toStringAsFixed(2);

    // Calcular tiempo promedio entre paradas
    int totalTravelTime = 0;
    for (final stop in route.stopInfos) {
      totalTravelTime += stop.timeFromPrevious;
    }

    final averageTimePerStop = totalOrders > 0 ? totalTravelTime ~/ totalOrders : 0;

    return {
      'totalOrders': totalOrders,
      'totalValue': totalValue,
      'estimatedTime': estimatedTimeFormatted,
      'totalDistance': '$distanceKm km',
      'averageTimePerDelivery': _formatDuration(averageTimePerStop),
      'totalServiceTime': _formatDuration(_serviceTimePerStop * totalOrders),
      'estimatedEndTime': route.estimatedEndTime,
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