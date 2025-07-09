import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sig/providers/dio_provider.dart';
import 'package:sig/models/enhanced_route_models.dart';
import '../models/order.dart';
import '../services/delivery_service.dart' hide DeliveryStats;
import '../services/enhanced_delivery_service.dart';
import '../services/enhanced_route_optimization_service.dart'; // Agregado
import '../services/location_service.dart'; // Agregado
import '../widgets/order_card.dart';
import 'route_map_screen.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DeliveryService _deliveryService = DeliveryService();
  final EnhancedDeliveryService _enhancedDeliveryService = EnhancedDeliveryService();
  final EnhancedRouteOptimizationService _routeService = EnhancedRouteOptimizationService(); // Agregado
  final LocationService _locationService = LocationService(); // Agregado
  final DioProvider _dioProvider = DioProvider();

  List<Order> _allOrders = [];
  List<Order> _pendingOrders = [];
  EnhancedDeliveryRoute? _enhancedCurrentRoute;
  DeliveryStats? _stats;
  bool _isLoading = true;
  bool _isConnectedToBackend = false;
  bool _isOptimizing = false; // Agregado
  LatLng? _currentLocation; // Agregado

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _getCurrentLocation(); // Agregado
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Agregado: Obtener ubicación actual
  Future<void> _getCurrentLocation() async {
    try {
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });
      } else {
        setState(() {
          _currentLocation = const LatLng(-17.8146, -63.1561); // Santa Cruz por defecto
        });
      }
    } catch (e) {
      setState(() {
        _currentLocation = const LatLng(-17.8146, -63.1561);
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      print('=== CARGANDO DATOS ===');

      // Intentar cargar datos del backend primero
      final ordersFromApi = await _dioProvider.getOrders();

      if (ordersFromApi != null && ordersFromApi.isNotEmpty) {
        print('✅ Datos cargados desde el backend: ${ordersFromApi.length} pedidos');
        _isConnectedToBackend = true;

        // Procesar los pedidos del backend
        await _deliveryService.loadOrdersFromBackend(ordersFromApi);
        await _enhancedDeliveryService.loadOrdersFromBackend(ordersFromApi);

        // Obtener los pedidos ya procesados
        final orders = await _deliveryService.getOrders();
        final pendingOrders = await _deliveryService.getPendingOrders();
        final stats = await _enhancedDeliveryService.getDeliveryStats();

        // **MODIFICADO**: Siempre cargar ruta mejorada si existe
        final enhancedRoute = await _enhancedDeliveryService.getActiveEnhancedRoute();

        setState(() {
          _allOrders = orders;
          _pendingOrders = pendingOrders;
          _stats = stats;
          _enhancedCurrentRoute = enhancedRoute; // Esto se actualiza siempre
          _isLoading = false;
        });

        if (enhancedRoute != null) {
          print('📍 Ruta optimizada cargada en gestión: ${enhancedRoute.id}');
        }

        print('📊 Estadísticas: ${stats.totalOrders} total, ${stats.pendingOrders} pendientes');
      } else {
        print('⚠️ No se pudieron cargar datos del backend, usando datos locales');
        _isConnectedToBackend = false;

        // Fallback a datos locales
        final orders = await _deliveryService.getOrders();
        final pendingOrders = await _deliveryService.getPendingOrders();
        final stats = await _enhancedDeliveryService.getDeliveryStats();

        // **MODIFICADO**: Siempre cargar ruta mejorada si existe
        final enhancedRoute = await _enhancedDeliveryService.getActiveEnhancedRoute();

        setState(() {
          _allOrders = orders;
          _pendingOrders = pendingOrders;
          _stats = stats;
          _enhancedCurrentRoute = enhancedRoute; // Esto se actualiza siempre
          _isLoading = false;
        });

        if (enhancedRoute != null) {
          print('📍 Ruta optimizada cargada (local) en gestión: ${enhancedRoute.id}');
        }

        print('📱 Usando datos locales: ${orders.length} pedidos');
      }
    } catch (e) {
      print('❌ Error al cargar datos: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _loadData,
            ),
          ),
        );
      }
    }
  }

  // Agregado: Optimizar ruta desde DeliveryManagementScreen
  Future<void> _optimizeRoute() async {
    if (_pendingOrders.isEmpty) {
      _showMessage('No hay órdenes pendientes para optimizar', isError: true);
      return;
    }

    if (!_routeService.isApiKeyConfigured()) {
      _showMessage('API Key de Google Maps no configurada', isError: true);
      return;
    }

    if (_currentLocation == null) {
      _showMessage('No se pudo obtener la ubicación actual', isError: true);
      return;
    }

    setState(() {
      _isOptimizing = true;
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
      await _enhancedDeliveryService.saveEnhancedRoute(optimizedRoute);

      setState(() {
        _enhancedCurrentRoute = optimizedRoute;
        _isOptimizing = false;
      });

      _showMessage('Ruta optimizada generada exitosamente');

      // Cambiar a la pestaña de ruta óptima para mostrar el resultado
      _tabController.animateTo(2);
    } catch (e) {
      setState(() {
        _isOptimizing = false;
      });
      _showMessage('Error al optimizar ruta: $e', isError: true);
    }
  }

  // Agregado: Diálogo para seleccionar hora de inicio
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

  // Agregado: Navegar al mapa con ruta ya optimizada
  void _navigateToRouteMapWithOptimizedRoute() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RouteMapScreen(),
      ),
    ).then((_) {
      if (mounted) {
        // Solo recargar datos básicos para mantener el estado de la ruta
        _reloadRouteData();
      }
    });
  }

  Future<void> _reloadRouteData() async {
    try {
      final currentRoute = await _enhancedDeliveryService.getActiveEnhancedRoute();
      if (currentRoute != null && currentRoute.id == _enhancedCurrentRoute?.id) {
        // La ruta sigue siendo la misma, mantener estado
        print('✅ Estado de ruta mantenido después de regresar del mapa');
      } else if (currentRoute != null) {
        // Hay una ruta nueva o actualizada
        setState(() {
          _enhancedCurrentRoute = currentRoute;
        });
        print('🔄 Ruta actualizada después de regresar del mapa');
      } else {
        // No hay ruta
        setState(() {
          _enhancedCurrentRoute = null;
        });
        print('🧹 Ruta eliminada después de regresar del mapa');
      }

      // Actualizar pedidos pendientes por si han cambiado
      final pendingOrders = await _enhancedDeliveryService.getPendingOrders();
      setState(() {
        _pendingOrders = pendingOrders;
      });
    } catch (e) {
      print('❌ Error recargando datos de ruta: $e');
    }
  }

  // Navegar a la pantalla del mapa
  void _navigateToRouteMap() async {
    // Si no hay ruta optimizada y hay pedidos pendientes, optimizar automáticamente
    if (_enhancedCurrentRoute == null && _pendingOrders.isNotEmpty) {
      final shouldOptimize = await _showOptimizeConfirmationDialog();

      if (shouldOptimize == true) {
        // Optimizar ruta antes de ir al mapa
        await _optimizeRouteForMap();
      }
    }

    // Navegar al mapa (con o sin optimización)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RouteMapScreen(),
      ),
    ).then((_) {
      // Recargar datos cuando regrese del mapa
      _loadData();
    });
  }

  // Agregado: Mostrar mensaje
  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Nuevo método para mostrar diálogo de confirmación de optimización
  Future<bool?> _showOptimizeConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Optimizar Ruta'),
        content: Text(
            'No hay ruta optimizada. ¿Deseas optimizar automáticamente los ${_pendingOrders.length} pedidos pendientes antes de ir al mapa?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Solo ir al Mapa'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Optimizar y ir al Mapa'),
          ),
        ],
      ),
    );
  }

  // Nuevo método para optimizar ruta específicamente antes de ir al mapa
  Future<void> _optimizeRouteForMap() async {
    if (_pendingOrders.isEmpty) {
      _showMessage('No hay órdenes pendientes para optimizar', isError: true);
      return;
    }

    if (!_routeService.isApiKeyConfigured()) {
      _showMessage('API Key de Google Maps no configurada', isError: true);
      return;
    }

    if (_currentLocation == null) {
      _showMessage('No se pudo obtener la ubicación actual', isError: true);
      return;
    }

    // Mostrar loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Optimizando ruta para el mapa...'),
          ],
        ),
      ),
    );

    try {
      // Mostrar diálogo para seleccionar hora de inicio
      Navigator.pop(context); // Cerrar loading dialog
      final startTime = await _showStartTimeDialog();

      if (startTime == null) {
        return; // Usuario canceló
      }

      // Mostrar loading dialog nuevamente
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generando ruta optimizada...'),
            ],
          ),
        ),
      );

      final optimizedRoute = await _routeService.optimizeDeliveryRouteEnhanced(
        startLocation: _currentLocation!,
        orders: _pendingOrders,
        startTime: startTime,
      );

      // Guardar la ruta optimizada
      await _enhancedDeliveryService.saveEnhancedRoute(optimizedRoute);

      setState(() {
        _enhancedCurrentRoute = optimizedRoute;
      });

      Navigator.pop(context); // Cerrar loading dialog
      _showMessage('Ruta optimizada generada exitosamente para el mapa');

      print('💾 Ruta optimizada para mapa: ${optimizedRoute.id}');
    } catch (e) {
      Navigator.pop(context); // Cerrar loading dialog en caso de error
      _showMessage('Error al optimizar ruta: $e', isError: true);
      print('❌ Error optimizando para mapa: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestión de Entregas'),
            if (!_isLoading) ...[
              Text(
                _isConnectedToBackend ? '🟢 Conectado al servidor' : '🟡 Modo offline',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar datos',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Pendientes'),
            Tab(icon: Icon(Icons.route), text: 'Ruta Óptima'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboard(),
          _buildPendingOrders(),
          _buildOptimalRoute(),
          _buildOrderHistory(),
        ],
      ),

    );
  }

  Widget _buildDashboard() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de estado de conexión
            if (!_isConnectedToBackend) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.offline_bolt, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trabajando en modo offline. Los datos se sincronizarán cuando se restablezca la conexión.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Text(
              'Resumen del Día',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (_stats != null) ...[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    'Entregas Hoy',
                    _stats!.deliveredToday.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Pendientes',
                    _stats!.pendingOrders.toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'En Ruta',
                    _stats!.inRouteOrders.toString(),
                    Icons.local_shipping,
                    Colors.blue,
                  ),

                ],
              ),
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pendingOrders.isNotEmpty ? _navigateToRouteMap : null,
                    icon: const Icon(Icons.route),
                    label: const Text('Ir a Optimización Avanzada'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),

            if (_enhancedCurrentRoute != null) ...[
              const SizedBox(height: 16),
              _buildEnhancedCurrentRouteCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedCurrentRouteCard() {
    if (_enhancedCurrentRoute == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Ruta Optimizada Avanzada',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRouteInfo(
                    'Entregas',
                    '${_enhancedCurrentRoute!.totalOrders}',
                  ),
                ),
                Expanded(
                  child: _buildRouteInfo(
                    'Distancia',
                    _enhancedCurrentRoute!.formattedDistance,
                  ),
                ),
                Expanded(
                  child: _buildRouteInfo(
                    'Duración',
                    _enhancedCurrentRoute!.formattedDuration,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Horario: ${_enhancedCurrentRoute!.formattedPlannedStartTime} - ${_enhancedCurrentRoute!.formattedEstimatedEndTime}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingOrders() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay pedidos pendientes',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (!_isConnectedToBackend) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Conectar al servidor'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Header con información
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Icon(Icons.pending_actions, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '${_pendingOrders.length} pedidos pendientes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                if (_isConnectedToBackend)
                  Icon(Icons.cloud_done, color: Colors.green.shade600, size: 20)
                else
                  Icon(Icons.cloud_off, color: Colors.orange.shade600, size: 20),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _pendingOrders.length,
              itemBuilder: (context, index) {
                return OrderCard(
                  order: _pendingOrders[index],
                  onStatusChanged: _loadData,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimalRoute() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card de optimización - Modificado para incluir botón de optimizar aquí también
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Botón para optimizar ruta
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pendingOrders.isEmpty || _isOptimizing ? null : _optimizeRoute,
                          icon: _isOptimizing
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.auto_fix_high),
                          label: Text(_isOptimizing
                              ? 'Optimizando...'
                              : 'Orden de Pedidos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Botón para ir al mapa - MEJORADO
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToRouteMap,
                          icon: const Icon(Icons.map),
                          label: Text(_enhancedCurrentRoute != null
                              ? 'Ver en Mapa'
                              : 'Ir al Mapa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _enhancedCurrentRoute != null ? Colors.green : Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),


                ],
              ),
            ),
          ),

          // Mostrar ruta mejorada si existe
          if (_enhancedCurrentRoute != null) ...[
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Secuencia de Entregas Optimizada',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        ],
                      ),
                      const SizedBox(height: 12),

                      // Resumen de la ruta
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSummaryItem(
                                Icons.local_shipping,
                                '${_enhancedCurrentRoute!.totalOrders} entregas',
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                Icons.straighten,
                                _enhancedCurrentRoute!.formattedDistance,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryItem(
                                Icons.schedule,
                                '${_enhancedCurrentRoute!.formattedPlannedStartTime} - ${_enhancedCurrentRoute!.formattedEstimatedEndTime}',
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Lista de paradas optimizada
                      Expanded(
                        child: ListView.separated(
                          itemCount: _enhancedCurrentRoute!.stopInfos.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final stopInfo = _enhancedCurrentRoute!.stopInfos[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Número de secuencia
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${stopInfo.sequence}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Información de la parada
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stopInfo.order.clientName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          stopInfo.order.address,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                stopInfo.formattedEstimatedArrival,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue.shade800,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                stopInfo.formattedDistanceFromPrevious,
                                                style: TextStyle(
                                                  fontSize: 10,
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

                                  // Valor del pedido e info
                                  Column(
                                    children: [
                                      Text(
                                        'Bs. ${stopInfo.order.totalAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _showEnhancedOrderDetails(stopInfo),
                                        icon: const Icon(Icons.info_outline),
                                        iconSize: 16,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
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
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.route_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay ruta optimizada',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pendingOrders.isNotEmpty
                            ? 'Optimiza los ${_pendingOrders.length} pedidos pendientes para generar una secuencia de entregas eficiente'
                            : 'No hay pedidos pendientes para optimizar',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Mostrar detalles mejorados del pedido (similar al RouteMapScreen)
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
                          _navigateToRouteMapWithOptimizedRoute();
                        },
                        icon: const Icon(Icons.map),
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

  Widget _buildOrderHistory() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final completedOrders = _allOrders.where((order) =>
    order.status == OrderStatus.entregado ||
        order.status == OrderStatus.noEntregado ||
        order.status == OrderStatus.productoIncorrecto
    ).toList();

    if (completedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay entregas completadas',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (!_isConnectedToBackend) ...[
              const SizedBox(height: 8),
              const Text(
                'Conecta al servidor para ver el historial completo',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Header con estadísticas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  '${completedOrders.length} entregas completadas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                if (_stats != null)
                  Text(
                    'Hoy: ${_stats!.deliveredToday}',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: completedOrders.length,
              itemBuilder: (context, index) {
                return OrderCard(
                  order: completedOrders[index],
                  showActions: false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}