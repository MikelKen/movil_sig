import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart' as geo;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Location location = Location();

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await location.serviceEnabled();
  }

  /// Request location service to be enabled
  Future<bool> requestLocationService() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    return true;
  }

  /// Check and request location permissions
  Future<bool> checkAndRequestLocationPermission() async {
    PermissionStatus permission = await location.hasPermission();

    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted) {
        return false;
      }
    }

    return true;
  }

  /// Get current location
  Future<LocationData?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await requestLocationService();
      if (!serviceEnabled) return null;

      bool permissionGranted = await checkAndRequestLocationPermission();
      if (!permissionGranted) return null;

      LocationData locationData = await location.getLocation();
      return locationData;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Get current position using Geolocator
  Future<geo.Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          return null;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        return null;
      }

      return await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Listen to location changes
  Stream<LocationData> getLocationStream() {
    return location.onLocationChanged;
  }

  /// Calculate distance between two points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return geo.Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Calculate bearing between two points
  double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    return geo.Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }
}
