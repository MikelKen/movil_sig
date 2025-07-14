class ApiConfig {
  // IMPORTANTE: Reemplaza esta API key con tu clave real de Google Maps
  // Asegúrate de habilitar las siguientes APIs en Google Cloud Console:
  // 1. Maps SDK for Android
  // 2. Directions API
  // 3. Distance Matrix API
  // 4. Places API (opcional)

  static const String googleMapsApiKey = 'YOUR_API_KEY_HERE';

  // URLs base para las APIs de Google
  static const String directionsApiUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String distanceMatrixApiUrl = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String placesApiUrl = 'https://maps.googleapis.com/maps/api/place';

  // Validar si la API key está configurada
  static bool get isApiKeyConfigured =>
      googleMapsApiKey.isNotEmpty;

  // Obtener URL completa para Directions APIs
  static String getDirectionsUrl() => directionsApiUrl;

  // Obtener URL completa para Distance Matrix API
  static String getDistanceMatrixUrl() => distanceMatrixApiUrl;

  // Obtener API key con validación
  static String getApiKey() {
    if (!isApiKeyConfigured) {

      throw Exception('API Key de Google Maps no configurada. '
          'Edita el archivo lib/config/api_config.dart');
    }
    return googleMapsApiKey;
  }
}

