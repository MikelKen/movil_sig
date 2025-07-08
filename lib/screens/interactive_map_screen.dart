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

class _InteractiveMapScreenState extends State<InteractiveMapScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();
  final DeliveryService _deliveryService = DeliveryService();
  final RouteVisualizationService _routeVisualizationService = RouteVisualizationService();
  StorageService? _storageService;

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
  bool _mapInitialized = false;
  String? _errorMessage;

  // Optimizaciones para rendimiento
  static const CameraPosition _santaCruzPosition = CameraPosition(
    target: LatLng(-17.8146, -63.1561),
    zoom: 12.0,
  );

  // Timer para debounce de actualizaciones
  Timer? _debounceTimer;
  Completer<GoogleMapController> _mapCompleter = Completer();

  // Estilo de mapa oscuro optimizado
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
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [{"color": "#757575"}]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [{"color": "#484848"}]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [{"color": "#000000"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _mapController != null) {
      // Refrescar el mapa cuando la app vuelve al primer plano
      _refreshMap();
    }
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _storageService = await StorageService.getInstance();

      // Cargar datos en paralelo para mejor rendimiento
      await Future.wait([
        _loadSavedLocations(),
        _loadPendingOrders(),
        _getCurrentLocation(),
      ]);

    } catch (e) {
      debugPrint('Error initializing services: $e');
      setState(() {
        _errorMessage = 'Error al inicializar la aplicación: ${e.toString()}';
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
      if (locationData != null && mounted) {
        setState(() {
          _currentLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
        });
        if (_mapInitialized) {
          _centerMapOnCurrentLocation();
        }
      } else {
        // Usar ubicación por defecto si no se puede obtener la actual
        setState(() {
          _currentLocation = const LatLng(-17.8146, -63.1561); // Santa Cruz
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _currentLocation = const LatLng(-17.8146, -63.1561); // Santa Cruz
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _isLoading = false;
        });
        _updateMarkersDebounced();
      }
    }
  }

  Future<void> _loadSavedLocations() async {
    try {
      if (_storageService != null) {
        final locations = await _storageService!.getSavedLocations();
        if (mounted) {
          setState(() {
            _savedLocations = locations;
          });
          _updateMarkersDebounced();
        }
      }
    } catch (e) {
      debugPrint('Error loading saved locations: $e');
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      final orders = await _deliveryService.getPendingOrders();
      if (mounted) {
        setState(() {
          _pendingOrders = orders;
        });
        _updateMarkersDebounced();
      }
    } catch (e) {
      debugPrint('Error loading pending orders: $e');
    }
  }

  void _updateMarkersDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _updateMarkers();
      }
    });
  }

  void _updateMarkers() {
    if (!mounted) return;

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
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case LocationType.restaurant:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      case LocationType.shopping:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      case LocationType.hospital:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose);
      case LocationType.school:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      case LocationType.gas_station:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    if (!mounted) return;

    try {
      _mapController = controller;
      _mapCompleter.complete(controller);

      setState(() {
        _mapInitialized = true;
      });

      // Aplicar estilo de mapa si es modo oscuro
      if (Theme.of(context).brightness == Brightness.dark) {
        await controller.setMapStyle(_darkMapStyle);
      }

      // Centrar en la ubicación actual si está disponible
      if (_currentLocation != null) {
        _centerMapOnCurrentLocation();
      }

      debugPrint('Mapa interactivo inicializado correctamente');
    } catch (e) {
      debugPrint('Error al inicializar el mapa: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar el mapa. Verifica tu conexión a internet.';
        });
      }
    }
  }

  Future<void> _refreshMap() async {
    if (_mapController != null && mounted) {
      try {
        // Refrescar estilo de mapa
        if (Theme.of(context).brightness == Brightness.dark) {
          await _mapController!.setMapStyle(_darkMapStyle);
        } else {
          await _mapController!.setMapStyle(null);
        }
      } catch (e) {
        debugPrint('Error refreshing map: $e');
      }
    }
  }

  void _onMapTap(LatLng position) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AddLocationDialog(
        position: position,
        onLocationSaved: _onLocationSaved,
      ),
    );
  }

  void _onMarkerTap(SavedLocation location) {
    _showLocationDetails(location);
  }

  Future<void> _onLocationSaved(SavedLocation location) async {
    try {
      if (_storageService != null) {
        await _storageService!.saveLocation(location);
        await _loadSavedLocations();
        _showSuccessMessage('Ubicación guardada exitosamente');
      }
    } catch (e) {
      debugPrint('Error saving location: $e');
      _showErrorMessage('Error al guardar la ubicación');
    }
  }

  void _onLocationEdit(SavedLocation location) {
    _showInfoMessage('Funcionalidad de edición próximamente');
  }

  Future<void> _onLocationDelete(SavedLocation location) async {
    try {
      if (_storageService != null) {
        await _storageService!.deleteLocation(location.id);
        await _loadSavedLocations();
        _showSuccessMessage('Ubicación eliminada');
      }
    } catch (e) {
      debugPrint('Error deleting location: $e');
      _showErrorMessage('Error al eliminar la ubicación');
    }
  }

  void _onLocationTap(SavedLocation location) {
    _centerMapOnLocation(location.position);
  }

  void _centerMapOnCurrentLocation() {
    if (_currentLocation != null && _mapController != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
      );
    }
  }

  void _centerMapOnLocation(LatLng location) {
    if (_mapController != null && mounted) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
    }
  }

  void _showLocationDetails(SavedLocation location) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
      if (mounted) {
        _loadPendingOrders();
      }
    });
  }

  void _navigateToOptimizedRoute() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const route_screen.RouteMapScreen(),
      ),
    ).then((_) {
      if (mounted) {
        _loadPendingOrders();
      }
    });
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;
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
        final routes = await _deliveryService.getRoutes();
        if (routes.isNotEmpty && mounted) {
          final activeRoute = routes.first;

          setState(() {
            _activeRoute = activeRoute;
          });

          if (_currentLocation != null) {
            final routeMarkers = _routeVisualizationService.generateRouteMarkers(
              deliveryRoute: activeRoute,
              startLocation: _currentLocation!,
              onOrderTap: _onOrderMarkerTap,
            );

            final routePolylines = await _routeVisualizationService.generateRoutePolylines(
              deliveryRoute: activeRoute,
              startLocation: _currentLocation!,
            );

            if (mounted) {
              setState(() {
                _markers = routeMarkers;
                _polylines = routePolylines;
              });

              if (_mapController != null) {
                await _routeVisualizationService.animateCameraToShowRoute(
                  mapController: _mapController!,
                  deliveryRoute: activeRoute,
                  startLocation: _currentLocation!,
                );
              }

              _showSuccessMessage('Ruta visualizada en el mapa');
            }
          }
        } else {
          _showInfoMessage('No hay rutas disponibles. Genera una ruta primero.');
          setState(() {
            _showRouteVisualization = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading route visualization: $e');
        _showErrorMessage('Error al cargar la visualización de ruta');
        setState(() {
          _showRouteVisualization = false;
        });
      }
    } else {
      setState(() {
        _activeRoute = null;
        _polylines.clear();
      });
      _updateMarkers();
      _showInfoMessage('Visualización de ruta ocultada');
    }

    if (mounted) {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error al cargar el mapa',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Verifica tu conexión a internet y la configuración de la API de Google Maps',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializeServices();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mapa Interactivo'),
        ),
        body: _buildErrorWidget(),
      );
    }

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
      body: _isLoading
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
                // Google Map optimizado
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation ?? const LatLng(-17.8146, -63.1561),
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
                  buildingsEnabled: false,
                  trafficEnabled: false,
                  indoorViewEnabled: false,
                  mapType: MapType.normal,
                ),

                // Panel de ubicaciones guardadas
                LocationListPanel(
                  locations: _savedLocations,
                  onLocationTap: _onLocationTap,
                  onLocationEdit: _onLocationEdit,
                  onLocationDelete: _onLocationDelete,
                ),

                // Botones de acción flotantes
                Positioned(
                  bottom: isTablet ? 200 : 180,
                  right: isTablet ? 32 : 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón para alternar marcadores de entrega
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

                      // Botón de gestión de entregas
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
                      child: Icon(
                        Icons.my_location,
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
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_pendingOrders.length} entregas pendientess',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
