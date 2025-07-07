import '../models/order.dart';
import '../models/delivery_route.dart';
import 'route_optimization_service.dart';
import 'storage_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryService {
  static const String _ordersKey = 'orders';
  static const String _routesKey = 'delivery_routes';

  late StorageService _storage;

  DeliveryService() {
    _initStorage();
  }

  Future<void> _initStorage() async {
    _storage = await StorageService.getInstance();
  }

  // Obtener todos los pedidos
  Future<List<Order>> getOrders() async {
    try {
      await _initStorage();
      final data = await _storage.getData(_ordersKey);
      if (data == null) {
        // Si no hay datos guardados, usar datos simulados
        final sampleOrders = _getSampleOrders();
        await saveOrders(sampleOrders);
        return sampleOrders;
      }

      return (data as List).map((json) => _orderFromJson(json)).toList();
    } catch (e) {
      // En caso de error, retornar datos simulados
      return _getSampleOrders();
    }
  }

  // Guardar pedidos
  Future<void> saveOrders(List<Order> orders) async {
    await _initStorage();
    final data = orders.map((order) => _orderToJson(order)).toList();
    await _storage.saveData(_ordersKey, data);
  }

  // Obtener pedidos pendientes
  Future<List<Order>> getPendingOrders() async {
    final orders = await getOrders();
    return orders.where((order) =>
      order.status == OrderStatus.pendiente ||
      order.status == OrderStatus.enRuta
    ).toList();
  }

  // Actualizar estado de un pedido
  Future<Order> updateOrderStatus(
    String orderId,
    OrderStatus newStatus, {
    PaymentMethod? paymentMethod,
    String? observations,
  }) async {
    final orders = await getOrders();
    final orderIndex = orders.indexWhere((order) => order.id == orderId);

    if (orderIndex == -1) {
      throw ArgumentError('Pedido no encontrado: $orderId');
    }

    final updatedOrder = orders[orderIndex].copyWith(
      status: newStatus,
      paymentMethod: paymentMethod,
      deliveryTime: newStatus == OrderStatus.entregado ? DateTime.now() : null,
      observations: observations,
    );

    orders[orderIndex] = updatedOrder;
    await saveOrders(orders);

    return updatedOrder;
  }

  // Registrar entrega
  Future<Order> registerDelivery(
    String orderId,
    PaymentMethod paymentMethod, {
    String? observations,
  }) async {
    return await updateOrderStatus(
      orderId,
      OrderStatus.entregado,
      paymentMethod: paymentMethod,
      observations: observations ?? 'Producto entregado correctamente',
    );
  }

  // Marcar como no entregado
  Future<Order> markAsNotDelivered(
    String orderId,
    String reason,
  ) async {
    return await updateOrderStatus(
      orderId,
      OrderStatus.noEntregado,
      observations: reason,
    );
  }

  // Marcar como producto incorrecto
  Future<Order> markAsIncorrectProduct(
    String orderId,
    String details,
  ) async {
    return await updateOrderStatus(
      orderId,
      OrderStatus.productoIncorrecto,
      observations: details,
    );
  }

  // Obtener rutas guardadas
  Future<List<DeliveryRoute>> getRoutes() async {
    try {
      await _initStorage();
      final data = await _storage.getData(_routesKey);
      if (data == null) return [];

      return (data as List).map((json) => _routeFromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Guardar ruta
  Future<void> saveRoute(DeliveryRoute route) async {
    await _initStorage();
    final routes = await getRoutes();
    final existingIndex = routes.indexWhere((r) => r.id == route.id);

    if (existingIndex >= 0) {
      routes[existingIndex] = route;
    } else {
      routes.add(route);
    }

    final data = routes.map((route) => _routeToJson(route)).toList();
    await _storage.saveData(_routesKey, data);
  }

  // Obtener estadísticas de entregas
  Future<DeliveryStats> getDeliveryStats() async {
    final orders = await getOrders();
    final today = DateTime.now();
    final todayOrders = orders.where((order) {
      if (order.deliveryTime == null) return false;
      return order.deliveryTime!.day == today.day &&
             order.deliveryTime!.month == today.month &&
             order.deliveryTime!.year == today.year;
    }).toList();

    return DeliveryStats(
      totalOrders: orders.length,
      deliveredToday: todayOrders.where((o) => o.status == OrderStatus.entregado).length,
      pendingOrders: orders.where((o) => o.status == OrderStatus.pendiente).length,
      inRouteOrders: orders.where((o) => o.status == OrderStatus.enRuta).length,
      totalRevenue: todayOrders
          .where((o) => o.status == OrderStatus.entregado)
          .fold(0.0, (sum, order) => sum + order.totalAmount),
    );
  }

  // Métodos de serialización
  Map<String, dynamic> _orderToJson(Order order) {
    return {
      'id': order.id,
      'clientName': order.clientName,
      'clientPhone': order.clientPhone,
      'deliveryLocation': {
        'latitude': order.deliveryLocation.latitude,
        'longitude': order.deliveryLocation.longitude,
      },
      'address': order.address,
      'items': order.items.map((item) => {
        'id': item.id,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
      }).toList(),
      'status': order.status.index,
      'paymentMethod': order.paymentMethod?.index,
      'createdAt': order.createdAt.millisecondsSinceEpoch,
      'deliveryTime': order.deliveryTime?.millisecondsSinceEpoch,
      'observations': order.observations,
      'totalAmount': order.totalAmount,
    };
  }

  Order _orderFromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      clientName: json['clientName'],
      clientPhone: json['clientPhone'],
      deliveryLocation: LatLng(
        json['deliveryLocation']['latitude'],
        json['deliveryLocation']['longitude'],
      ),
      address: json['address'],
      items: (json['items'] as List).map((item) => OrderItem(
        id: item['id'],
        name: item['name'],
        quantity: item['quantity'],
        price: item['price'],
      )).toList(),
      status: OrderStatus.values[json['status']],
      paymentMethod: json['paymentMethod'] != null
          ? PaymentMethod.values[json['paymentMethod']]
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      deliveryTime: json['deliveryTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deliveryTime'])
          : null,
      observations: json['observations'],
      totalAmount: json['totalAmount'],
    );
  }

  Map<String, dynamic> _routeToJson(DeliveryRoute route) {
    return {
      'id': route.id,
      'orders': route.orders.map((order) => _orderToJson(order)).toList(),
      'polylinePoints': route.polylinePoints.map((p) => {
        'latitude': p.latitude,
        'longitude': p.longitude,
      }).toList(),
      'startLocation': {
        'latitude': route.startLocation.latitude,
        'longitude': route.startLocation.longitude,
      },
      'endLocation': route.endLocation != null ? {
        'latitude': route.endLocation!.latitude,
        'longitude': route.endLocation!.longitude,
      } : null,
      'createdAt': route.createdAt.millisecondsSinceEpoch,
      'startTime': route.startTime?.millisecondsSinceEpoch,
      'endTime': route.endTime?.millisecondsSinceEpoch,
      'totalDistance': route.totalDistance,
      'estimatedDuration': route.estimatedDuration,
      'optimizationMethod': route.optimizationMethod,
      'isOptimized': route.isOptimized,
    };
  }

  DeliveryRoute _routeFromJson(Map<String, dynamic> json) {
    return DeliveryRoute(
      id: json['id'],
      orders: (json['orders'] as List).map((o) => _orderFromJson(o)).toList(),
      polylinePoints: (json['polylinePoints'] as List?)?.map((p) =>
        LatLng(p['latitude'], p['longitude'])
      ).toList() ?? [],
      startLocation: LatLng(
        json['startLocation']['latitude'],
        json['startLocation']['longitude'],
      ),
      endLocation: json['endLocation'] != null ? LatLng(
        json['endLocation']['latitude'],
        json['endLocation']['longitude']
      ) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      startTime: json['startTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['startTime'])
          : null,
      endTime: json['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'])
          : null,
      totalDistance: json['totalDistance'].toDouble(),
      estimatedDuration: json['estimatedDuration'],
      optimizationMethod: json['optimizationMethod'] ?? 'Manual',
      isOptimized: json['isOptimized'] ?? false,
    );
  }

  List<Order> _getSampleOrders() {
    return [
      Order(
        id: '1',
        clientName: 'Juan Perez',
        clientPhone: '+591 70123456',
        deliveryLocation: LatLng(-17.7834, -63.1821), // Santa Cruz, Bolivia
        address: 'Av. San Martín 123, Plan 3000',
        items: [
          OrderItem(id: '1', name: 'Hamburguesa', quantity: 2, price: 35),
          OrderItem(id: '2', name: 'Papas fritas', quantity: 1, price: 15),
        ],
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.efectivo,
        createdAt: DateTime.now(),
        deliveryTime: null,
        observations: '',
        totalAmount: 50,
      ),
      Order(
        id: '2',
        clientName: 'Maria Gomez',
        clientPhone: '+591 75987654',
        deliveryLocation: LatLng(-17.8040, -63.1562), // Centro Santa Cruz
        address: 'Calle Libertad 456, Equipetrol',
        items: [
          OrderItem(id: '3', name: 'Pizza', quantity: 1, price: 80),
          OrderItem(id: '4', name: 'Gaseosa', quantity: 2, price: 12),
        ],
        status: OrderStatus.enRuta,
        paymentMethod: PaymentMethod.tarjetaCredito,
        createdAt: DateTime.now().subtract(Duration(hours: 1)),
        deliveryTime: null,
        observations: '',
        totalAmount: 92,
      ),
      Order(
        id: '3',
        clientName: 'Pedro Martinez',
        clientPhone: '+591 69456789',
        deliveryLocation: LatLng(-17.8200, -63.1400), // Villa 1ro de Mayo
        address: 'Av. Los Cusis 789, Villa 1ro de Mayo',
        items: [
          OrderItem(id: '5', name: 'Pollo Broaster', quantity: 1, price: 65),
          OrderItem(id: '6', name: 'Ensalada', quantity: 1, price: 20),
        ],
        status: OrderStatus.entregado,
        paymentMethod: PaymentMethod.efectivo,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
        deliveryTime: DateTime.now().subtract(Duration(days: 1, hours: 2)),
        observations: 'Entregar en mano propia',
        totalAmount: 85,
      ),
      Order(
        id: '4',
        clientName: 'Ana Rodriguez',
        clientPhone: '+591 72345678',
        deliveryLocation: LatLng(-17.7950, -63.1750), // Zona Norte
        address: 'Barrio Las Palmas, Calle 3 #45',
        items: [
          OrderItem(id: '7', name: 'Empanadas', quantity: 6, price: 5),
          OrderItem(id: '8', name: 'Refresco', quantity: 1, price: 8),
        ],
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.transferencia,
        createdAt: DateTime.now().subtract(Duration(minutes: 30)),
        deliveryTime: null,
        observations: 'Llamar al llegar',
        totalAmount: 38,
      ),
      Order(
        id: '5',
        clientName: 'Carlos Mendoza',
        clientPhone: '+591 67123890',
        deliveryLocation: LatLng(-17.8300, -63.1250), // Zona Sur
        address: 'Urb. Los Jardines, Mz. 5 Casa 12',
        items: [
          OrderItem(id: '9', name: 'Sándwich', quantity: 2, price: 25),
          OrderItem(id: '10', name: 'Jugo natural', quantity: 2, price: 15),
        ],
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.efectivo,
        createdAt: DateTime.now().subtract(Duration(minutes: 45)),
        deliveryTime: null,
        observations: 'Casa color azul',
        totalAmount: 80,
      ),
    ];
  }
}

class DeliveryStats {
  final int totalOrders;
  final int deliveredToday;
  final int pendingOrders;
  final int inRouteOrders;
  final double totalRevenue;

  DeliveryStats({
    required this.totalOrders,
    required this.deliveredToday,
    required this.pendingOrders,
    required this.inRouteOrders,
    required this.totalRevenue,
  });
}
