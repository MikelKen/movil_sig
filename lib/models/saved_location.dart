import 'package:google_maps_flutter/google_maps_flutter.dart';

class SavedLocation {
  final String id;
  final String name;
  final String? description;
  final LatLng position;
  final LocationType type;
  final DateTime createdAt;

  SavedLocation({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    required this.type,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      position: LatLng(json['latitude'], json['longitude']),
      type: LocationType.values[json['type']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
    );
  }

  SavedLocation copyWith({
    String? name,
    String? description,
    LocationType? type,
  }) {
    return SavedLocation(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      position: position,
      type: type ?? this.type,
      createdAt: createdAt,
    );
  }
}

enum LocationType {
  home,
  work,
  restaurant,
  shopping,
  hospital,
  school,
  gas_station,
  other,
}

extension LocationTypeExtension on LocationType {
  String get displayName {
    switch (this) {
      case LocationType.home:
        return 'Casa';
      case LocationType.work:
        return 'Trabajo';
      case LocationType.restaurant:
        return 'Restaurante';
      case LocationType.shopping:
        return 'Tienda';
      case LocationType.hospital:
        return 'Hospital';
      case LocationType.school:
        return 'Escuela';
      case LocationType.gas_station:
        return 'Gasolinera';
      case LocationType.other:
        return 'Otro';
    }
  }

  String get icon {
    switch (this) {
      case LocationType.home:
        return '🏠';
      case LocationType.work:
        return '🏢';
      case LocationType.restaurant:
        return '🍽️';
      case LocationType.shopping:
        return '🛒';
      case LocationType.hospital:
        return '🏥';
      case LocationType.school:
        return '🏫';
      case LocationType.gas_station:
        return '⛽';
      case LocationType.other:
        return '📍';
    }
  }
}
