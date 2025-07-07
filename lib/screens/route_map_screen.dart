import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/delivery_route.dart';
import '../models/order.dart';
import '../services/route_optimization_service.dart';
import '../services/delivery_service.dart';
import '../services/location_service.dart';

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final DeliveryService _deliveryService = DeliveryService();
  final RouteOptimizationService _routeOptimizationService = RouteOptimizationService();

  LatLng? _currentLocation;
  DeliveryRoute? _optimizedRoute;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = false;
  bool _isOptimizing = false;
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
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      } else {
        _currentLocation = const LatLng(-17.8146, -63.1561);
      }

      _pendingOrders = await _deliveryService.getPendingOrders();
      _updateMarkersWithoutRoute();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error cargando datos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _optimizeRoute() async {
    if (_pendingOrders.isEmpty) {
      _showMessage('No hay órdenes pendientes para optimizar', isError: true);
      return;
    }

    if (!_routeOptimizationService.isApiKeyConfigured()) {
      _showMessage('API Key de Google Maps no configurada', isError: true);
      return;
    }

    setState(() {
      _isOptimizing = true;
      _errorMessage = null;
    });

    try {
      final optimizedRoute = await _routeOptimizationService.optimizeDeliveryRoute(
        startLocation: _currentLocation!,
        orders: _pendingOrders,
      );

      setState(() {
        _optimizedRoute = optimizedRoute;
        _isOptimizing = false;
      });

      await _displayRouteOnMap();
      _showMessage('Ruta optimizada generada exitosamente');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error optimizando ruta: $e';
        _isOptimizing = false;
      });
      _showMessage('Error al optimizar ruta: $e', isError: true);
    }
  }

  Future<void> _displayRouteOnMap() async {
    if (_optimizedRoute == null) return;

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Punto de Inicio',
            snippet: 'Tu ubicación actual',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    for (int i = 0; i < _optimizedRoute!.orders.length; i++) {
      final order = _optimizedRoute!.orders[i];
      markers.add(
        Marker(
          markerId: MarkerId('delivery_${order.id}'),
          position: order.deliveryLocation,
          infoWindow: InfoWindow(
            title: 'Entrega ${i + 1}: ${order.clientName}',
            snippet: 'Bs. ${order.totalAmount.toStringAsFixed(2)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(i, _optimizedRoute!.orders.length),
          ),
          onTap: () => _showOrderDetails(order, i + 1),
        ),
      );
    }

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

    await _fitMapToRoute();
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
          onTap: () => _showOrderDetails(order, null),
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

  void _showOrderDetails(Order order, int? sequenceNumber) {
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
              sequenceNumber != null ? 'Entrega #$sequenceNumber' : 'Pendiente',
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

  void _showRouteStatistics() {
    if (_optimizedRoute == null) return;

    final stats = _routeOptimizationService.calculateRouteStatistics(_optimizedRoute!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estadísticas de Ruta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total de entregas:', '${stats['totalOrders']}'),
            _buildStatRow('Valor total:', 'Bs. ${stats['totalValue'].toStringAsFixed(2)}'),
            _buildStatRow('Distancia total:', stats['totalDistance']),
            _buildStatRow('Tiempo estimado:', stats['estimatedTime']),
            _buildStatRow('Método optimización:', _optimizedRoute!.optimizationMethod),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
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
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Optimizada'),
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          if (_optimizedRoute != null)
            IconButton(
              onPressed: _showRouteStatistics,
              icon: const Icon(Icons.analytics),
              tooltip: 'Estadísticas',
            ),
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
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: _currentLocation ?? const LatLng(-17.8146, -63.1561),
                        zoom: 12,
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
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.local_shipping,
                                        '${_optimizedRoute!.totalOrders} entregas',
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.straighten,
                                        _optimizedRoute!.formattedDistance,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoItem(
                                        Icons.access_time,
                                        _optimizedRoute!.formattedDuration,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_optimizedRoute == null && _pendingOrders.isNotEmpty)
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
                                Text(
                                  '${_pendingOrders.length} entregas pendientes',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Presiona el botón para optimizar la ruta',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
                  : const Icon(Icons.route),
              label: Text(_isOptimizing ? 'Optimizando...' : 'Optimizar Ruta'),
            ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
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
