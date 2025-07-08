import 'dart:convert';
import 'package:dio/dio.dart';

class DioProvider {
  static const String _baseUrl = 'http://192.168.100.9:3000';
  late Dio _dio;

  DioProvider() {
    _dio = Dio();
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    // Interceptor para logging detallado
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false, // Cambiar a true para debug
        responseBody: false, // Cambiar a true para debug
        error: true,
        logPrint: (o) => print('🌐 DIO: $o'),
      ),
    );
  }

  // ===== MÉTODOS PARA ORDERS =====

  /// Obtener todos los pedidos formateados para Flutter
  Future<List<Map<String, dynamic>>?> getOrders() async {
    try {
      print('🔄 Obteniendo pedidos desde: $_baseUrl/orders/formatted');

      final response = await _dio.get('/orders/formatted');

      if (response.statusCode == 200 && response.data is List) {
        print("===================================");
        print(response);
        final List<Map<String, dynamic>> orders = response.data
            .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
            .toList();

        print('✅ Pedidos obtenidos exitosamente: ${orders.length}');

        // Log de algunos campos importantes para debug
        if (orders.isNotEmpty) {
          final firstOrder = orders.first;
          print('📋 Primer pedido: ${firstOrder['clientName']} - ${firstOrder['status']}');
        }

        return orders;
      } else {
        print('⚠️ Respuesta inesperada del servidor: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ Error de conexión al obtener pedidos:');
      print('   Tipo: ${e.type}');
      print('   Mensaje: ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      return null;
    } catch (error) {
      print('❌ Error inesperado al obtener pedidos: $error');
      return null;
    }
  }

  /// Obtener solo pedidos pendientes
  Future<List<Map<String, dynamic>>?> getPendingOrders() async {
    try {
      print('🔄 Obteniendo pedidos pendientes');

      final response = await _dio.get('/orders/pending');

      if (response.statusCode == 200 && response.data is List) {
        print("===================================");
        print(response);
        print("=====================================");
        final List<Map<String, dynamic>> orders = response.data
            .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
            .toList();

        print('✅ Pedidos pendientes obtenidos: ${orders.length}');
        return orders;
      }
      return null;
    } on DioException catch (e) {
      print('❌ Error al obtener pedidos pendientes: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado: $error');
      return null;
    }
  }

  /// Actualizar estado de un pedido
  Future<Map<String, dynamic>?> updateOrderStatus(
      String orderId,
      String status, {
        String? paymentMethod,
        String? observations,
      }) async {
    try {
      print('🔄 Actualizando pedido $orderId a estado: $status');

      final data = {
        'status': status,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (observations != null) 'observations': observations,
        if (status == 'entregado') 'deliveryTime': DateTime.now().toIso8601String(),
      };

      final response = await _dio.put('/orders/$orderId/status', data: data);

      if (response.statusCode == 200) {
        print('✅ Estado del pedido actualizado exitosamente');
        return response.data as Map<String, dynamic>;
      } else {
        print('⚠️ Error al actualizar pedido: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ Error de conexión al actualizar pedido: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado al actualizar pedido: $error');
      return null;
    }
  }

  /// Obtener estadísticas de entregas
  Future<Map<String, dynamic>?> getDeliveryStats() async {
    try {
      print('🔄 Obteniendo estadísticas de entregas');

      final response = await _dio.get('/orders/stats');

      if (response.statusCode == 200) {
        print('✅ Estadísticas obtenidas exitosamente');
        final stats = response.data as Map<String, dynamic>;
        print('📊 Stats: ${stats['totalOrders']} total, ${stats['pendingOrders']} pendientes');
        return stats;
      } else {
        print('⚠️ Error al obtener estadísticas: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ Error de conexión al obtener estadísticas: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado al obtener estadísticas: $error');
      return null;
    }
  }

  // ===== MÉTODOS PARA ROUTES =====

  /// Crear ruta optimizada
  Future<Map<String, dynamic>?> createOptimizedRoute(Map<String, dynamic> routeData) async {
    try {
      print('🔄 Creando ruta optimizada');
      print('📝 Datos de ruta: ${routeData.keys.join(', ')}');

      final response = await _dio.post('/routes/flutter', data: routeData);

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Ruta creada exitosamente');
        return response.data as Map<String, dynamic>;
      } else {
        print('⚠️ Error al crear ruta: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ Error de conexión al crear ruta: ${e.message}');
      if (e.response != null) {
        print('   Response data: ${e.response?.data}');
      }
      return null;
    } catch (error) {
      print('❌ Error inesperado al crear ruta: $error');
      return null;
    }
  }

  /// Obtener todas las rutas formateadas
  Future<List<Map<String, dynamic>>?> getRoutes() async {
    try {
      print('🔄 Obteniendo rutas');

      final response = await _dio.get('/routes/formatted');

      if (response.statusCode == 200 && response.data is List) {
        final List<Map<String, dynamic>> routes = response.data
            .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
            .toList();

        print('✅ Rutas obtenidas: ${routes.length}');
        return routes;
      }
      return null;
    } on DioException catch (e) {
      print('❌ Error al obtener rutas: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado: $error');
      return null;
    }
  }

  /// Obtener una ruta específica
  Future<Map<String, dynamic>?> getRoute(String routeId) async {
    try {
      print('🔄 Obteniendo ruta $routeId');

      final response = await _dio.get('/routes/$routeId/formatted');

      if (response.statusCode == 200) {
        print('✅ Ruta obtenida exitosamente');
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      print('❌ Error al obtener ruta: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado: $error');
      return null;
    }
  }

  /// Iniciar ruta
  Future<Map<String, dynamic>?> startRoute(String routeId) async {
    try {
      print('🔄 Iniciando ruta $routeId');

      final response = await _dio.put('/routes/$routeId/start');

      if (response.statusCode == 200) {
        print('✅ Ruta iniciada exitosamente');
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      print('❌ Error al iniciar ruta: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado: $error');
      return null;
    }
  }

  /// Finalizar ruta
  Future<Map<String, dynamic>?> endRoute(String routeId) async {
    try {
      print('🔄 Finalizando ruta $routeId');

      final response = await _dio.put('/routes/$routeId/end');

      if (response.statusCode == 200) {
        print('✅ Ruta finalizada exitosamente');
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      print('❌ Error al finalizar ruta: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado: $error');
      return null;
    }
  }

  // ===== MÉTODOS GENERALES =====

  /// Probar conexión con el servidor
  Future<bool> testConnection() async {
    try {
      print('🔄 Probando conexión con el servidor...');

      final response = await _dio.get('/health');

      if (response.statusCode == 200) {
        print('✅ Conexión exitosa con el servidor');
        final data = response.data as Map<String, dynamic>;
        print('🏥 Health check: ${data['status']} - ${data['service'] ?? 'Unknown'}');
        return true;
      } else {
        print('⚠️ Servidor responde pero con código: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      print('❌ Error de conexión: ${e.type} - ${e.message}');

      // Diferentes tipos de errores de conexión
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          print('   - Timeout de conexión');
          break;
        case DioExceptionType.receiveTimeout:
          print('   - Timeout de recepción');
          break;
        case DioExceptionType.connectionError:
          print('   - Error de conexión (¿servidor apagado?)');
          break;
        default:
          print('   - Error desconocido');
      }

      return false;
    } catch (error) {
      print('❌ Error inesperado: $error');
      return false;
    }
  }

  /// Obtener información del servidor
  Future<Map<String, dynamic>?> getServerInfo() async {
    try {
      final response = await _dio.get('/health');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } on DioException catch (e) {
      print('❌ Error al obtener info del servidor: ${e.message}');
      return null;
    } catch (error) {
      print('❌ Error inesperado: $error');
      return null;
    }
  }

  /// Cambiar la URL base (útil para testing)
  void setBaseUrl(String newBaseUrl) {
    print('🔧 Cambiando URL base a: $newBaseUrl');
    _dio.options.baseUrl = newBaseUrl;
  }

  /// Obtener la URL base actual
  String get baseUrl => _dio.options.baseUrl;
}