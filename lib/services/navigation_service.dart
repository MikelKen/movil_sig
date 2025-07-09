// services/navigation_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import '../models/enhanced_route_models.dart';
import '../config/api_config.dart';
import 'location_service.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  // TTS instance
  final FlutterTts _flutterTts = FlutterTts();

  // Location tracking
  final LocationService _locationService = LocationService();
  StreamSubscription<LocationData>? _locationSubscription;

  // Navigation state
  bool _isNavigating = false;
  EnhancedDeliveryRoute? _currentRoute;
  int _currentStopIndex = 0;
  LatLng? _currentLocation;
  List<NavigationInstruction> _currentInstructions = [];
  int _currentInstructionIndex = 0;

  // Thresholds
  static const double _arrivalThreshold = 50.0; // metros
  static const double _instructionThreshold = 100.0; // metros para próxima instrucción
  static const double _recalculateThreshold = 200.0; // metros para recalcular ruta

  // Controllers
  final StreamController<NavigationState> _navigationController =
  StreamController<NavigationState>.broadcast();
  final StreamController<String> _instructionController =
  StreamController<String>.broadcast();

  // Getters
  bool get isNavigating => _isNavigating;
  Stream<NavigationState> get navigationStream => _navigationController.stream;
  Stream<String> get instructionStream => _instructionController.stream;
  int get currentStopIndex => _currentStopIndex;
  EnhancedDeliveryRoute? get currentRoute => _currentRoute;

  /// Inicializar TTS
  Future<void> initializeTTS() async {
    try {
      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Configurar callbacks
      _flutterTts.setStartHandler(() {
        print("🔊 TTS iniciado");
      });

      _flutterTts.setCompletionHandler(() {
        print("🔊 TTS completado");
      });

      _flutterTts.setErrorHandler((msg) {
        print("❌ Error TTS: $msg");
      });

      print("✅ TTS inicializado correctamente");
    } catch (e) {
      print("❌ Error inicializando TTS: $e");
    }
  }

  /// Comenzar navegación
  Future<void> startNavigation(EnhancedDeliveryRoute route) async {
    try {
      if (_isNavigating) {
        print('⚠️ Ya hay una navegación activa, deteniéndola primero...');
        await stopNavigation();
      }

      _currentRoute = route;

      // Si no se ha empezado, comenzar desde el principio
      if (_currentStopIndex >= route.stopInfos.length) {
        _currentStopIndex = 0;
      }

      _isNavigating = true;
      _currentInstructionIndex = 0;

      // Inicializar TTS si no está configurado
      await initializeTTS();

      // Obtener ubicación actual
      final locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
      }

      // Obtener instrucciones para el segmento actual
      await _loadInstructionsForCurrentSegment();

      // Comenzar seguimiento de ubicación
      _startLocationTracking();

      // Anuncio de reanudación o inicio
      final currentStop = route.stopInfos[_currentStopIndex];
      if (_currentStopIndex == 0) {
        await _speak("Navegación iniciada. Dirigiéndose al primer destino: ${currentStop.order.clientName}");
      } else {
        await _speak("Navegación reanudada. Continuando hacia: ${currentStop.order.clientName}");
      }

      // Emitir estado inicial
      _emitNavigationState();

      print("🚀 Navegación iniciada/reanudada hacia parada ${_currentStopIndex + 1}/${route.stopInfos.length}");
    } catch (e) {
      print("❌ Error iniciando navegación: $e");
      await stopNavigation();
      rethrow;
    }
  }

  /// Detener navegación
  Future<void> stopNavigation() async {
    _isNavigating = false;
    _currentRoute = null;
    _currentStopIndex = 0;
    _currentInstructionIndex = 0;
    _currentInstructions.clear();

    await _locationSubscription?.cancel();
    _locationSubscription = null;

    await _speak("Navegación detenida");

    _emitNavigationState();
    print("🛑 Navegación detenida");
  }

  /// Marcar parada actual como completada y continuar
  Future<void> completeCurrentStop() async {
    if (!_isNavigating || _currentRoute == null) return;

    final currentStop = _currentRoute!.stopInfos[_currentStopIndex];

    await _speak("Entrega completada en ${currentStop.order.clientName}");

    _currentStopIndex++;
    _currentInstructionIndex = 0;

    if (_currentStopIndex >= _currentRoute!.stopInfos.length) {
      // Todas las entregas completadas
      await _speak("¡Felicitaciones! Todas las entregas han sido completadas exitosamente.");
      await stopNavigation();

      // Emitir estado final antes de detener
      _emitNavigationState();
      return;
    }

    // Continuar con la siguiente parada
    final nextStop = _currentRoute!.stopInfos[_currentStopIndex];
    await _loadInstructionsForCurrentSegment();

    await _speak("Dirigiéndose al siguiente destino: ${nextStop.order.clientName}");

    _emitNavigationState();
  }

  /// Saltar a la siguiente parada
  Future<void> skipToNextStop() async {
    if (!_isNavigating || _currentRoute == null) return;

    if (_currentStopIndex < _currentRoute!.stopInfos.length - 1) {
      _currentStopIndex++;
      _currentInstructionIndex = 0;

      final nextStop = _currentRoute!.stopInfos[_currentStopIndex];
      await _loadInstructionsForCurrentSegment();

      await _speak("Saltando al destino: ${nextStop.order.clientName}");
      _emitNavigationState();
    }
  }

  /// Ir a parada anterior
  Future<void> goToPreviousStop() async {
    if (!_isNavigating || _currentRoute == null) return;

    if (_currentStopIndex > 0) {
      _currentStopIndex--;
      _currentInstructionIndex = 0;

      final prevStop = _currentRoute!.stopInfos[_currentStopIndex];
      await _loadInstructionsForCurrentSegment();

      await _speak("Regresando al destino: ${prevStop.order.clientName}");
      _emitNavigationState();
    }
  }

  /// Cargar instrucciones para el segmento actual
  Future<void> _loadInstructionsForCurrentSegment() async {
    if (_currentRoute == null || _currentLocation == null) return;

    try {
      final currentStop = _currentRoute!.stopInfos[_currentStopIndex];
      final origin = _currentStopIndex == 0
          ? _currentRoute!.startLocation
          : _currentRoute!.stopInfos[_currentStopIndex - 1].location;

      final instructions = await _getDetailedInstructions(
        _currentLocation!,
        currentStop.location,
      );

      _currentInstructions = instructions;
      _currentInstructionIndex = 0;

      print("📍 Cargadas ${instructions.length} instrucciones para parada ${_currentStopIndex + 1}");
    } catch (e) {
      print("❌ Error cargando instrucciones: $e");
    }
  }

  /// Obtener instrucciones detalladas de Google Directions
  Future<List<NavigationInstruction>> _getDetailedInstructions(
      LatLng origin,
      LatLng destination,
      ) async {
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?'
              'origin=${origin.latitude},${origin.longitude}&'
              'destination=${destination.latitude},${destination.longitude}&'
              'mode=driving&'
              'language=es&'
              'units=metric&'
              'key=${ApiConfig.getApiKey()}'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'] as List;
          final instructions = <NavigationInstruction>[];

          for (final leg in legs) {
            final steps = leg['steps'] as List;

            for (int i = 0; i < steps.length; i++) {
              final step = steps[i];

              final instruction = NavigationInstruction(
                text: _cleanHtmlText(step['html_instructions']),
                distance: (step['distance']['value'] as int).toDouble(),
                duration: step['duration']['value'] as int,
                maneuver: step['maneuver'] ?? '',
                startLocation: LatLng(
                  step['start_location']['lat'],
                  step['start_location']['lng'],
                ),
                endLocation: LatLng(
                  step['end_location']['lat'],
                  step['end_location']['lng'],
                ),
              );

              instructions.add(instruction);
            }
          }

          return instructions;
        }
      }
    } catch (e) {
      print("❌ Error obteniendo instrucciones: $e");
    }

    return [];
  }

  /// Comenzar seguimiento de ubicación
  void _startLocationTracking() {
    _locationSubscription = _locationService.getLocationStream().listen(
          (locationData) => _onLocationUpdate(locationData),
      onError: (error) => print("❌ Error en seguimiento de ubicación: $error"),
    );
  }

  /// Manejar actualización de ubicación
  void _onLocationUpdate(LocationData locationData) {
    if (!_isNavigating || _currentRoute == null) return;

    _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);

    final currentStop = _currentRoute!.stopInfos[_currentStopIndex];
    final distanceToDestination = _calculateDistance(
      _currentLocation!,
      currentStop.location,
    );

    // Verificar si llegó al destino
    if (distanceToDestination <= _arrivalThreshold) {
      _handleArrival();
      return;
    }

    // Verificar instrucciones de navegación
    _checkNavigationInstructions();

    // Emitir estado actualizado
    _emitNavigationState();
  }

  /// Manejar llegada a destino
  void _handleArrival() {
    final currentStop = _currentRoute!.stopInfos[_currentStopIndex];
    _speak("Ha llegado a su destino: ${currentStop.order.clientName}. " +
        "Dirección: ${currentStop.order.address}. " +
        "Teléfono: ${currentStop.order.clientPhone}");
  }

  /// Verificar y anunciar instrucciones de navegación
  void _checkNavigationInstructions() {
    if (_currentInstructions.isEmpty || _currentLocation == null) return;

    for (int i = _currentInstructionIndex; i < _currentInstructions.length; i++) {
      final instruction = _currentInstructions[i];
      final distanceToInstruction = _calculateDistance(
        _currentLocation!,
        instruction.startLocation,
      );

      if (distanceToInstruction <= _instructionThreshold) {
        _announceInstruction(instruction);
        _currentInstructionIndex = i + 1;
        break;
      }
    }
  }

  /// Anunciar instrucción de navegación
  void _announceInstruction(NavigationInstruction instruction) {
    final distanceText = instruction.distance > 1000
        ? "${(instruction.distance / 1000).toStringAsFixed(1)} kilómetros"
        : "${instruction.distance.round()} metros";

    final announcement = "En $distanceText, ${instruction.text}";
    _speak(announcement);

    _instructionController.add(announcement);
  }

  /// Hablar texto usando TTS
  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
      print("🔊 TTS: $text");
    } catch (e) {
      print("❌ Error en TTS: $e");
    }
  }

  /// Emitir estado de navegación
  void _emitNavigationState() {
    if (_currentRoute == null) return;

    final state = NavigationState(
      isNavigating: _isNavigating,
      currentStopIndex: _currentStopIndex,
      totalStops: _currentRoute!.stopInfos.length,
      currentStop: _currentStopIndex < _currentRoute!.stopInfos.length
          ? _currentRoute!.stopInfos[_currentStopIndex]
          : null,
      currentLocation: _currentLocation,
      distanceToDestination: _currentLocation != null &&
          _currentStopIndex < _currentRoute!.stopInfos.length
          ? _calculateDistance(
        _currentLocation!,
        _currentRoute!.stopInfos[_currentStopIndex].location,
      )
          : null,
    );

    _navigationController.add(state);
  }

  /// Calcular distancia entre dos puntos
  double _calculateDistance(LatLng point1, LatLng point2) {
    return _locationService.calculateDistance(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Limpiar texto HTML
  String _cleanHtmlText(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  /// Limpiar recursos
  void dispose() {
    _locationSubscription?.cancel();
    _navigationController.close();
    _instructionController.close();
    _flutterTts.stop();
  }
}

// Modelo para instrucciones de navegación
class NavigationInstruction {
  final String text;
  final double distance;
  final int duration;
  final String maneuver;
  final LatLng startLocation;
  final LatLng endLocation;

  NavigationInstruction({
    required this.text,
    required this.distance,
    required this.duration,
    required this.maneuver,
    required this.startLocation,
    required this.endLocation,
  });
}

// Modelo para estado de navegación
class NavigationState {
  final bool isNavigating;
  final int currentStopIndex;
  final int totalStops;
  final RouteStopInfo? currentStop;
  final LatLng? currentLocation;
  final double? distanceToDestination;

  NavigationState({
    required this.isNavigating,
    required this.currentStopIndex,
    required this.totalStops,
    this.currentStop,
    this.currentLocation,
    this.distanceToDestination,
  });
}