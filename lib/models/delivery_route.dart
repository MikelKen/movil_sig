import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'order.dart';

class DeliveryRoute {
  final String id;
  final List<Order> orders; // Cambio: usar directamente órdenes en lugar de stops
  final List<LatLng> polylinePoints; // NUEVO: puntos de la ruta para visualización
  final LatLng startLocation;
  final LatLng? endLocation; // NUEVO: ubicación final opcional
  final DateTime createdAt; // Cambio: momento de creación
  final DateTime? startTime; // NUEVO: momento de inicio real
  final DateTime? endTime;
  final double totalDistance; // en metros (cambio: más preciso)
  final int estimatedDuration; // en segundos (cambio: más preciso)
  final String optimizationMethod; // NUEVO: método de optimización usado
  final bool isOptimized;

  DeliveryRoute({
    required this.id,
    required this.orders,
    this.polylinePoints = const [],
    required this.startLocation,
    this.endLocation,
    required this.createdAt,
    this.startTime,
    this.endTime,
    required this.totalDistance,
    required this.estimatedDuration,
    this.optimizationMethod = 'Manual',
    this.isOptimized = false,
  });

  DeliveryRoute copyWith({
    List<Order>? orders,
    List<LatLng>? polylinePoints,
    LatLng? endLocation,
    DateTime? startTime,
    DateTime? endTime,
    double? totalDistance,
    int? estimatedDuration,
    String? optimizationMethod,
    bool? isOptimized,
  }) {
    return DeliveryRoute(
      id: id,
      orders: orders ?? this.orders,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      startLocation: startLocation,
      endLocation: endLocation ?? this.endLocation,
      createdAt: createdAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalDistance: totalDistance ?? this.totalDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      optimizationMethod: optimizationMethod ?? this.optimizationMethod,
      isOptimized: isOptimized ?? this.isOptimized,
    );
  }

  // Getters útiles
  int get completedOrders => orders.where((order) => order.status == OrderStatus.entregado).length;
  int get totalOrders => orders.length;
  double get progress => totalOrders > 0 ? completedOrders / totalOrders : 0.0;

  double get totalDistanceKm => totalDistance / 1000;
  String get formattedDistance => '${totalDistanceKm.toStringAsFixed(2)} km';

  String get formattedDuration {
    final hours = estimatedDuration ~/ 3600;
    final minutes = (estimatedDuration % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  double get totalValue => orders.fold<double>(0, (sum, order) => sum + order.totalAmount);

  bool get isActive => startTime != null && endTime == null;
  bool get isCompleted => endTime != null;

  List<LatLng> get deliveryLocations => orders.map((order) => order.deliveryLocation).toList();

  // Métodos para serialización (si necesitas guardar en storage)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orders': orders.map((o) => {
        'id': o.id,
        'clientName': o.clientName,
        'clientPhone': o.clientPhone,
        'address': o.address,
        'deliveryLocation': {
          'latitude': o.deliveryLocation.latitude,
          'longitude': o.deliveryLocation.longitude,
        },
        'totalAmount': o.totalAmount,
        'status': o.status.index,
        'createdAt': o.createdAt.toIso8601String(),
        'items': o.items.map((item) => {
          'id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
        }).toList(),
      }).toList(),
      'polylinePoints': polylinePoints.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
      }).toList(),
      'startLocation': {
        'latitude': startLocation.latitude,
        'longitude': startLocation.longitude,
      },
      'endLocation': endLocation != null ? {
        'latitude': endLocation!.latitude,
        'longitude': endLocation!.longitude,
      } : null,
      'createdAt': createdAt.toIso8601String(),
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'totalDistance': totalDistance,
      'estimatedDuration': estimatedDuration,
      'optimizationMethod': optimizationMethod,
      'isOptimized': isOptimized,
    };
  }

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    return DeliveryRoute(
      id: json['id'],
      orders: (json['orders'] as List).map((o) => Order.fromJson(o)).toList(),
      polylinePoints: (json['polylinePoints'] as List?)?.map((p) =>
        LatLng(p['latitude'], p['longitude'])
      ).toList() ?? [],
      startLocation: LatLng(
        json['startLocation']['latitude'],
        json['startLocation']['longitude']
      ),
      endLocation: json['endLocation'] != null ? LatLng(
        json['endLocation']['latitude'],
        json['endLocation']['longitude']
      ) : null,
      createdAt: DateTime.parse(json['createdAt']),
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      totalDistance: json['totalDistance'].toDouble(),
      estimatedDuration: json['estimatedDuration'],
      optimizationMethod: json['optimizationMethod'] ?? 'Manual',
      isOptimized: json['isOptimized'] ?? false,
    );
  }
}

// Mantener RouteStop para compatibilidad (pero deprecated)
@deprecated
class RouteStop {
  final String id;
  final Order order;
  final int sequenceNumber;
  final DateTime estimatedArrival;
  final DateTime? actualArrival;
  final bool isCompleted;

  RouteStop({
    required this.id,
    required this.order,
    required this.sequenceNumber,
    required this.estimatedArrival,
    this.actualArrival,
    this.isCompleted = false,
  });

  RouteStop copyWith({
    DateTime? actualArrival,
    bool? isCompleted,
  }) {
    return RouteStop(
      id: id,
      order: order,
      sequenceNumber: sequenceNumber,
      estimatedArrival: estimatedArrival,
      actualArrival: actualArrival ?? this.actualArrival,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
