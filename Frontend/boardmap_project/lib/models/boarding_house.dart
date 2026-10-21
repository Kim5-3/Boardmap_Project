class BoardingHouse {
  const BoardingHouse({
    required this.name,
    required this.location,
    required this.price,
    required this.availableRooms,
    required this.roomType,
    required this.match,
    required this.rating,
    required this.amenities,
    this.imageColor = 0xFFDCEDE2,
  });

  final String name;
  final String location;
  final int price;
  final int availableRooms;
  final String roomType;
  final int match;
  final double rating;
  final List<String> amenities;
  final int imageColor;
}
