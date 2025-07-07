import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_location.dart';

class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  // Singleton pattern
  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._internal();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  StorageService._internal();

  // Inicializar SharedPreferences
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Guardar datos
  Future<void> saveData(String key, dynamic data) async {
    await init();
    final jsonString = jsonEncode(data);
    await _prefs!.setString(key, jsonString);
  }

  // Obtener datos
  Future<dynamic> getData(String key) async {
    await init();
    final jsonString = _prefs!.getString(key);
    if (jsonString == null) return null;
    return jsonDecode(jsonString);
  }

  // Eliminar datos
  Future<void> removeData(String key) async {
    await init();
    await _prefs!.remove(key);
  }

  // Limpiar todos los datos
  Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }

  // Métodos específicos para ubicaciones guardadas
  Future<List<SavedLocation>> getSavedLocations() async {
    try {
      final data = await getData('saved_locations');
      if (data == null) return [];

      return (data as List).map((json) => SavedLocation.fromJson(json)).toList();
    } catch (e) {
      print('Error loading saved locations: $e');
      return [];
    }
  }

  Future<void> saveLocation(SavedLocation location) async {
    try {
      final locations = await getSavedLocations();
      final existingIndex = locations.indexWhere((l) => l.id == location.id);

      if (existingIndex >= 0) {
        locations[existingIndex] = location;
      } else {
        locations.add(location);
      }

      final data = locations.map((l) => l.toJson()).toList();
      await saveData('saved_locations', data);
    } catch (e) {
      print('Error saving location: $e');
      throw e;
    }
  }

  Future<void> deleteLocation(String locationId) async {
    try {
      final locations = await getSavedLocations();
      locations.removeWhere((l) => l.id == locationId);

      final data = locations.map((l) => l.toJson()).toList();
      await saveData('saved_locations', data);
    } catch (e) {
      print('Error deleting location: $e');
      throw e;
    }
  }
}
