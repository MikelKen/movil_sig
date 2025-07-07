import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/delivery_route.dart';
import '../models/order.dart';

class MapsService {
  static const String _googleMapsApiKey = 'AIzaSyDbpv3i7Tno3aicF4_1GnUUHGQLFo1GOLY'; // Reemplaza con tu API key
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  // Obtener ruta detallada usando Google Directions API
  static Future<List<LatLng>> getRoutePolyline(
    LatLng origin,
    LatLng destination, {
    List<LatLng> waypoints = const [],
  }) async {
    try {
      final String waypointsString = waypoints.isEmpty
          ? ''
          : '&waypoints=${waypoints.map((point) => '${point.latitude},${point.longitude}').join('|')}';

      final String url = '$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '$waypointsString'
          '&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final String polylineString = data['routes'][0]['overview_polyline']['points'];
          final PolylinePoints polylinePoints = PolylinePoints();
          final List<PointLatLng> points = polylinePoints.decodePolyline(polylineString);

          return points.map((point) => LatLng(point.latitude, point.longitude)).toList();
        }
      }

      // Si la API falla, devolver una línea recta
      return _createStraightLine(origin, destination, waypoints);
    } catch (e) {
      print('Error obteniendo ruta: $e');
      return _createStraightLine(origin, destination, waypoints);
    }
  }

  // Crear una línea recta como fallback
  static List<LatLng> _createStraightLine(
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
  ) {
    final List<LatLng> points = [origin];
    points.addAll(waypoints);
    points.add(destination);
    return points;
  }

  // Generar markers para la ruta de entrega
  static Set<Marker> generateRouteMarkers(
    DeliveryRoute route,
    LatLng startLocation, {
    Function(String)? onMarkerTap,
  }) {
    final Set<Marker> markers = {};

    // Marker de inicio
    markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: startLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(
          title: 'Punto de Inicio',
          snippet: 'Almacén/Depósito',
        ),
      ),
    );

    // Markers para cada parada
    for (int i = 0; i < route.orders.length; i++) {
      final order = route.orders[i];
      final hue = order.status == OrderStatus.entregado
          ? BitmapDescriptor.hueBlue
          : BitmapDescriptor.hueRed;

      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}'),
          position: order.deliveryLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${order.clientName}',
            snippet: '${order.address}\nTotal: Bs. ${order.totalAmount.toStringAsFixed(2)}',
          ),
          onTap: () => onMarkerTap?.call(order.id),
        ),
      );
    }

    return markers;
  }

  // Generar polyline para la ruta completa
  static Future<Set<Polyline>> generateRoutePolylines(
    DeliveryRoute route,
    LatLng startLocation,
  ) async {
    final Set<Polyline> polylines = {};

    if (route.orders.isEmpty) return polylines;

    LatLng currentLocation = startLocation;

    for (int i = 0; i < route.orders.length; i++) {
      final order = route.orders[i];
      final destination = order.deliveryLocation;

      try {
        final List<LatLng> routePoints = await getRoutePolyline(
          currentLocation,
          destination,
        );

        if (routePoints.isNotEmpty) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('route_segment_$i'),
              points: routePoints,
              color: order.status == OrderStatus.entregado
                  ? Colors.green // Verde para completados
                  : Colors.blue, // Azul para pendientes
              width: 4,
              patterns: order.status == OrderStatus.entregado
                  ? []
                  : [PatternItem.dash(10), PatternItem.gap(5)],
            ),
          );
        }

        currentLocation = destination;
      } catch (e) {
        print('Error generando segmento de ruta $i: $e');
        // Crear línea recta como fallback
        polylines.add(
          Polyline(
            polylineId: PolylineId('route_segment_$i'),
            points: [currentLocation, destination],
            color: order.status == OrderStatus.entregado
                ? Colors.green
                : Colors.blue,
            width: 4,
            patterns: order.status == OrderStatus.entregado
                ? []
                : [PatternItem.dash(10), PatternItem.gap(5)],
          ),
        );
        currentLocation = destination;
      }
    }

    return polylines;
  }

  // Calcular los límites de la cámara para mostrar toda la ruta
  static CameraUpdate getBoundsForRoute(
    DeliveryRoute route,
    LatLng startLocation,
  ) {
    final List<LatLng> allPoints = [startLocation];
    allPoints.addAll(route.orders.map((order) => order.deliveryLocation));

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
    const double padding = 0.001;
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    return CameraUpdate.newLatLngBounds(bounds, 100.0);
  }

  // Estimar tiempo de llegada actualizado
  static Future<Duration?> getEstimatedDuration(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final String url = '$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&departure_time=now'
          '&traffic_model=best_guess'
          '&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final int durationInSeconds = data['routes'][0]['legs'][0]['duration']['value'];
          return Duration(seconds: durationInSeconds);
        }
      }
    } catch (e) {
      print('Error obteniendo duración: $e');
    }

    return null;
  }
}
