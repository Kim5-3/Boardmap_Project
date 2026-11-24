int _parseRent(dynamic value) {
  if (value is num) return value.round();
  return double.tryParse('$value')?.round() ?? 0;
}

class BoardingHouse {
  const BoardingHouse({
    this.id,
    required this.name,
    required this.location,
    this.description = '',
    required this.price,
    required this.availableRooms,
    required this.roomType,
    required this.amenities,
    this.matchReasons = const [],
    this.rules = '',
    this.curfewDetails = '',
    this.safetyFeatures = const [],
    this.utilityDetails = const [],
    this.genderPolicy = '',
    this.depositTerms = '',
    this.campusDistanceKm,
    this.latitude,
    this.longitude,
    this.imageColor = 0xFFDCEDE2,
    this.imageUrls = const [],
  });

  final int? id;
  final String name;
  final String location;
  final String description;
  final int price;
  final int availableRooms;
  final String roomType;
  final List<String> matchReasons;
  final String rules;
  final List<String> amenities;
  final String curfewDetails;
  final List<String> safetyFeatures;
  final List<String> utilityDetails;
  final String genderPolicy;
  final String depositTerms;
  final double? campusDistanceKm;
  final double? latitude;
  final double? longitude;
  final int imageColor;
  final List<String> imageUrls;

  factory BoardingHouse.fromJson(Map<String, dynamic> json) => BoardingHouse(
    id: (json['id'] as num?)?.toInt(),
    name: json['name'] as String? ?? 'Boarding house',
    location: json['location'] as String? ?? 'Location not provided',
    description: json['description'] as String? ?? '',
    price: _parseRent(json['price']),
    availableRooms: (json['available_rooms'] as num?)?.toInt() ?? 0,
    roomType: json['room_type'] as String? ?? 'Not specified',
    amenities:
        (json['amenities'] as List?)?.whereType<String>().toList() ?? const [],
    rules: json['rules'] as String? ?? '',
    curfewDetails: json['curfew_details'] as String? ?? '',
    safetyFeatures:
        (json['safety_features'] as List?)?.whereType<String>().toList() ??
        const [],
    utilityDetails:
        (json['utility_details'] as List?)?.whereType<String>().toList() ??
        const [],
    genderPolicy: json['gender_policy'] as String? ?? '',
    depositTerms: json['deposit_terms'] as String? ?? '',
    campusDistanceKm: json['campus_distance_km'] is num
        ? (json['campus_distance_km'] as num).toDouble()
        : double.tryParse('${json['campus_distance_km']}'),
    matchReasons:
        (json['match_reasons'] as List?)?.whereType<String>().toList() ??
        const [],
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    imageColor: 0xFFDDE8D7,
    imageUrls: (json['image_urls'] as List?)?.whereType<String>().toList() ?? const [],
  );
}

/// Stable identity for saved listings; names alone are not unique.
String boardingHouseFavoriteKey(BoardingHouse house) =>
    house.id == null ? 'name:${house.name}' : 'id:${house.id}';
