// models/enhanced_route_models.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'delivery_route.dart';
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

  // Helper para conversión segura de tipos
  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
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
        'createdAt': order.createdAt.toIso8601String(),
        'observations': order.observations,
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
    final orderData = json['order'] as Map<String, dynamic>;
    return RouteStopInfo(
      sequence: _safeParseInt(json['sequence']),
      order: Order(
        id: orderData['id']?.toString() ?? '',
        clientName: orderData['clientName']?.toString() ?? '',
        clientPhone: orderData['clientPhone']?.toString() ?? '',
        deliveryLocation: LatLng(
          _safeParseDouble(orderData['deliveryLocation']['latitude']),
          _safeParseDouble(orderData['deliveryLocation']['longitude']),
        ),
        address: orderData['address']?.toString() ?? '',
        items: (orderData['items'] as List? ?? []).map((item) => OrderItem(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          quantity: _safeParseInt(item['quantity']),
          price: _safeParseDouble(item['price']),
        )).toList(),
        status: OrderStatus.values[_safeParseInt(orderData['status'])],
        createdAt: DateTime.tryParse(orderData['createdAt']?.toString() ?? '') ?? DateTime.now(),
        observations: orderData['observations']?.toString() ?? '',
        totalAmount: _safeParseDouble(orderData['totalAmount']),
      ),
      distanceFromStart: _safeParseDouble(json['distanceFromStart']),
      distanceFromPrevious: _safeParseDouble(json['distanceFromPrevious']),
      cumulativeTime: _safeParseInt(json['cumulativeTime']),
      timeFromPrevious: _safeParseInt(json['timeFromPrevious']),
      estimatedArrival: DateTime.tryParse(json['estimatedArrival']?.toString() ?? '') ?? DateTime.now(),
      location: LatLng(
        _safeParseDouble(json['location']['latitude']),
        _safeParseDouble(json['location']['longitude']),
      ),
    );
  }
}

// Ruta de entrega mejorada que extiende DeliveryRoute
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

  // Helper para conversión segura de tipos
  static int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _safeParseDateTime(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback ?? DateTime.now();

    // Si es un timestamp en milisegundos
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    // Si es un string ISO8601
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }

    return fallback ?? DateTime.now();
  }

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
    try {
      print('🔍 Deserializando EnhancedDeliveryRoute: ${json.keys}');

      return EnhancedDeliveryRoute(
        id: json['id']?.toString() ?? '',
        orders: (json['orders'] as List? ?? []).map((o) => Order(
          id: o['id']?.toString() ?? '',
          clientName: o['clientName']?.toString() ?? '',
          clientPhone: o['clientPhone']?.toString() ?? '',
          deliveryLocation: LatLng(
            _safeParseDouble(o['deliveryLocation']['latitude']),
            _safeParseDouble(o['deliveryLocation']['longitude']),
          ),
          address: o['address']?.toString() ?? '',
          items: (o['items'] as List? ?? []).map((item) => OrderItem(
            id: item['id']?.toString() ?? '',
            name: item['name']?.toString() ?? '',
            quantity: _safeParseInt(item['quantity']),
            price: _safeParseDouble(item['price']),
          )).toList(),
          status: OrderStatus.values[_safeParseInt(o['status'])],
          createdAt: _safeParseDateTime(o['createdAt']),
          deliveryTime: o['deliveryTime'] != null
              ? _safeParseDateTime(o['deliveryTime'])
              : null,
          observations: o['observations']?.toString() ?? '',
          totalAmount: _safeParseDouble(o['totalAmount']),
        )).toList(),
        stopInfos: (json['stopInfos'] as List? ?? [])
            .map((stop) => RouteStopInfo.fromJson(stop))
            .toList(),
        polylinePoints: (json['polylinePoints'] as List? ?? []).map((p) =>
            LatLng(
                _safeParseDouble(p['latitude']),
                _safeParseDouble(p['longitude'])
            )
        ).toList(),
        startLocation: LatLng(
          _safeParseDouble(json['startLocation']['latitude']),
          _safeParseDouble(json['startLocation']['longitude']),
        ),
        endLocation: json['endLocation'] != null ? LatLng(
            _safeParseDouble(json['endLocation']['latitude']),
            _safeParseDouble(json['endLocation']['longitude'])
        ) : null,
        createdAt: _safeParseDateTime(json['createdAt']),
        startTime: json['startTime'] != null
            ? _safeParseDateTime(json['startTime'])
            : null,
        endTime: json['endTime'] != null
            ? _safeParseDateTime(json['endTime'])
            : null,
        totalDistance: _safeParseDouble(json['totalDistance']),
        estimatedDuration: _safeParseInt(json['estimatedDuration']),
        optimizationMethod: json['optimizationMethod']?.toString() ?? 'Enhanced',
        isOptimized: json['isOptimized'] == true,
        plannedStartTime: json['plannedStartTime'] != null
            ? _safeParseDateTime(json['plannedStartTime'])
            : _safeParseDateTime(json['createdAt']),
      );
    } catch (e) {
      print('❌ Error deserializando EnhancedDeliveryRoute: $e');
      print('📄 JSON problemático: $json');
      rethrow;
    }
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