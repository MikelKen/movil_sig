import 'package:google_maps_flutter/google_maps_flutter.dart';

enum OrderStatus {
  pendiente,
  enRuta,
  entregado,
  noEntregado,
  productoIncorrecto,
}

enum PaymentMethod {
  qr,
  efectivo,
  transferencia,
}

class Order {
  final String id;
  final String clientName;
  final String clientPhone;
  final LatLng deliveryLocation;
  final String address;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentMethod? paymentMethod;
  final DateTime createdAt;
  final DateTime? deliveryTime;
  final String? observations;
  final double totalAmount;

  Order({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.deliveryLocation,
    required this.address,
    required this.items,
    required this.status,
    this.paymentMethod,
    required this.createdAt,
    this.deliveryTime,
    this.observations,
    required this.totalAmount,
  });

  Order copyWith({
    OrderStatus? status,
    PaymentMethod? paymentMethod,
    DateTime? deliveryTime,
    String? observations,
  }) {
    return Order(
      id: id,
      clientName: clientName,
      clientPhone: clientPhone,
      deliveryLocation: deliveryLocation,
      address: address,
      items: items,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      observations: observations ?? this.observations,
      totalAmount: totalAmount,
    );
  }

  String get statusText {
    switch (status) {
      case OrderStatus.pendiente:
        return 'Pendiente';
      case OrderStatus.enRuta:
        return 'En Ruta';
      case OrderStatus.entregado:
        return 'Entregado';
      case OrderStatus.noEntregado:
        return 'No Entregado';
      case OrderStatus.productoIncorrecto:
        return 'Producto Incorrecto';
    }
  }

  String get paymentMethodText {
    if (paymentMethod == null) return 'No especificado';
    switch (paymentMethod!) {
      case PaymentMethod.qr:
        return 'QR';;
      case PaymentMethod.efectivo:
        return 'Efectivo';
      case PaymentMethod.transferencia:
        return 'Transferencia';
    }
  }

  // Método para deserializar desde JSON
  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      clientName: json['clientName'],
      clientPhone: json['clientPhone'],
      deliveryLocation: LatLng(
        double.parse(json['deliveryLocation']['latitude']),
        double.parse(json['deliveryLocation']['longitude']),
      ),
      address: json['address'],
      items: (json['items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList(),
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      totalAmount: double.parse(json['totalAmount']),
    );
  }

  static OrderStatus _parseStatus(String status) {
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
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get subtotal => quantity * price;

  // Método para deserializar desde JSON
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'],
      price: double.parse(json['price'].toString()),
    );
  }
}
