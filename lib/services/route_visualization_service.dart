import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../models/delivery_route.dart';
import '../models/order.dart';
import 'directions_service.dart';

class RouteVisualizationService {
  final DirectionsService _directionsService = DirectionsService();

  // Generar marcadores para la ruta con números de secuencia
  Set<Marker> generateRouteMarkers({
    required DeliveryRoute deliveryRoute,
    required LatLng startLocation,
    required Function(Order) onOrderTap,
  }) {
    Set<Marker> markers = {};

    // Marcador de inicio (depot/almacén)
    markers.add(
      Marker(
        markerId: const MarkerId('start_location'),
        position: startLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: '🏪 Punto de Inicio',
          snippet: 'Almacén/Depot',
        ),
      ),
    );

    // Marcadores de paradas numerados
    for (int i = 0; i < deliveryRoute.orders.length; i++) {
      final order = deliveryRoute.orders[i];
      final isCompleted = order.status == OrderStatus.entregado;
      final sequenceNumber = i + 1;

      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}'),
          position: order.deliveryLocation,
          icon: _getNumberedMarkerIcon(sequenceNumber, isCompleted),
          infoWindow: InfoWindow(
            title: '${isCompleted ? '✅' : '📦'} Parada $sequenceNumber',
            snippet: '${order.clientName} - Bs. ${order.totalAmount.toStringAsFixed(2)}',
          ),
          onTap: () => onOrderTap(order),
        ),
      );
    }

    return markers;
  }

  // Generar polylines para mostrar la ruta
  Future<Set<Polyline>> generateRoutePolylines({
    required DeliveryRoute deliveryRoute,
    required LatLng startLocation,
  }) async {
    Set<Polyline> polylines = {};

    if (deliveryRoute.orders.isEmpty) return polylines;

    // Preparar waypoints para el Directions API
    List<LatLng> waypoints = [];
    LatLng destination = deliveryRoute.orders.last.deliveryLocation;

    // Agregar todas las paradas intermedias como waypoints
    for (int i = 0; i < deliveryRoute.orders.length - 1; i++) {
      waypoints.add(deliveryRoute.orders[i].deliveryLocation);
    }

    try {
      // Obtener direcciones de Google
      final directionsResult = await _directionsService.getDirections(
        origin: startLocation,
        destination: destination,
        waypoints: waypoints,
        optimizeWaypoints: false, // Ya tenemos nuestra optimización
      );

      if (directionsResult != null && directionsResult.routes.isNotEmpty) {
        final route = directionsResult.routes.first;

        // Crear polyline principal
        polylines.add(
          Polyline(
            polylineId: const PolylineId('main_route'),
            points: route.polylinePoints,
            color: Colors.blue,
            width: 5,
            patterns: [], // Línea sólida
          ),
        );

        // Crear polylines para segmentos completados (diferentes color)
        _addCompletedSegments(polylines, deliveryRoute, route);
      } else {
        // Fallback: crear líneas rectas si no hay respuesta de Directions API
        _createFallbackPolylines(polylines, deliveryRoute, startLocation);
      }
    } catch (e) {
      print('Error generating route polylines: $e');
      // Fallback en caso de error
      _createFallbackPolylines(polylines, deliveryRoute, startLocation);
    }

    return polylines;
  }

  // Crear polylines de respaldo (líneas rectas)
  void _createFallbackPolylines(
    Set<Polyline> polylines,
    DeliveryRoute deliveryRoute,
    LatLng startLocation,
  ) {
    List<LatLng> allPoints = [startLocation];

    for (final order in deliveryRoute.orders) {
      allPoints.add(order.deliveryLocation);
    }

    polylines.add(
      Polyline(
        polylineId: const PolylineId('fallback_route'),
        points: allPoints,
        color: Colors.blue.withOpacity(0.7),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)], // Línea punteada
      ),
    );
  }

  // Agregar segmentos completados con color diferente
  void _addCompletedSegments(
    Set<Polyline> polylines,
    DeliveryRoute deliveryRoute,
    RouteDirection route,
  ) {
    int completedOrders = deliveryRoute.completedOrders;

    if (completedOrders > 0 && route.legs.isNotEmpty) {
      List<LatLng> completedPoints = [];

      // Agregar puntos de los legs completados
      for (int i = 0; i < completedOrders && i < route.legs.length; i++) {
        final leg = route.legs[i];
        completedPoints.addAll(
          leg.steps.expand((step) => step.polylinePoints).toList(),
        );
      }

      if (completedPoints.isNotEmpty) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('completed_route'),
            points: completedPoints,
            color: Colors.green,
            width: 6,
            patterns: [],
          ),
        );
      }
    }
  }

  // Generar información de la ruta para mostrar en UI
  RouteInfo generateRouteInfo(DeliveryRoute deliveryRoute) {
    double totalDistance = deliveryRoute.totalDistance;
    int totalDuration = deliveryRoute.estimatedDuration;
    int completedOrders = deliveryRoute.completedOrders;
    int totalOrders = deliveryRoute.totalOrders;

    String estimatedArrival = _calculateEstimatedArrival(deliveryRoute);
    double progress = deliveryRoute.progress;

    return RouteInfo(
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      completedStops: completedOrders,
      totalStops: totalOrders,
      estimatedArrival: estimatedArrival,
      progress: progress,
      remainingTime: _calculateRemainingTime(deliveryRoute),
    );
  }

  // Crear íconos numerados para los marcadores
  BitmapDescriptor _getNumberedMarkerIcon(int number, bool isCompleted) {
    // Por ahora usamos colores diferentes, luego se puede personalizar con íconos custom
    if (isCompleted) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }

  String _calculateEstimatedArrival(DeliveryRoute deliveryRoute) {
    if (deliveryRoute.orders.isEmpty) return 'N/A';

    // Calcular tiempo estimado basado en la hora de creación de la ruta y duración estimada
    final estimatedCompletion = deliveryRoute.createdAt.add(
      Duration(seconds: deliveryRoute.estimatedDuration)
    );

    return '${estimatedCompletion.hour.toString().padLeft(2, '0')}:${estimatedCompletion.minute.toString().padLeft(2, '0')}';
  }

  String _calculateRemainingTime(DeliveryRoute deliveryRoute) {
    final now = DateTime.now();
    final estimatedCompletion = deliveryRoute.createdAt.add(
      Duration(seconds: deliveryRoute.estimatedDuration)
    );

    final remainingTime = estimatedCompletion.difference(now);

    if (remainingTime.isNegative) return 'Completado';

    final hours = remainingTime.inHours;
    final minutes = remainingTime.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  // Animar la cámara para mostrar toda la ruta
  Future<void> animateCameraToShowRoute({
    required GoogleMapController mapController,
    required DeliveryRoute deliveryRoute,
    required LatLng startLocation,
  }) async {
    if (deliveryRoute.orders.isEmpty) return;

    List<LatLng> allPoints = [startLocation];
    for (final order in deliveryRoute.orders) {
      allPoints.add(order.deliveryLocation);
    }

    // Calcular bounds
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final point in allPoints) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    // Agregar padding
    const double padding = 0.005;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    await mapController.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }
}

class RouteInfo {
  final double totalDistance;
  final int totalDuration;
  final int completedStops;
  final int totalStops;
  final String estimatedArrival;
  final double progress;
  final String remainingTime;

  RouteInfo({
    required this.totalDistance,
    required this.totalDuration,
    required this.completedStops,
    required this.totalStops,
    required this.estimatedArrival,
    required this.progress,
    required this.remainingTime,
  });
}
