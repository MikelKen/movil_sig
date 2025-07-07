import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/delivery_service.dart';

class OrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback? onStatusChanged;
  final bool showActions;

  const OrderCard({
    super.key,
    required this.order,
    this.onStatusChanged,
    this.showActions = true,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  final DeliveryService _deliveryService = DeliveryService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del pedido
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.clientName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pedido #${widget.order.id}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    widget.order.statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: _getStatusColor().withOpacity(0.2),
                  side: BorderSide(color: _getStatusColor()),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Información del cliente
            _buildInfoRow(Icons.phone, widget.order.clientPhone),
            _buildInfoRow(Icons.location_on, widget.order.address),

            const SizedBox(height: 12),

            // Items del pedido
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productos:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${item.name} x${item.quantity}',
                          style: const TextStyle(
                            color: Colors.black
                          ),),
                        ),
                        Text(
                          'Bs. ${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  )),
                  const Divider(),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Total:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black
                          ),
                        ),
                      ),
                      Text(
                        'Bs. ${widget.order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Información adicional
            if (widget.order.paymentMethod != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.payment, 'Pago: ${widget.order.paymentMethodText}'),
            ],

            if (widget.order.deliveryTime != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                Icons.access_time,
                'Entregado: ${_formatDateTime(widget.order.deliveryTime!)}',
              ),
            ],

            if (widget.order.observations != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Observaciones:',
                      style: TextStyle(fontWeight: FontWeight.bold,
                      color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.order.observations!),
                  ],
                ),
              ),
            ],

            // Botones de acción
            if (widget.showActions && widget.order.status == OrderStatus.pendiente) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : () => _showDeliveryDialog(),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Entregar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () => _showNotDeliveredDialog(),
                      icon: const Icon(Icons.cancel),
                      label: const Text('No Entregado'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (widget.order.status) {
      case OrderStatus.pendiente:
        return Icons.schedule;
      case OrderStatus.enRuta:
        return Icons.local_shipping;
      case OrderStatus.entregado:
        return Icons.check_circle;
      case OrderStatus.noEntregado:
        return Icons.cancel;
      case OrderStatus.productoIncorrecto:
        return Icons.error;
    }
  }

  Color _getStatusColor() {
    switch (widget.order.status) {
      case OrderStatus.pendiente:
        return Colors.orange;
      case OrderStatus.enRuta:
        return Colors.blue;
      case OrderStatus.entregado:
        return Colors.green;
      case OrderStatus.noEntregado:
        return Colors.red;
      case OrderStatus.productoIncorrecto:
        return Colors.purple;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showDeliveryDialog() {
    PaymentMethod? selectedPayment;
    final observationsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona el método de pago:'),
            const SizedBox(height: 16),
            ...PaymentMethod.values.map((method) => RadioListTile<PaymentMethod>(
              title: Text(_getPaymentMethodText(method)),
              value: method,
              groupValue: selectedPayment,
              onChanged: (value) {
                setState(() {
                  selectedPayment = value;
                });
                Navigator.pop(context);
                _showDeliveryDialog();
              },
            )),
            const SizedBox(height: 16),
            TextField(
              controller: observationsController,
              decoration: const InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: selectedPayment != null
                ? () => _completeDelivery(selectedPayment!, observationsController.text)
                : null,
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _showNotDeliveredDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo de No Entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Especifica el motivo por el cual no se pudo entregar:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _markAsNotDelivered(reasonController.text),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDelivery(PaymentMethod paymentMethod, String observations) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      await _deliveryService.registerDelivery(
        widget.order.id,
        paymentMethod,
        observations: observations.isEmpty ? null : observations,
      );

      widget.onStatusChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrega registrada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar entrega: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsNotDelivered(String reason) async {
    Navigator.pop(context);
    if (reason.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _deliveryService.markAsNotDelivered(widget.order.id, reason);
      widget.onStatusChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado correctamente'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getPaymentMethodText(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.qr:
        return 'QR';
      case PaymentMethod.transferenciaBancaria:
        return 'Transferencia Bancaria';
      case PaymentMethod.efectivo:
        return 'Efectivo';
      case PaymentMethod.tarjetaCredito:
        return 'Tarjeta de Crédito';
      case PaymentMethod.transferencia:
        return 'Transferencia';
    }
  }
}
