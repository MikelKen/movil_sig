// services/enhanced_delivery_service.dart
import '../models/order.dart';
import '../models/delivery_route.dart';
import '../models/enhanced_route_models.dart'; // Importar los modelos del archivo separado
import 'storage_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EnhancedDeliveryService {
  static const String _ordersKey = 'orders';
  static const String _routesKey = 'delivery_routes';
  static const String _enhancedRoutesKey = 'enhanced_delivery_routes';

  late StorageService _storage;

  EnhancedDeliveryService() {
    _initStorage();
  }

  Future<void> _initStorage() async {
    _storage = await StorageService.getInstance();
  }

  // ✅ Método helper para conversión segura de IDs
  String _safeIdToString(dynamic id) {
    if (id == null) return '';
    if (id is String) return id;
    if (id is int) return id.toString();
    if (id is double) return id.toInt().toString();
    return id.toString();
  }

  // Método para cargar pedidos desde el backend
  Future<List<Order>> loadOrdersFromBackend(List<Map<String, dynamic>> backendOrders) async {
    try {
      print('🔄 Procesando ${backendOrders.length} pedidos del backend...');

      final orders = backendOrders.map((json) => _orderFromBackendJson(json)).toList();
      await saveOrders(orders);

      print('✅ ${orders.length} pedidos procesados y guardados localmente');
      return orders;
    } catch (e) {
      print('❌ Error al procesar pedidos del backend: $e');
      return [];
    }
  }

  // Obtener todos los pedidos
  Future<List<Order>> getOrders() async {
    try {
      await _initStorage();
      final data = await _storage.getData(_ordersKey);
      if (data == null) {
        final sampleOrders = _getSampleOrders();
        await saveOrders(sampleOrders);
        return sampleOrders;
      }

      return (data as List).map((json) => _orderFromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener pedidos: $e');
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

  // ===== GESTIÓN DE RUTAS MEJORADAS =====

  // Guardar ruta mejorada
  Future<void> saveEnhancedRoute(EnhancedDeliveryRoute route) async {
    await _initStorage();
    final routes = await getEnhancedRoutes();
    final existingIndex = routes.indexWhere((r) => r.id == route.id);

    if (existingIndex >= 0) {
      routes[existingIndex] = route;
    } else {
      routes.add(route);
    }

    final data = routes.map((route) => route.toJson()).toList();
    await _storage.saveData(_enhancedRoutesKey, data);

    print('💾 Ruta mejorada guardada: ${route.id} con ${route.stopInfos.length} paradas');
  }

  // Obtener rutas mejoradas
  Future<List<EnhancedDeliveryRoute>> getEnhancedRoutes() async {
    try {
      await _initStorage();
      final data = await _storage.getData(_enhancedRoutesKey);
      if (data == null) return [];

      return (data as List).map((json) => EnhancedDeliveryRoute.fromJson(json)).toList();
    } catch (e) {
      print('❌ Error al obtener rutas mejoradas: $e');
      return [];
    }
  }

  // Obtener ruta mejorada por ID
  Future<EnhancedDeliveryRoute?> getEnhancedRouteById(String id) async {
    final routes = await getEnhancedRoutes();
    try {
      return routes.firstWhere((route) => route.id == id);
    } catch (e) {
      return null;
    }
  }

  // Obtener la ruta activa más reciente
  Future<EnhancedDeliveryRoute?> getActiveEnhancedRoute() async {
    final routes = await getEnhancedRoutes();
    if (routes.isEmpty) return null;

    // Buscar ruta iniciada pero no terminada
    final activeRoutes = routes.where((route) =>
    route.startTime != null && route.endTime == null).toList();

    if (activeRoutes.isNotEmpty) {
      activeRoutes.sort((a, b) => b.startTime!.compareTo(a.startTime!));
      return activeRoutes.first;
    }

    // Si no hay ruta activa, devolver la más reciente
    routes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return routes.first;
  }

  // Iniciar ruta mejorada
  Future<EnhancedDeliveryRoute> startEnhancedRoute(String routeId) async {
    final route = await getEnhancedRouteById(routeId);
    if (route == null) {
      throw ArgumentError('Ruta no encontrada: $routeId');
    }

    final updatedRoute = route.copyWith(
      startTime: DateTime.now(),
    );

    await saveEnhancedRoute(updatedRoute);
    print('🚀 Ruta iniciada: ${routeId}');

    return updatedRoute;
  }

  // Finalizar ruta mejorada
  Future<EnhancedDeliveryRoute> endEnhancedRoute(String routeId) async {
    final route = await getEnhancedRouteById(routeId);
    if (route == null) {
      throw ArgumentError('Ruta no encontrada: $routeId');
    }

    final updatedRoute = route.copyWith(
      endTime: DateTime.now(),
    );

    await saveEnhancedRoute(updatedRoute);
    print('🏁 Ruta finalizada: ${routeId}');

    return updatedRoute;
  }

  // Actualizar progreso de entrega en ruta
  Future<void> updateDeliveryProgress(String routeId, String orderId, OrderStatus newStatus) async {
    // Actualizar estado del pedido
    await updateOrderStatus(orderId, newStatus);

    // La ruta se actualizará automáticamente cuando se recarguen los datos
    print('📦 Progreso actualizado - Pedido: $orderId, Estado: ${newStatus.name}');
  }

  // ===== GESTIÓN DE RUTAS TRADICIONALES (COMPATIBILIDAD) =====

  // Obtener rutas tradicionales
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

  // Guardar ruta tradicional
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

  // ===== ESTADÍSTICAS =====

  // Obtener estadísticas de entregas (compatible con DeliveryStats normal)
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

  // ===== MÉTODOS PRIVADOS DE CONVERSIÓN =====

  Order _orderFromBackendJson(Map<String, dynamic> json) {
    try {
      return Order(
        id: _safeIdToString(json['id']),
        clientName: json['clientName']?.toString() ?? '',
        clientPhone: json['clientPhone']?.toString() ?? '',
        deliveryLocation: LatLng(
          double.parse(json['deliveryLocation']['latitude'].toString()),
          double.parse(json['deliveryLocation']['longitude'].toString()),
        ),
        address: json['address']?.toString() ?? '',
        items: (json['items'] as List? ?? []).map((item) => OrderItem(
          id: _safeIdToString(item['id']),
          name: item['name']?.toString() ?? '',
          quantity: int.tryParse(item['quantity'].toString()) ?? 0,
          price: double.tryParse(item['price'].toString()) ?? 0.0,
        )).toList(),
        status: _parseOrderStatus(json['status']?.toString() ?? 'pendiente'),
        paymentMethod: json['paymentMethod'] != null
            ? _parsePaymentMethod(json['paymentMethod'].toString())
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        deliveryTime: json['deliveryTime'] != null
            ? DateTime.tryParse(json['deliveryTime'].toString())
            : null,
        observations: json['observations']?.toString() ?? '',
        totalAmount: double.tryParse(json['totalAmount'].toString()) ?? 0.0,
      );
    } catch (e) {
      print('❌ Error al convertir pedido: $json');
      print('Error: $e');
      rethrow;
    }
  }

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

  PaymentMethod _parsePaymentMethod(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'efectivo':
        return PaymentMethod.efectivo;
      case 'tarjeta_credito':
      case 'tarjetacredito':
        return PaymentMethod.tarjetaCredito;
      case 'transferencia':
        return PaymentMethod.transferencia;
      case 'qr':
        return PaymentMethod.qr;
      case 'transferencia_bancaria':
      case 'transferenciabancaria':
        return PaymentMethod.transferenciaBancaria;
      default:
        return PaymentMethod.efectivo;
    }
  }

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

  // Datos de ejemplo mejorados
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
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.efectivo,
        createdAt: DateTime.now().subtract(Duration(hours: 2)),
        deliveryTime: null,
        observations: 'Portero en edificio',
        totalAmount: 720,
      ),
      Order(
        id: '4',
        clientName: 'Pedro Salinas',
        clientPhone: '+591 7456-7890',
        deliveryLocation: LatLng(-17.801111, -63.155556),
        address: 'Av. Alemana #321, 4to Anillo Este',
        items: [
          OrderItem(id: '6', name: 'Vans Old Skool', quantity: 2, price: 320),
        ],
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.qr,
        createdAt: DateTime.now().subtract(Duration(hours: 3)),
        deliveryTime: null,
        observations: 'Disponible después de las 14:00',
        totalAmount: 640,
      ),
      Order(
        id: '5',
        clientName: 'Sofía Torres',
        clientPhone: '+591 7567-8901',
        deliveryLocation: LatLng(-17.775000, -63.190000),
        address: 'Barrio Las Palmas, Calle Los Tajibos #567',
        items: [
          OrderItem(id: '7', name: 'New Balance 574', quantity: 1, price: 420),
          OrderItem(id: '8', name: 'Calcetines deportivos', quantity: 3, price: 25),
        ],
        status: OrderStatus.pendiente,
        paymentMethod: PaymentMethod.transferencia,
        createdAt: DateTime.now().subtract(Duration(minutes: 30)),
        deliveryTime: null,
        observations: 'Casa con portón verde',
        totalAmount: 495,
      ),
    ];
  }
}

// Estadísticas de entrega (mantenemos la clase original para compatibilidad)
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