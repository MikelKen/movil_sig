import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/constants.dart';

class SimpleMapScreen extends StatefulWidget {
  const SimpleMapScreen({Key? key}) : super(key: key);

  @override
  State<SimpleMapScreen> createState() => _SimpleMapScreenState();
}

class _SimpleMapScreenState extends State<SimpleMapScreen> {
  GoogleMapController? _mapController;

  // Default location (Santa Cruz, Bolivia)
  static const LatLng _center = LatLng(
    AppConstants.defaultLat,
    AppConstants.defaultLng,
  );
  static const LatLng _destination = LatLng(
    AppConstants.santaCruzLat,
    AppConstants.santaCruzLng,
  );

  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
  }

  void _initializeMarkers() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('origin'),
          position: _center,
          infoWindow: const InfoWindow(
            title: 'Ubicación Actual',
            snippet: 'Tu ubicación',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination,
          infoWindow: const InfoWindow(
            title: 'Destino',
            snippet: 'Santa Cruz Centro',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    print('Mapa creado exitosamente');
  }

  void _goToLocation(LatLng location) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
  }

  void _fitBothMarkers() {
    if (_mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _center.latitude < _destination.latitude
              ? _center.latitude
              : _destination.latitude,
          _center.longitude < _destination.longitude
              ? _center.longitude
              : _destination.longitude,
        ),
        northeast: LatLng(
          _center.latitude > _destination.latitude
              ? _center.latitude
              : _destination.latitude,
          _center.longitude > _destination.longitude
              ? _center.longitude
              : _destination.longitude,
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery App - Mapa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: _center,
              zoom: 14,
            ),
            markers: _markers,
            myLocationEnabled: false, // Deshabilitado temporalmente
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomGesturesEnabled: true,
          ),

          // Panel de información superior
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🚗 App de Delivery',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Mapa estilo Uber funcionando correctamente',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // Botones de control
          Positioned(
            bottom: 100,
            right: 20,
            child: Column(
              children: [
                // Botón de ubicación actual
                FloatingActionButton(
                  heroTag: "origin",
                  mini: true,
                  backgroundColor: Colors.green,
                  onPressed: () => _goToLocation(_center),
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
                const SizedBox(height: 10),

                // Botón de destino
                FloatingActionButton(
                  heroTag: "destination",
                  mini: true,
                  backgroundColor: Colors.red,
                  onPressed: () => _goToLocation(_destination),
                  child: const Icon(Icons.location_on, color: Colors.white),
                ),
                const SizedBox(height: 10),

                // Botón para ver ambos marcadores
                FloatingActionButton(
                  heroTag: "fit",
                  mini: true,
                  backgroundColor: Colors.blue,
                  onPressed: _fitBothMarkers,
                  child: const Icon(Icons.fit_screen, color: Colors.white),
                ),
              ],
            ),
          ),

          // Botón de simulación (placeholder)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🚗 Simulación de delivery próximamente!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Iniciar Simulación de Delivery',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
