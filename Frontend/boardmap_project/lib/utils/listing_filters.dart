import 'dart:math' as math;

const commonBoardingRoomTypes = <String>[
  'Bed spacer',
  'Solo',
  'Shared',
  'Studio',
  'Dormitory',
];

String normalizeRoomType(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

List<String> boardingRoomTypeOptions(Iterable<String> listingTypes) {
  final options = <String, String>{};
  for (final type in [...commonBoardingRoomTypes, ...listingTypes]) {
    final cleaned = type.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isNotEmpty) options.putIfAbsent(cleaned.toLowerCase(), () => cleaned);
  }
  return options.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

int parsePriceInput(String value, {required int fallback}) {
  final parsed = double.tryParse(value.replaceAll(',', '').trim())?.round();
  return parsed == null || parsed < 0 ? fallback : parsed;
}

String _normalizedToken(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r"[^a-z0-9]+"), ' ')
    .trim();

bool matchesListingQuery({
  required String query,
  required Iterable<String> fields,
}) {
  final ignored = {'bh', 'boarding', 'house', 'houses', 'the', 'for', 'near'};
  final queryTokens = _normalizedToken(query)
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty && !ignored.contains(token))
      .map((token) => token.length > 4 && token.endsWith('s')
          ? token.substring(0, token.length - 1)
          : token);
  final fieldTokens = fields
      .map(_normalizedToken)
      .join(' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toSet();
  return queryTokens.every((queryToken) => fieldTokens.any(
        (fieldToken) => fieldToken == queryToken ||
            fieldToken.startsWith(queryToken) ||
            queryToken.startsWith(fieldToken),
      ));
}

double? distanceBetweenKm(double? lat1, double? lon1, double? lat2, double? lon2) {
  if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;
  const earthRadiusKm = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
