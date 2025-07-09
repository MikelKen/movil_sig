// screens/active_navigation_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../models/enhanced_route_models.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';

class ActiveNavigationScreen extends StatefulWidget {
  final EnhancedDeliveryRoute route;

  const ActiveNavigationScreen({
    super.key,
    required this.route,
  });

  @override
  State<ActiveNavigationScreen> createState() => _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState extends State<ActiveNavigationScreen> {
  GoogleMapController? _mapController;
  final NavigationService _navigationService = NavigationService();
  final LocationService _locationService = LocationService();

  StreamSubscription<NavigationState>? _navigationSubscription;
  StreamSubscription<String>? _instructionSubscription;

  NavigationState? _currentNavigationState;
  String? _currentInstruction;
  LatLng? _currentLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isInitializing = true;
  bool _isPaused = false;

  // Colores del tema oscuro azulado
  static const Color _primaryDark = Color(0xFF1A1A2E);
  static const Color _secondaryDark = Color(0xFF16213E);
  static const Color _accentBlue = Color(0xFF0F3460);
  static const Color _lightBlue = Color(0xFF533A7B);
  static const Color _transparentDark = Color(0x88000000);
  static const Color _transparentBlue = Color(0x661A1A2E);

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _navigationSubscription?.cancel();
    _instructionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    try {
      // Inicializar servicios
      await _navigationService.initializeTTS();

      // Obtener ubicación actual
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      }

      // Configurar listeners
      _setupNavigationListeners();

      // Iniciar navegación automáticamente
      await _navigationService.startNavigation(widget.route);

      // Configurar mapa inicial
      _setupInitialMap();

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      print('❌ Error inicializando navegación: $e');
      _showMessage('Error al iniciar navegación: $e', isError: true);
      Navigator.pop(context);
    }
  }

  void _setupNavigationListeners() {
    // Escuchar estado de navegación
    _navigationSubscription = _navigationService.navigationStream.listen(
          (state) {
        if (mounted) {
          setState(() {
            _currentNavigationState = state;
          });

          // Si la navegación se detiene, volver a la pantalla anterior
          if (!state.isNavigating && !_isPaused) {
            Navigator.pop(context);
            return;
          }

          // Actualizar marcadores y centrar mapa
          if (state.currentLocation != null) {
            _currentLocation = state.currentLocation;
            _updateMapForNavigation();
          }
        }
      },
    );

    // Escuchar instrucciones
    _instructionSubscription = _navigationService.instructionStream.listen(
          (instruction) {
        if (mounted) {
          setState(() {
            _currentInstruction = instruction;
          });
        }
      },
    );
  }

  void _setupInitialMap() {
    _updateMapMarkersAndPolylines();
  }

  void _updateMapForNavigation() {
    if (_currentLocation != null && _mapController != null) {
      // Centrar mapa en ubicación actual con zoom alto para navegación
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 18),
      );
    }
    _updateMapMarkersAndPolylines();
  }

  void _updateMapMarkersAndPolylines() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Marcador de ubicación actual
    if (_currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(
            title: 'Mi Ubicación',
            snippet: 'Navegando...',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Marcadores de destinos
    if (_currentNavigationState != null) {
      for (int i = 0; i < widget.route.stopInfos.length; i++) {
        final stopInfo = widget.route.stopInfos[i];
        final isCurrentDestination = i == _currentNavigationState!.currentStopIndex;
        final isCompleted = i < _currentNavigationState!.currentStopIndex;

        markers.add(
          Marker(
            markerId: MarkerId('destination_${stopInfo.order.id}'),
            position: stopInfo.location,
            infoWindow: InfoWindow(
              title: isCurrentDestination
                  ? '🎯 ${stopInfo.order.clientName} (Actual)'
                  : '${stopInfo.sequence}. ${stopInfo.order.clientName}',
              snippet: isCompleted
                  ? '✅ Completado'
                  : stopInfo.order.address,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isCompleted
                  ? BitmapDescriptor.hueGreen
                  : isCurrentDestination
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueOrange,
            ),
          ),
        );
      }
    }

    // Polyline de la ruta
    if (widget.route.polylinePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('navigation_route'),
          points: widget.route.polylinePoints,
          color: const Color(0xFF64B5F6),
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  Future<void> _pauseNavigation() async {
    try {
      setState(() {
        _isPaused = true;
      });
      await _navigationService.stopNavigation();
      _showMessage('Navegación pausada');
      print('✅ Navegación pausada exitosamente');
    } catch (e) {
      print('❌ Error pausando navegación: $e');
      setState(() {
        _isPaused = false;
      });
    }
  }

  Future<void> _resumeNavigation() async {
    try {
      print('🔄 Intentando reanudar navegación...');
      setState(() {
        _isPaused = false;
      });
      await _navigationService.startNavigation(widget.route);
      _showMessage('Navegación reanudada');
      print('✅ Navegación reanudada exitosamente');
    } catch (e) {
      print('❌ Error reanudando navegación: $e');
      _showMessage('Error al reanudar navegación: $e', isError: true);
      setState(() {
        _isPaused = true;
      });
    }
  }

  Future<void> _stopNavigationAndExit() async {
    final shouldStop = await _showStopConfirmationDialog();
    if (shouldStop) {
      await _navigationService.stopNavigation();
      Navigator.pop(context, 'stopped');
    }
  }

  Future<bool> _showStopConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _secondaryDark,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.amber),
            SizedBox(width: 8),
            Text('Detener Navegación', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que quieres detener la navegación?\n\n'
              'Perderás el progreso actual y tendrás que reiniciar desde la pantalla de rutas.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Detener'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: _primaryDark,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Iniciando navegación...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isPaused ? 'Navegación Pausada' : 'Navegación Activa',
          style: const TextStyle(fontSize: 18, color: Colors.white),
        ),
        backgroundColor: _isPaused ? Colors.amber.shade800 : _primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _stopNavigationAndExit,
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Detener y Salir',
        ),
        actions: [
          if (_currentNavigationState != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentNavigationState!.currentStopIndex + 1}/${_currentNavigationState!.totalStops}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentLocation != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation!, 18),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(-17.8146, -63.1561),
              zoom: 18,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            trafficEnabled: true,
          ),

          // Panel de información del destino actual
          if (_currentNavigationState?.currentStop != null && !_isPaused)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildCurrentDestinationCard(),
            ),

          // Panel de instrucciones
          if (_currentInstruction != null && !_isPaused)
            Positioned(
              top: _currentNavigationState?.currentStop != null ? 200 : 80,
              left: 16,
              right: 16,
              child: _buildInstructionCard(),
            ),

          // Controles de navegación
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildNavigationControls(),
          ),

          // Botón de centrar ubicación
          Positioned(
            bottom: 200,
            right: 16,
            child: FloatingActionButton(
              heroTag: "center_location",
              onPressed: () {
                if (_currentLocation != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_currentLocation!, 18),
                  );
                }
              },
              backgroundColor: _accentBlue,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          // Indicador de pausa - SIN bloquear los controles
          if (_isPaused)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 250, // Dejar espacio para los controles de navegación
              child: Container(
                color: _transparentDark,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle, size: 80, color: Colors.amber),
                      SizedBox(height: 16),
                      Text(
                        'Navegación Pausada',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Usa los controles de abajo para continuar',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentDestinationCard() {
    final currentStop = _currentNavigationState!.currentStop!;
    final distanceText = _currentNavigationState!.distanceToDestination != null
        ? '${(_currentNavigationState!.distanceToDestination! / 1000).toStringAsFixed(2)} km'
        : 'Calculando...';

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${currentStop.sequence}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStop.order.clientName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currentStop.order.address,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.near_me, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text('Distancia: $distanceText'),
                const Spacer(),
                Icon(Icons.phone, size: 16, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(currentStop.order.clientPhone),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Card(
      color: _accentBlue,
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          color: _accentBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.directions, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _currentInstruction!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _isPaused ? Colors.amber.shade800 : _primaryDark,
            _isPaused ? Colors.amber.shade900 : _secondaryDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de progreso
              if (_currentNavigationState != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Progreso de Entregas',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: _currentNavigationState!.totalStops > 0
                                ? _currentNavigationState!.currentStopIndex /
                                _currentNavigationState!.totalStops
                                : 0.0,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_currentNavigationState!.currentStopIndex}/${_currentNavigationState!.totalStops} completadas',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Botones de control
              if (_isPaused)
                Container(
                  decoration: BoxDecoration(
                    color: _transparentDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            print('🔄 Botón Continuar presionado');
                            _resumeNavigation();
                          },
                          icon: const Icon(Icons.play_arrow, size: 24),
                          label: const Text(
                            'Continuar',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            print('🛑 Botón Detener presionado');
                            _stopNavigationAndExit();
                          },
                          icon: const Icon(Icons.stop, size: 24),
                          label: const Text(
                            'Detener',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_currentNavigationState != null)
                Row(
                  children: [
                    // Botón Anterior
                    if (_currentNavigationState!.currentStopIndex > 0)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigationService.goToPreviousStop(),
                          icon: const Icon(Icons.skip_previous),
                          label: const Text(''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _transparentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Colors.white12),
                          ),
                        ),
                      ),

                    if (_currentNavigationState!.currentStopIndex > 0)
                      const SizedBox(width: 8),

                    // Botón Completar
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _navigationService.completeCurrentStop(),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Completar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Botón Saltar
                    if (_currentNavigationState!.currentStopIndex <
                        _currentNavigationState!.totalStops - 1)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _navigationService.skipToNextStop(),
                          icon: const Icon(Icons.skip_next),
                          label: const Text(''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _transparentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: Colors.white12),
                          ),
                        ),
                      ),

                    const SizedBox(width: 8),

                    // Botón Pausar
                    FloatingActionButton(
                      heroTag: "pause_navigation",
                      onPressed: _pauseNavigation,
                      backgroundColor: Colors.amber.shade600,
                      child: const Icon(Icons.pause, color: Colors.white),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}