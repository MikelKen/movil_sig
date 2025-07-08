import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sig/models/enhanced_route_models.dart';
import '../models/delivery_route.dart';
import '../models/order.dart';
import '../services/enhanced_route_optimization_service.dart';
import '../services/enhanced_delivery_service.dart';
import '../services/location_service.dart';
import 'delivery_management_screen.dart' as delivery_screen;

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final EnhancedDeliveryService _deliveryService = EnhancedDeliveryService();
  final EnhancedRouteOptimizationService _routeService = EnhancedRouteOptimizationService();

  LatLng? _currentLocation;
  EnhancedDeliveryRoute? _optimizedRoute;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = false;
  bool _isOptimizing = false;
  bool _isLoadingLocation = false;
  String? _errorMessage;
  List<Order> _pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Obtener ubicación actual
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      } else {
        _currentLocation = const LatLng(-17.8146, -63.1561);
      }

      // 2. Obtener pedidos pendientes
      _pendingOrders = await _deliveryService.getPendingOrders();

      // 3. **NUEVO**: Intentar cargar ruta optimizada existente
      final existingRoute = await _deliveryService.getActiveEnhancedRoute();
      if (existingRoute != null) {
        print('📍 Ruta optimizada encontrada, cargando automáticamente...');
        setState(() {
          _optimizedRoute = existingRoute;
        });

        // Mostrar la ruta en el mapa
        await _displayRouteOnMap();

        // Ajustar la vista del mapa a la ruta
        await _fitMapToRoute();

        _showMessage('Ruta optimizada cargada automáticamente');
      } else {
        // Si no hay ruta optimizada, mostrar solo los marcadores
        _updateMarkersWithoutRoute();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando datos: $e';
        _isLoading = false;
      });
      print('❌ Error en _initializeData: $e');
    }
  }

  void _centerMapOnCurrentLocation() {
    if (_currentLocation != null && _mapController != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
      );
    }
  }

  Future<void> _updateCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null && mounted) {
        setState(() {
          _currentLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
        });
        _centerMapOnCurrentLocation();

        if (_optimizedRoute == null) {
          _updateMarkersWithoutRoute();
        } else {
          await _displayRouteOnMap();
        }

        _showMessage('Ubicación actualizada');
      }
    } catch (e) {
      _showMessage('Error al obtener ubicación: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _navigateToDeliveryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const delivery_screen.DeliveryManagementScreen(),
      ),
    ).then((_) {
      if (mounted) {
        // **MODIFICADO**: Recargar solo datos básicos, mantener ruta si existe
        _reloadBasicData();
      }
    });
  }

  // **NUEVO**: Método para recargar solo datos básicos sin perder la ruta
  Future<void> _reloadBasicData() async {
    try {
      // Actualizar pedidos pendientes
      _pendingOrders = await _deliveryService.getPendingOrders();

      // Verificar si la ruta sigue siendo válida
      final currentRoute = await _deliveryService.getActiveEnhancedRoute();
      if (currentRoute != null && _optimizedRoute?.id == currentRoute.id) {
        // La ruta sigue siendo la misma, mantenerla
        print('✅ Ruta optimizada mantenida');
      } else if (currentRoute != null) {
        // Hay una nueva ruta, cargarla
        setState(() {
          _optimizedRoute = currentRoute;
        });
        await _displayRouteOnMap();
        print('🔄 Nueva ruta optimizada cargada');
      } else {
        // No hay ruta, limpiar
        setState(() {
          _optimizedRoute = null;
        });
        _updateMarkersWithoutRoute();
        print('🧹 Ruta optimizada eliminada');
      }
    } catch (e) {
      print('❌ Error recargando datos básicos: $e');
    }
  }

  Future<void> _optimizeRoute() async {
    if (_pendingOrders.isEmpty) {
      _showMessage('No hay órdenes pendientes para optimizar', isError: true);
      return;
    }

    if (!_routeService.isApiKeyConfigured()) {
      _showMessage('API Key de Google Maps no configurada', isError: true);
      return;
    }

    setState(() {
      _isOptimizing = true;
      _errorMessage = null;
    });

    try {
      // Mostrar diálogo para seleccionar hora de inicio
      final startTime = await _showStartTimeDialog();
      if (startTime == null) {
        setState(() => _isOptimizing = false);
        return;
      }

      final optimizedRoute = await _routeService.optimizeDeliveryRouteEnhanced(
        startLocation: _currentLocation!,
        orders: _pendingOrders,
        startTime: startTime,
      );

      // Guardar la ruta optimizada
      await _deliveryService.saveEnhancedRoute(optimizedRoute);

      setState(() {
        _optimizedRoute = optimizedRoute;
        _isOptimizing = false;
      });

      await _displayRouteOnMap();
      _showMessage('Ruta optimizada generada exitosamente');

      print('💾 Ruta optimizada guardada y mostrada: ${optimizedRoute.id}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error optimizando ruta: $e';
        _isOptimizing = false;
      });
      _showMessage('Error al optimizar ruta: $e', isError: true);
    }
  }

  Future<DateTime?> _showStartTimeDialog() async {
    final now = DateTime.now();
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      helpText: 'Selecciona hora de inicio',
    );

    if (selectedTime != null) {
      return DateTime(
        now.year,
        now.month,
        now.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    }
    return null;
  }

  Future<void> _displayRouteOnMap() async {
    if (_optimizedRoute == null) return;

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Marcador de inicio
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start_location'),
          position: _currentLocation!,
          infoWindow: InfoWindow(
            title: 'Punto de Inicio',
            snippet: 'Salida: ${_optimizedRoute!.formattedPlannedStartTime}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Marcadores de entregas con información detallada
    for (final stopInfo in _optimizedRoute!.stopInfos) {
      markers.add(
        Marker(
          markerId: MarkerId('delivery_${stopInfo.order.id}'),
          position: stopInfo.location,
          infoWindow: InfoWindow(
            title: 'Parada ${stopInfo.sequence}: ${stopInfo.order.clientName}',
            snippet: 'ETA: ${stopInfo.formattedEstimatedArrival} | ${stopInfo.formattedDistanceFromPrevious}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(stopInfo.sequence - 1, _optimizedRoute!.stopInfos.length),
          ),
          onTap: () => _showEnhancedOrderDetails(stopInfo),
        ),
      );
    }

    // Polyline de la ruta
    if (_optimizedRoute!.polylinePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('optimized_route'),
          points: _optimizedRoute!.polylinePoints,
          color: Theme.of(context).colorScheme.primary,
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    // **NUEVO**: Ajustar automáticamente la vista del mapa
    if (_mapController != null) {
      await _fitMapToRoute();
    }
  }

  void _updateMarkersWithoutRoute() {
    final markers = <Marker>{};

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Mi Ubicación',
            snippet: 'Punto de inicio para rutas',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    for (final order in _pendingOrders) {
      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}'),
          position: order.deliveryLocation,
          infoWindow: InfoWindow(
            title: order.clientName,
            snippet: 'Bs. ${order.totalAmount.toStringAsFixed(2)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          onTap: () => _showOrderDetails(order),
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = {};
    });
  }

  double _getMarkerHue(int index, int total) {
    final hues = [
      BitmapDescriptor.hueRed,
      BitmapDescriptor.hueOrange,
      BitmapDescriptor.hueYellow,
      BitmapDescriptor.hueGreen,
      BitmapDescriptor.hueBlue,
      BitmapDescriptor.hueViolet,
      BitmapDescriptor.hueRose,
    ];
    return hues[index % hues.length];
  }

  Future<void> _fitMapToRoute() async {
    if (_mapController == null || _optimizedRoute == null) return;

    final bounds = _calculateBounds([
      if (_currentLocation != null) _currentLocation!,
      ..._optimizedRoute!.deliveryLocations,
    ]);

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(-17.8146, -63.1561),
        northeast: const LatLng(-17.8146, -63.1561),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // **NUEVO**: Método para limpiar/eliminar ruta optimizada
  Future<void> _clearOptimizedRoute() async {
    try {
      // Confirmar con el usuario
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Limpiar Ruta'),
          content: const Text('¿Estás seguro de que quieres eliminar la ruta optimizada actual?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (shouldClear == true) {
        setState(() {
          _optimizedRoute = null;
        });

        // Limpiar del storage (opcional - puedes mantener para historial)
        // await _deliveryService.clearActiveRoute();

        _updateMarkersWithoutRoute();
        _showMessage('Ruta optimizada eliminada');

        print('🧹 Ruta optimizada limpiada');
      }
    } catch (e) {
      _showMessage('Error al limpiar ruta: $e', isError: true);
    }
  }

  void _showEnhancedOrderDetails(RouteStopInfo stopInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stopInfo.sequence}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parada ${stopInfo.sequence}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            stopInfo.order.clientName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Información de timing
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            'Información de Tiempo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Hora estimada de llegada:', stopInfo.formattedEstimatedArrival),
                      _buildInfoRow('Tiempo desde inicio:', stopInfo.formattedTimeFromStart),
                      _buildInfoRow('Tiempo desde anterior:', stopInfo.formattedTimeFromPrevious),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Información de distancia
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.straighten, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Información de Distancia',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Distancia desde inicio:', stopInfo.formattedDistanceFromStart),
                      _buildInfoRow('Distancia desde anterior:', stopInfo.formattedDistanceFromPrevious),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Información del pedido
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_bag, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Detalles del Pedido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Cliente:', stopInfo.order.clientName),
                      _buildInfoRow('Teléfono:', stopInfo.order.clientPhone),
                      _buildInfoRow('Dirección:', stopInfo.order.address),
                      _buildInfoRow('Total:', 'Bs. ${stopInfo.order.totalAmount.toStringAsFixed(2)}'),

                      const SizedBox(height: 12),
                      const Text(
                        'Productos:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...stopInfo.order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text('• ${item.name} x${item.quantity} - Bs. ${item.price.toStringAsFixed(2)}'),
                      )),

                      if (stopInfo.order.observations != null && stopInfo.order.observations!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Observaciones: ${stopInfo.order.observations}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(stopInfo.location, 16),
                          );
                        },
                        icon: const Icon(Icons.location_on),
                        label: const Text('Ver en Mapa'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // Aquí puedes agregar funcionalidad para llamar
                          // launch('tel:${stopInfo.order.clientPhone}');
                        },
                        icon: const Icon(Icons.phone),
                        label: const Text('Llamar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pedido Pendiente',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              order.clientName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Teléfono: ${order.clientPhone}'),
            const SizedBox(height: 4),
            Text('Dirección: ${order.address}'),
            const SizedBox(height: 8),
            Text('Total: Bs. ${order.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'Productos:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...order.items.map((item) => Text('• ${item.name} x${item.quantity}')),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (label.toLowerCase().contains('dirección') || label.toLowerCase().contains('direccion')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              softWrap: true,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  void _showRouteDetailPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del panel
              Row(
                children: [
                  Icon(
                    Icons.route,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Secuencia de Entregas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              if (_optimizedRoute != null) ...[
                const SizedBox(height: 16),

                // Resumen de la ruta
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem(
                              Icons.local_shipping,
                              '${_optimizedRoute!.totalOrders} entregas',
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              Icons.straighten,
                              _optimizedRoute!.formattedDistance,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem(
                              Icons.schedule,
                              '${_optimizedRoute!.formattedPlannedStartTime} - ${_optimizedRoute!.formattedEstimatedEndTime}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Lista de paradas
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _optimizedRoute!.stopInfos.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final stopInfo = _optimizedRoute!.stopInfos[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Número de secuencia
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  '${stopInfo.sequence}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Información de la parada
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stopInfo.order.clientName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stopInfo.order.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          stopInfo.formattedEstimatedArrival,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          stopInfo.formattedDistanceFromPrevious,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Valor del pedido
                            Column(
                              children: [
                                Text(
                                  'Bs. ${stopInfo.order.totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showEnhancedOrderDetails(stopInfo);
                                  },
                                  icon: const Icon(Icons.info_outline),
                                  iconSize: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Optimizada Avanzada'),
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (_isLoadingLocation)
            Padding(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: SizedBox(
                width: isTablet ? 24 : 20,
                height: isTablet ? 24 : 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

          if (_optimizedRoute != null)
            IconButton(
              onPressed: _showRouteDetailPanel,
              icon: const Icon(Icons.list),
              tooltip: 'Ver Secuencia',
            ),
          // **NUEVO**: Botón para limpiar ruta
          if (_optimizedRoute != null)
            IconButton(
              onPressed: _clearOptimizedRoute,
              icon: const Icon(Icons.clear),
              tooltip: 'Limpiar Ruta',
            ),
          SizedBox(width: isTablet ? 16 : 8),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando datos...'),
          ],
        ),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              // **NUEVO**: Si hay ruta optimizada, ajustar vista automáticamente
              if (_optimizedRoute != null) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  _fitMapToRoute();
                });
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(-17.8146, -63.1561),
              zoom: isTablet ? 15 : 12,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            buildingsEnabled: false,
            trafficEnabled: false,
            style: theme.brightness == Brightness.dark ? _darkMapStyle : null,
          ),

          // Botones de acción flotantes
          Positioned(
            bottom: isTablet ? 200 : 180,
            right: isTablet ? 32 : 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón de gestión de entregas
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: "delivery_management",
                    onPressed: _navigateToDeliveryManagement,
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                    elevation: 0,
                    tooltip: 'Gestión de Entregas',
                    child: Icon(
                      Icons.local_shipping,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                ),

                // Botón para actualizar ubicación
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: "update_location",
                    onPressed: _isLoadingLocation ? null : _updateCurrentLocation,
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary,
                    elevation: 0,
                    tooltip: 'Actualizar Ubicación',
                    child: _isLoadingLocation
                        ? SizedBox(
                      width: isTablet ? 24 : 20,
                      height: isTablet ? 24 : 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onTertiary,
                      ),
                    )
                        : Icon(
                      Icons.gps_fixed,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Botón para centrar en ubicación actual
          Positioned(
            bottom: isTablet ? 120 : 100,
            right: isTablet ? 32 : 20,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: "center_location",
                onPressed: _centerMapOnCurrentLocation,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                tooltip: 'Centrar en Mi Ubicación',
                child: Icon(
                  Icons.my_location,
                  size: isTablet ? 28 : 24,
                ),
              ),
            ),
          ),

          // Botón para ver secuencia de entregas
          if (_optimizedRoute != null)
            Positioned(
              bottom: isTablet ? 40 : 20,
              right: isTablet ? 32 : 20,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton(
                  heroTag: "route_details",
                  onPressed: _showRouteDetailPanel,
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  tooltip: 'Ver Secuencia de Entregas',
                  child: Icon(
                    Icons.format_list_numbered,
                    size: isTablet ? 28 : 24,
                  ),
                ),
              ),
            ),

          // Información de la ruta optimizada
          if (_optimizedRoute != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.route,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Ruta Optimizada',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_optimizedRoute!.formattedPlannedStartTime} - ${_optimizedRoute!.formattedEstimatedEndTime}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryItem(
                              Icons.local_shipping,
                              '${_optimizedRoute!.totalOrders} entregas',
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              Icons.straighten,
                              _optimizedRoute!.formattedDistance,
                            ),
                          ),
                          Expanded(
                            child: _buildSummaryItem(
                              Icons.access_time,
                              _optimizedRoute!.formattedDuration,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Toca los marcadores para ver detalles de cada entrega',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Botón principal de optimización
      floatingActionButton: _pendingOrders.isEmpty
          ? null
          : FloatingActionButton.extended(
        onPressed: _isOptimizing ? null : _optimizeRoute,
        icon: _isOptimizing
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.auto_fix_high),
        label: Text(_isOptimizing
            ? 'Optimizando...'
            : _optimizedRoute != null
            ? 'Re-optimizar Ruta'
            : 'Optimizar Ruta Avanzada'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#212121"}]
  },
  {
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#757575"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#212121"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#2c2c2c"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#000000"}]
  }
]
''';
}