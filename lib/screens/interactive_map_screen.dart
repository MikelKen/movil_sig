import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/saved_location.dart';
import '../models/order.dart';
import '../models/delivery_route.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/delivery_service.dart';
import '../services/route_visualization_service.dart';
import '../widgets/add_location_dialog.dart';
import '../widgets/location_list_panel.dart';
import 'delivery_management_screen.dart' as delivery_screen;
import 'route_map_screen.dart' as route_screen;

class InteractiveMapScreen extends StatefulWidget {
  const InteractiveMapScreen({Key? key}) : super(key: key);

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final DeliveryService _deliveryService = DeliveryService();
  final RouteVisualizationService _routeVisualizationService = RouteVisualizationService();
  late StorageService _storageService;

  // Location data
  LatLng? _currentLocation;
  List<SavedLocation> _savedLocations = [];
  List<Order> _pendingOrders = [];
  DeliveryRoute? _activeRoute;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // UI state
  bool _isLoading = true;
  bool _isLoadingLocation = false;
  bool _showDeliveryMarkers = true;
  bool _showRouteVisualization = false;
  bool _isLoadingRoute = false;

  // Optimizaciones para rendimiento
  static const CameraPosition _santaCruzPosition = CameraPosition(
    target: LatLng(-17.8146, -63.1561),
    zoom: 12.0,
  );

  // Timer para debounce de actualizaciones
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      _storageService = await StorageService.getInstance();
      await _loadSavedLocations();
      await _loadPendingOrders();
      await _getCurrentLocation();
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        setState(() {
          _currentLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
        });
        _centerMapOnCurrentLocation();
      } else {
        // Usar ubicación por defecto si no se puede obtener la actual
        setState(() {
          _currentLocation = const LatLng(-17.8146, -63.1561); // Santa Cruz
        });
      }
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _currentLocation = const LatLng(-17.8146, -63.1561); // Santa Cruz
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
        _isLoading = false;
      });
      _updateMarkers();
    }
  }

  Future<void> _loadSavedLocations() async {
    try {
      final locations = await _storageService.getSavedLocations();
      setState(() {
        _savedLocations = locations;
      });
      _updateMarkers();
    } catch (e) {
      print('Error loading saved locations: $e');
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      final orders = await _deliveryService.getPendingOrders();
      setState(() {
        _pendingOrders = orders;
      });
      _updateMarkers();
    } catch (e) {
      print('Error loading pending orders: $e');
    }
  }

  void _updateMarkers() {
    Set<Marker> newMarkers = {};

    // Agregar marcador de ubicación actual
    if (_currentLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Mi Ubicación',
            snippet: 'Tu ubicación actual',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Agregar marcadores de ubicaciones guardadas
    for (final location in _savedLocations) {
      newMarkers.add(
        Marker(
          markerId: MarkerId(location.id),
          position: location.position,
          infoWindow: InfoWindow(
            title: location.name,
            snippet: location.description ?? location.type.displayName,
          ),
          icon: _getMarkerIcon(location.type),
          onTap: () => _onMarkerTap(location),
        ),
      );
    }

    // Agregar marcadores de pedidos de entrega si están habilitados
    if (_showDeliveryMarkers) {
      for (final order in _pendingOrders) {
        newMarkers.add(
          Marker(
            markerId: MarkerId('order_${order.id}'),
            position: order.deliveryLocation,
            infoWindow: InfoWindow(
              title: 'Entrega: ${order.clientName}',
              snippet: 'Bs. ${order.totalAmount.toStringAsFixed(2)} - ${order.statusText}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              order.status == OrderStatus.pendiente
                ? BitmapDescriptor.hueOrange
                : BitmapDescriptor.hueBlue,
            ),
            onTap: () => _onOrderMarkerTap(order),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  BitmapDescriptor _getMarkerIcon(LocationType type) {
    switch (type) {
      case LocationType.home:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case LocationType.work:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case LocationType.restaurant:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case LocationType.shopping:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
      case LocationType.hospital:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
      case LocationType.school:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueYellow,
        );
      case LocationType.gas_station:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    print('Mapa interactivo creado exitosamente');
  }

  void _onMapTap(LatLng position) {
    showDialog(
      context: context,
      builder:
          (context) => AddLocationDialog(
            position: position,
            onLocationSaved: _onLocationSaved,
          ),
    );
  }

  void _onMarkerTap(SavedLocation location) {
    _showLocationDetails(location);
  }

  void _onLocationSaved(SavedLocation location) async {
    try {
      await _storageService.saveLocation(location);
      await _loadSavedLocations();
      _showSuccessMessage('Ubicación guardada exitosamente');
    } catch (e) {
      print('Error saving location: $e');
      _showErrorMessage('Error al guardar la ubicación');
    }
  }

  void _onLocationEdit(SavedLocation location) {
    // TODO: Implementar edición de ubicación
    _showInfoMessage('Funcionalidad de edición próximamente');
  }

  void _onLocationDelete(SavedLocation location) async {
    try {
      await _storageService.deleteLocation(location.id);
      await _loadSavedLocations();
      _showSuccessMessage('Ubicación eliminada');
    } catch (e) {
      print('Error deleting location: $e');
      _showErrorMessage('Error al eliminar la ubicación');
    }
  }

  void _onLocationTap(SavedLocation location) {
    _centerMapOnLocation(location.position);
  }

  void _centerMapOnCurrentLocation() {
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
      );
    }
  }

  void _centerMapOnLocation(LatLng location) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
  }

  void _showLocationDetails(SavedLocation location) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        location.type.icon,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            location.type.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (location.description != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    location.description!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${location.position.latitude.toStringAsFixed(6)}, ${location.position.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _onOrderMarkerTap(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pedido #${order.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${order.clientName}'),
            Text('Teléfono: ${order.clientPhone}'),
            Text('Dirección: ${order.address}'),
            Text('Total: Bs. ${order.totalAmount.toStringAsFixed(2)}'),
            Text('Estado: ${order.statusText}'),
            const SizedBox(height: 8),
            const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...order.items.map((item) => Text('• ${item.name} x${item.quantity}')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToDeliveryManagement();
            },
            child: const Text('Ver Detalles'),
          ),
        ],
      ),
    );
  }

  void _navigateToDeliveryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const delivery_screen.DeliveryManagementScreen(),
      ),
    ).then((_) {
      // Recargar datos cuando regrese de la pantalla de gestión
      _loadPendingOrders();
    });
  }
  void _navigateToOptimizedRoute() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const route_screen.RouteMapScreen(),
      ),
    ).then((_) {
      // Recargar datos cuando regrese
      _loadPendingOrders();
    });
  }


  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleRouteVisualization() async {
    setState(() {
      _showRouteVisualization = !_showRouteVisualization;
      _isLoadingRoute = true;
    });

    if (_showRouteVisualization) {
      try {
        // Obtener rutas guardadas
        final routes = await _deliveryService.getRoutes();
        if (routes.isNotEmpty) {
          final activeRoute = routes.first; // Usar la primera ruta disponible

          setState(() {
            _activeRoute = activeRoute;
          });

          // Generar marcadores de la ruta
          if (_currentLocation != null) {
            final routeMarkers = _routeVisualizationService.generateRouteMarkers(
              deliveryRoute: activeRoute,
              startLocation: _currentLocation!,
              onOrderTap: _onOrderMarkerTap,
            );

            // Generar polylines de la ruta
            final routePolylines = await _routeVisualizationService.generateRoutePolylines(
              deliveryRoute: activeRoute,
              startLocation: _currentLocation!,
            );

            setState(() {
              _markers = routeMarkers;
              _polylines = routePolylines;
            });

            // Animar cámara para mostrar toda la ruta
            if (_mapController != null) {
              await _routeVisualizationService.animateCameraToShowRoute(
                mapController: _mapController!,
                deliveryRoute: activeRoute,
                startLocation: _currentLocation!,
              );
            }

            _showSuccessMessage('Ruta visualizada en el mapa');
          }
        } else {
          _showInfoMessage('No hay rutas disponibles. Genera una ruta primero.');
          setState(() {
            _showRouteVisualization = false;
          });
        }
      } catch (e) {
        print('Error loading route visualization: $e');
        _showErrorMessage('Error al cargar la visualización de ruta');
        setState(() {
          _showRouteVisualization = false;
        });
      }
    } else {
      // Ocultar visualización de ruta y volver a marcadores normales
      setState(() {
        _activeRoute = null;
        _polylines.clear();
      });
      _updateMarkers(); // Volver a los marcadores normales
      _showInfoMessage('Visualización de ruta ocultada');
    }

    setState(() {
      _isLoadingRoute = false;
    });
  }

  Future<void> _loadActiveRoute() async {
    try {
      final routes = await _deliveryService.getRoutes();
      if (routes.isNotEmpty) {
        setState(() {
          _activeRoute = routes.first;
        });
      }
    } catch (e) {
      print('Error loading active route: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Mapa Interactivo',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isTablet ? 24 : 20,
          ),
        ),
        backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer.withOpacity(0.8),
                theme.colorScheme.surface.withOpacity(0.9),
              ],
            ),
          ),
        ),
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
          SizedBox(width: isTablet ? 16 : 8),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
                    ),
                    SizedBox(height: isTablet ? 24 : 16),
                    Text(
                      'Cargando mapa...',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              )
              : Stack(
                children: [
                  // Google Map with optimized settings
                  Container(
                    child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target:
                            _currentLocation ?? const LatLng(-17.8146, -63.1561),
                        zoom: isTablet ? 15 : 14,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      onTap: _onMapTap,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: true,
                      rotateGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      // Configuraciones optimizadas para evitar errores de renderizado
                      buildingsEnabled: false,
                      trafficEnabled: false,
                      indoorViewEnabled: false,
                      // Estilo del mapa
                      mapType: MapType.normal,
                      style: theme.brightness == Brightness.dark
                          ? _darkMapStyle
                          : null,
                    ),
                  ),

                  // Panel de ubicaciones guardadas
                  LocationListPanel(
                    locations: _savedLocations,
                    onLocationTap: _onLocationTap,
                    onLocationEdit: _onLocationEdit,
                    onLocationDelete: _onLocationDelete,
                  ),

                  // Botón de gestión de entregas
                  Positioned(
                    bottom: isTablet ? 200 : 180,
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
                        heroTag: "delivery_management",
                        onPressed: _navigateToDeliveryManagement,
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: theme.colorScheme.onSecondary,
                        elevation: 0,
                        child: Icon(
                          Icons.local_shipping,
                          size: isTablet ? 28 : 24,
                        ),
                      ),
                    ),
                  ),

                  // Botón para alternar marcadores de entrega
                  Positioned(
                    bottom: isTablet ? 260 : 240,
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
                        heroTag: "toggle_delivery_markers",
                        onPressed: () {
                          setState(() {
                            _showDeliveryMarkers = !_showDeliveryMarkers;
                          });
                          _updateMarkers();
                        },
                        backgroundColor: _showDeliveryMarkers
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.outline.withOpacity(0.3),
                        foregroundColor: _showDeliveryMarkers
                            ? theme.colorScheme.onTertiary
                            : theme.colorScheme.onSurface,
                        elevation: 0,
                        child: Icon(
                          _showDeliveryMarkers ? Icons.visibility : Icons.visibility_off,
                          size: isTablet ? 28 : 24,
                        ),
                      ),
                    ),
                  ),

                  // Información de pedidos pendientes
                  if (_pendingOrders.isNotEmpty)
                    Positioned(
                      top: kToolbarHeight + MediaQuery.of(context).padding.top + 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delivery_dining,
                              size: 16,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_pendingOrders.length} entregas pendientes',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Botón de ubicación actual - responsive
                  Positioned(
                    bottom: isTablet ? 140 : 120,
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
                        heroTag: "current_location",
                        onPressed: _getCurrentLocation,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                        elevation: 0,
                        child:
                            _isLoadingLocation
                                ? SizedBox(
                                  width: isTablet ? 24 : 20,
                                  height: isTablet ? 24 : 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                )
                                : Icon(
                                  Icons.my_location_rounded,
                                  size: isTablet ? 28 : 24,
                                ),
                      ),
                    ),
                  ),
                  // Botón de ruta optimizada (NUEVO)
                  Positioned(
                    bottom: isTablet ? 380 : 360,
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
                        heroTag: "optimized_route",
                        onPressed: _navigateToOptimizedRoute,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        child: Icon(
                          Icons.alt_route,
                          size: isTablet ? 28 : 24,
                        ),
                      ),
                    ),
                  ),


                  // Botón para alternar visualización de ruta
                  Positioned(
                    bottom: isTablet ? 320 : 300,
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
                        heroTag: "toggle_route_visualization",
                        onPressed: () {
                          _toggleRouteVisualization();
                        },
                        backgroundColor: _showRouteVisualization
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.outline.withOpacity(0.3),
                        foregroundColor: _showRouteVisualization
                            ? theme.colorScheme.onTertiary
                            : theme.colorScheme.onSurface,
                        elevation: 0,
                        child: _isLoadingRoute
                            ? SizedBox(
                              width: isTablet ? 24 : 20,
                              height: isTablet ? 24 : 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.onTertiary,
                                ),
                              ),
                            )
                            : Icon(
                              _showRouteVisualization ? Icons.route : Icons.directions_off,
                              size: isTablet ? 28 : 24,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  // Estilo de mapa oscuro
  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9e9e9e"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2c2c2c"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#000000"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3d3d3d"
      }
    ]
  }
]
''';
}
