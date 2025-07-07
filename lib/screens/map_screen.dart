import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import '../services/location_service.dart';
import '../services/directions_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final LocationService _locationService = LocationService();

  // Location and Route data
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  DirectionsResult? _directionsResult;

  // Map display state
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Vehicle animation
  LatLng? _vehiclePosition;
  double _vehicleRotation = 0.0;
  Timer? _animationTimer;
  int _currentRouteIndex = 0;

  // UI state
  bool _isLoading = true;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      print('Initializing map...');

      // Get current location
      LocationData? locationData = await _locationService.getCurrentLocation();
      if (locationData != null) {
        print(
          'Location obtained: ${locationData.latitude}, ${locationData.longitude}',
        );
        setState(() {
          _currentLocation = LatLng(
            locationData.latitude!,
            locationData.longitude!,
          );
          _isLoading = false;
        });

        // Set a sample destination (you can modify this)
        _setDestination(LatLng(-17.7833, -63.1822)); // Santa Cruz, Bolivia
      } else {
        print('Could not get location, using default location');
        // Use default location if can't get current location
        setState(() {
          _currentLocation = const LatLng(
            -17.8146,
            -63.1561,
          ); // Default: Santa Cruz
          _isLoading = false;
        });
        _setDestination(LatLng(-17.7833, -63.1822));
      }
    } catch (e) {
      print('Error initializing map: $e');
      // Use default location on error
      setState(() {
        _currentLocation = const LatLng(
          -17.8146,
          -63.1561,
        ); // Default: Santa Cruz
        _isLoading = false;
      });
      _setDestination(LatLng(-17.7833, -63.1822));
    }
  }

  Future<void> _setDestination(LatLng destination) async {
    if (_currentLocation == null) return;

    setState(() {
      _destinationLocation = destination;
      _isLoading = true;
    });

    print(
      'Setting destination to: ${destination.latitude}, ${destination.longitude}',
    );

    // Get directions
    final DirectionsService directionsService = DirectionsService();
    DirectionsResult? result = await directionsService.getDirections(
      origin: _currentLocation!,
      destination: destination,
    );

    if (result != null) {
      print('Directions result obtained, updating UI');
      setState(() {
        _directionsResult = result;
        _vehiclePosition = _currentLocation;
        _currentRouteIndex = 0;
        _isLoading = false;
      });

      _updateMapUI();
      _animateMapCamera();
    } else {
      print('No directions result, showing map without route');
      setState(() {
        _isLoading = false;
      });
      // Show basic markers even without directions
      _showBasicMarkers();
    }
  }

  void _showBasicMarkers() {
    _markers.clear();
    _polylines.clear();

    // Add origin marker
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Current Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    // Add destination marker
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    setState(() {});
  }

  void _updateMapUI() {
    if (_directionsResult == null) return;

    // Clear previous markers and polylines
    _markers.clear();
    _polylines.clear();

    // Add origin marker
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    // Add destination marker
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // Add vehicle marker
    if (_vehiclePosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('vehicle'),
          position: _vehiclePosition!,
          rotation: _vehicleRotation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Vehicle'),
        ),
      );
    }

    // Add route polyline
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: _directionsResult!.routes.first.polylinePoints,
        color: Colors.blue,
        width: 5,
      ),
    );

    setState(() {});
  }

  void _animateMapCamera() {
    if (_directionsResult != null && _mapController != null) {
      // Crear bounds basados en los puntos de la ruta
      final points = _directionsResult!.routes.first.polylinePoints;
      if (points.isNotEmpty) {
        double minLat = points.first.latitude;
        double maxLat = points.first.latitude;
        double minLng = points.first.longitude;
        double maxLng = points.first.longitude;

        for (LatLng point in points) {
          minLat = math.min(minLat, point.latitude);
          maxLat = math.max(maxLat, point.latitude);
          minLng = math.min(minLng, point.longitude);
          maxLng = math.max(maxLng, point.longitude);
        }

        LatLngBounds bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100.0),
        );
      }
    }
  }

  void _startVehicleAnimation() {
    if (_directionsResult == null || _isSimulating) return;

    setState(() {
      _isSimulating = true;
      _currentRouteIndex = 0;
    });

    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      if (_currentRouteIndex < _directionsResult!.routes.first.polylinePoints.length - 1) {
        _updateVehiclePosition();
      } else {
        _stopVehicleAnimation();
      }
    });
  }

  void _updateVehiclePosition() {
    if (_directionsResult == null) return;

    final currentPoint = _directionsResult!.routes.first.polylinePoints[_currentRouteIndex];
    final nextPoint = _directionsResult!.routes.first.polylinePoints[_currentRouteIndex + 1];

    // Calculate bearing for vehicle rotation
    double bearing = _calculateBearing(currentPoint, nextPoint);

    setState(() {
      _vehiclePosition = nextPoint;
      _vehicleRotation = bearing;
      _currentRouteIndex++;
    });

    // Update vehicle marker
    _markers.removeWhere((marker) => marker.markerId.value == 'vehicle');
    _markers.add(
      Marker(
        markerId: const MarkerId('vehicle'),
        position: _vehiclePosition!,
        rotation: _vehicleRotation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Vehicle'),
      ),
    );

    // Center camera on vehicle
    _mapController?.animateCamera(CameraUpdate.newLatLng(_vehiclePosition!));
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double deltaLng = (end.longitude - start.longitude) * math.pi / 180;

    double y = math.sin(deltaLng) * math.cos(lat2);
    double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  void _stopVehicleAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _isSimulating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                initialCameraPosition: CameraPosition(
                  target: _currentLocation ?? const LatLng(-17.8146, -63.1561),
                  zoom: 14,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),

          // Top info panel
          if (_directionsResult != null)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance: ${_directionsResult!.routes.first.distance}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: ${_directionsResult!.routes.first.duration}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Control buttons
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              children: [
                // My Location button
                FloatingActionButton(
                  heroTag: "location",
                  mini: true,
                  onPressed: () {
                    if (_currentLocation != null && _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLngZoom(_currentLocation!, 16),
                      );
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 10),

                // Fit route button
                if (_directionsResult != null)
                  FloatingActionButton(
                    heroTag: "fit",
                    mini: true,
                    onPressed: _animateMapCamera,
                    child: const Icon(Icons.fit_screen),
                  ),
              ],
            ),
          ),

          // Start simulation button
          if (_directionsResult != null && !_isSimulating)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _startVehicleAnimation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Delivery Simulation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // Stop simulation button
          if (_isSimulating)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: _stopVehicleAnimation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Stop Simulation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
