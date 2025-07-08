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

  // Nuevo método para cargar pedidos desde el backend
  Future<List<Order>> loadOrdersFromBackend(List<Map<String, dynamic>> backendOrders) async {
    try {
      final orders = backendOrders.map((json) => _orderFromBackendJson(json)).toList();

      // Guardar los pedidos del backend localmente
      await saveOrders(orders);

      return orders;
    } catch (e) {
      print('Error al procesar pedidos del backend: $e');
      return [];
    }
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

  // Método para convertir datos del backend a Order
  Order _orderFromBackendJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      clientName: json['clientName'] ?? '',
      clientPhone: json['clientPhone'] ?? '',
      deliveryLocation: LatLng(
        double.parse(json['deliveryLocation']['latitude'].toString()),
        double.parse(json['deliveryLocation']['longitude'].toString()),
      ),
      address: json['address'] ?? '',
      items: (json['items'] as List? ?? []).map((item) => OrderItem(
        id: item['id']?.toString() ?? '',
        name: item['name'] ?? '',
        quantity: (item['quantity'] ?? 0).toInt(),
        price: double.parse(item['price'].toString()),
      )).toList(),
      status: _parseOrderStatus(json['status'] ?? 'pendiente'),
      paymentMethod: json['paymentMethod'] != null
          ? _parsePaymentMethod(json['paymentMethod'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      deliveryTime: json['deliveryTime'] != null
          ? DateTime.parse(json['deliveryTime'])
          : null,
      observations: json['observations'] ?? '',
      totalAmount: double.parse(json['totalAmount'].toString()),
    );
  }

  // Método para parsear el estado del pedido desde string
  OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return OrderStatus.pendiente;
      case 'en_ruta':
      case 'enruta':
        return OrderStatus.enRuta;
      case 'entregado':
        return OrderStatus.entregado;
      case 'no_entregado':
      case 'noentregado':
        return OrderStatus.noEntregado;
      case 'producto_incorrecto':
      case 'productoincorrecto':
        return OrderStatus.productoIncorrecto;
      default:
        return OrderStatus.pendiente;
    }
  }

  // Método para parsear método de pago desde string
  PaymentMethod _parsePaymentMethod(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'efectivo':
        return PaymentMethod.efectivo;
      case 'tarjeta_credito':
      case 'tarjetacredito':
        return PaymentMethod.tarjetaCredito;
      case 'transferencia':
        return PaymentMethod.transferencia;
      default:
        return PaymentMethod.efectivo;
    }
  }

  // Métodos de serialización existentes
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

  // Datos de ejemplo con zapatos (similar a tu backend)
  List<Order> _getSampleOrders() {
    return [
      Order(
        id: '1',
        clientName: 'María González',
        clientPhone: '+591 7123-4567',
        deliveryLocation: LatLng(-17.783333, -63.183333),
        address: 'Av. Cristo Redentor #123, 2do Anillo Norte',
        items: [
          OrderItem(id: '1', name: 'Nike Air Max 270', quantity: 1, price: 450),
          OrderItem(id: '2', name: 'Converse Chuck Taylor All Star', quantity: 1, price: 280),
        ],
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.efectivo,
        createdAt: DateTime.now(),
        deliveryTime: null,
        observations: 'Llamar al llegar, casa color blanco',
        totalAmount: 730,
      ),
      Order(
        id: '2',
        clientName: 'Carlos Mendoza',
        clientPhone: '+591 7234-5678',
        deliveryLocation: LatLng(-17.789444, -63.175278),
        address: 'Calle Warnes #456, Equipetrol Norte',
        items: [
          OrderItem(id: '3', name: 'Adidas Ultraboost 22', quantity: 1, price: 520),
          OrderItem(id: '4', name: 'Puma RS-X3', quantity: 1, price: 380),
        ],
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.tarjetaCredito,
        createdAt: DateTime.now().subtract(Duration(hours: 1)),
        deliveryTime: null,
        observations: 'Edificio azul, 2do piso',
        totalAmount: 900,
      ),
      Order(
        id: '3',
        clientName: 'Ana Rodríguez',
        clientPhone: '+591 7345-6789',
        deliveryLocation: LatLng(-17.795556, -63.167222),
        address: 'Av. Banzer #789, 3er Anillo Norte',
        items: [
          OrderItem(id: '5', name: 'Dr. Martens 1460', quantity: 1, price: 720),
        ],
        status: OrderStatus.entregado,
        paymentMethod: PaymentMethod.efectivo,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
        deliveryTime: DateTime.now().subtract(Duration(days: 1, hours: 2)),
        observations: 'Entregado correctamente',
        totalAmount: 720,
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