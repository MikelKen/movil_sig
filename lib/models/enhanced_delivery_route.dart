// enhanced_delivery_route.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sig/models/delivery_route.dart';
import 'order.dart';

// Información detallada de cada parada en la ruta
class RouteStopInfo {
  final int sequence;
  final Order order;
  final double distanceFromStart; // Distancia total desde el inicio (metros)
  final double distanceFromPrevious; // Distancia desde la parada anterior (metros)
  final int cumulativeTime; // Tiempo total desde el inicio (segundos)
  final int timeFromPrevious; // Tiempo desde la parada anterior (segundos)
  final DateTime estimatedArrival;
  final LatLng location;

  RouteStopInfo({
    required this.sequence,
    required this.order,
    required this.distanceFromStart,
    required this.distanceFromPrevious,
    required this.cumulativeTime,
    required this.timeFromPrevious,
    required this.estimatedArrival,
    required this.location,
  });

  // Getters para formato legible
  String get formattedDistanceFromStart =>
      '${(distanceFromStart / 1000).toStringAsFixed(1)} km';

  String get formattedDistanceFromPrevious =>
      '${(distanceFromPrevious / 1000).toStringAsFixed(1)} km';

  String get formattedTimeFromStart => _formatDuration(cumulativeTime);

  String get formattedTimeFromPrevious => _formatDuration(timeFromPrevious);

  String get formattedEstimatedArrival =>
      '${estimatedArrival.hour.toString().padLeft(2, '0')}:${estimatedArrival.minute.toString().padLeft(2, '0')}';

  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    } else {
      return '${minutes}min';
    }
  }

  // Serialización
  Map<String, dynamic> toJson() {
    return {
      'sequence': sequence,
      'order': {
        'id': order.id,
        'clientName': order.clientName,
        'clientPhone': order.clientPhone,
        'address': order.address,
        'deliveryLocation': {
          'latitude': order.deliveryLocation.latitude,
          'longitude': order.deliveryLocation.longitude,
        },
        'totalAmount': order.totalAmount,
        'status': order.status.index,
        'items': order.items.map((item) => {
          'id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
        }).toList(),
      },
      'distanceFromStart': distanceFromStart,
      'distanceFromPrevious': distanceFromPrevious,
      'cumulativeTime': cumulativeTime,
      'timeFromPrevious': timeFromPrevious,
      'estimatedArrival': estimatedArrival.toIso8601String(),
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
    };
  }

  factory RouteStopInfo.fromJson(Map<String, dynamic> json) {
    return RouteStopInfo(
      sequence: json['sequence'],
      order: Order.fromJson(json['order']),
      distanceFromStart: json['distanceFromStart'].toDouble(),
      distanceFromPrevious: json['distanceFromPrevious'].toDouble(),
      cumulativeTime: json['cumulativeTime'],
      timeFromPrevious: json['timeFromPrevious'],
      estimatedArrival: DateTime.parse(json['estimatedArrival']),
      location: LatLng(
        json['location']['latitude'],
        json['location']['longitude'],
      ),
    );
  }
}

// Ruta de entrega mejorada con información detallada
class EnhancedDeliveryRoute extends DeliveryRoute {
  final List<RouteStopInfo> stopInfos;
  final DateTime plannedStartTime;

  EnhancedDeliveryRoute({
    required super.id,
    required super.orders,
    required this.stopInfos,
    super.polylinePoints = const [],
    required super.startLocation,
    super.endLocation,
    required super.createdAt,
    super.startTime,
    super.endTime,
    required super.totalDistance,
    required super.estimatedDuration,
    super.optimizationMethod = 'Enhanced',
    super.isOptimized = false,
    required this.plannedStartTime,
  });

  // Getters adicionales para la ruta mejorada
  DateTime get estimatedEndTime {
    if (stopInfos.isNotEmpty) {
      // Última llegada + 5 minutos de tiempo de servicio
      return stopInfos.last.estimatedArrival.add(const Duration(minutes: 5));
    }
    return plannedStartTime.add(Duration(seconds: estimatedDuration));
  }

  String get formattedPlannedStartTime =>
      '${plannedStartTime.hour.toString().padLeft(2, '0')}:${plannedStartTime.minute.toString().padLeft(2, '0')}';

  String get formattedEstimatedEndTime =>
      '${estimatedEndTime.hour.toString().padLeft(2, '0')}:${estimatedEndTime.minute.toString().padLeft(2, '0')}';

  double get totalServiceTime => stopInfos.length * 5.0; // 5 minutos por parada

  String get formattedTotalServiceTime {
    final minutes = totalServiceTime.toInt();
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
    return '${minutes}min';
  }

  // Obtener parada por índice
  RouteStopInfo? getStopInfo(int sequence) {
    try {
      return stopInfos.firstWhere((stop) => stop.sequence == sequence);
    } catch (e) {
      return null;
    }
  }

  // Obtener siguiente parada
  RouteStopInfo? getNextStop(int currentSequence) {
    final nextSequence = currentSequence + 1;
    return getStopInfo(nextSequence);
  }

  // Obtener parada anterior
  RouteStopInfo? getPreviousStop(int currentSequence) {
    final prevSequence = currentSequence - 1;
    if (prevSequence >= 1) {
      return getStopInfo(prevSequence);
    }
    return null;
  }

  // Estadísticas de la ruta
  Map<String, dynamic> get routeStatistics {
    final totalValue = orders.fold<double>(0, (sum, order) => sum + order.totalAmount);
    final avgTimePerStop = stopInfos.isNotEmpty
        ? (estimatedDuration / stopInfos.length / 60).round()
        : 0;

    return {
      'totalStops': stopInfos.length,
      'totalValue': totalValue,
      'averageValuePerStop': stopInfos.isNotEmpty ? totalValue / stopInfos.length : 0,
      'totalDistanceKm': totalDistance / 1000,
      'averageDistancePerStop': stopInfos.isNotEmpty ? (totalDistance / 1000) / stopInfos.length : 0,
      'estimatedDurationMinutes': estimatedDuration / 60,
      'averageTimePerStopMinutes': avgTimePerStop,
      'totalServiceTimeMinutes': totalServiceTime,
      'plannedStartTime': formattedPlannedStartTime,
      'estimatedEndTime': formattedEstimatedEndTime,
    };
  }

  @override
  Map<String, dynamic> toJson() {
    final baseJson = super.toJson();
    baseJson.addAll({
      'stopInfos': stopInfos.map((stop) => stop.toJson()).toList(),
      'plannedStartTime': plannedStartTime.toIso8601String(),
      'routeType': 'enhanced',
    });
    return baseJson;
  }

  factory EnhancedDeliveryRoute.fromJson(Map<String, dynamic> json) {
    final base = DeliveryRoute.fromJson(json);

    return EnhancedDeliveryRoute(
      id: base.id,
      orders: base.orders,
      stopInfos: (json['stopInfos'] as List?)
          ?.map((stop) => RouteStopInfo.fromJson(stop))
          .toList() ?? [],
      polylinePoints: base.polylinePoints,
      startLocation: base.startLocation,
      endLocation: base.endLocation,
      createdAt: base.createdAt,
      startTime: base.startTime,
      endTime: base.endTime,
      totalDistance: base.totalDistance,
      estimatedDuration: base.estimatedDuration,
      optimizationMethod: base.optimizationMethod,
      isOptimized: base.isOptimized,
      plannedStartTime: json['plannedStartTime'] != null
          ? DateTime.parse(json['plannedStartTime'])
          : base.createdAt,
    );
  }

  @override
  EnhancedDeliveryRoute copyWith({
    List<Order>? orders,
    List<LatLng>? polylinePoints,
    LatLng? endLocation,
    DateTime? startTime,
    DateTime? endTime,
    double? totalDistance,
    int? estimatedDuration,
    String? optimizationMethod,
    bool? isOptimized,
    List<RouteStopInfo>? stopInfos,
    DateTime? plannedStartTime,
  }) {
    return EnhancedDeliveryRoute(
      id: id,
      orders: orders ?? this.orders,
      stopInfos: stopInfos ?? this.stopInfos,
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
      plannedStartTime: plannedStartTime ?? this.plannedStartTime,
    );
  }
}