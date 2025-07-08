import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sig/providers/dio_provider.dart';
import '../models/order.dart';
import '../models/delivery_route.dart';
import '../services/delivery_service.dart';
import '../services/route_optimization_service.dart';
import '../widgets/order_card.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DeliveryService _deliveryService = DeliveryService();
  final DioProvider _dioProvider = DioProvider();

  List<Order> _allOrders = [];
  List<Order> _pendingOrders = [];
  DeliveryRoute? _currentRoute;
  DeliveryStats? _stats;
  bool _isLoading = true;
  bool _isConnectedToBackend = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

        // Obtener los pedidos ya procesados
        final orders = await _deliveryService.getOrders();
        final pendingOrders = await _deliveryService.getPendingOrders();
        final stats = await _deliveryService.getDeliveryStats();

        setState(() {
          _allOrders = orders;
          _pendingOrders = pendingOrders;
          _stats = stats;
          _isLoading = false;
        });

        print('📊 Estadísticas: ${stats.totalOrders} total, ${stats.pendingOrders} pendientes');
      } else {
        print('⚠️ No se pudieron cargar datos del backend, usando datos locales');
        _isConnectedToBackend = false;

        // Fallback a datos locales
        final orders = await _deliveryService.getOrders();
        final pendingOrders = await _deliveryService.getPendingOrders();
        final stats = await _deliveryService.getDeliveryStats();

        setState(() {
          _allOrders = orders;
          _pendingOrders = pendingOrders;
          _stats = stats;
          _isLoading = false;
        });

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
                  _buildStatCard(
                    'Ingresos Hoy',
                    'Bs. ${_stats!.totalRevenue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pendingOrders.isNotEmpty ? _generateOptimalRoute : null,
                    icon: const Icon(Icons.route),
                    label: const Text('Generar Ruta Óptima'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),

            if (_currentRoute != null) ...[
              const SizedBox(height: 16),
              _buildCurrentRouteCard(),
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

  Widget _buildCurrentRouteCard() {
    if (_currentRoute == null) return const SizedBox.shrink();

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
                  'Ruta Actual',
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
                    '${_currentRoute!.completedOrders}/${_currentRoute!.totalOrders}',
                  ),
                ),
                Expanded(
                  child: _buildRouteInfo(
                    'Distancia',
                    _currentRoute!.formattedDistance,
                  ),
                ),
                Expanded(
                  child: _buildRouteInfo(
                    'Tiempo Est.',
                    _currentRoute!.formattedDuration,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _currentRoute!.progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _currentRoute!.progress == 1.0 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Progreso: ${(_currentRoute!.progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optimización de Ruta',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Genera la ruta más eficiente para entregar todos los pedidos pendientes, considerando distancia y tiempo de viaje.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pendingOrders.isNotEmpty ? _generateOptimalRoute : null,
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(_pendingOrders.isEmpty
                              ? 'No hay pedidos pendientes'
                              : 'Generar Ruta Óptima (${_pendingOrders.length} pedidos)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_currentRoute != null) ...[
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
                            'Secuencia de Entregas',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text('${_currentRoute!.orders.length} paradas'),
                            backgroundColor: Colors.blue.shade100,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _currentRoute!.orders.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final order = _currentRoute!.orders[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: order.status == OrderStatus.entregado ? Colors.green : Colors.orange,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(order.clientName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order.address),
                                  Text(
                                    'Total: Bs. ${order.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  // ✅ FIX: Verificar null safety para observations
                                  if (order.observations != null && order.observations!.isNotEmpty)
                                    Text(
                                      'Obs: ${order.observations}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: order.status == OrderStatus.entregado
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : IconButton(
                                onPressed: () => _markOrderAsDelivered(order),
                                icon: const Icon(Icons.check_circle_outline),
                                tooltip: 'Marcar como entregado',
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
          ],
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

  Future<void> _generateOptimalRoute() async {
    if (_pendingOrders.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Ubicación de inicio (centro de Santa Cruz)
      const startLocation = LatLng(-17.8146, -63.1561);

      print('🗺️ Generando ruta óptima para ${_pendingOrders.length} pedidos...');

      final routeOptimizationService = RouteOptimizationService();
      final route = await routeOptimizationService.optimizeDeliveryRoute(
        startLocation: startLocation,
        orders: _pendingOrders,
      );

      print('✅ Ruta generada: ${route.totalDistance.toStringAsFixed(2)} km, '
          '${route.estimatedDuration} minutos');

      // Actualizar estado de pedidos a "en ruta"
      for (final order in _pendingOrders) {
        await _deliveryService.updateOrderStatus(order.id, OrderStatus.enRuta);
      }

      // Guardar la ruta
      await _deliveryService.saveRoute(route);

      setState(() {
        _currentRoute = route;
        _isLoading = false;
      });

      // Cambiar a la pestaña de ruta óptima
      _tabController.animateTo(2);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Ruta óptima generada: ${route.orders.length} paradas, '
                    '${route.totalDistance.toStringAsFixed(1)} km'
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ver Ruta',
              onPressed: () => _tabController.animateTo(2),
            ),
          ),
        );
      }

      // Recargar datos
      await _loadData();
    } catch (e) {
      print('❌ Error al generar ruta: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar ruta: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _generateOptimalRoute,
            ),
          ),
        );
      }
    }
  }

  Future<void> _markOrderAsDelivered(Order order) async {
    try {
      print('📦 Marcando pedido ${order.id} como entregado...');

      await _deliveryService.updateOrderStatus(order.id, OrderStatus.entregado);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido de ${order.clientName} marcado como entregado'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Recargar datos para actualizar la interfaz
      await _loadData();
    } catch (e) {
      print('❌ Error al actualizar pedido: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}