import 'package:flutter/material.dart';

import '../models/boarding_house.dart';
import '../services/api_service.dart';

class BoardingHouseImage extends StatelessWidget {
  const BoardingHouseImage({
    super.key,
    required this.house,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  final BoardingHouse house;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = house.imageUrls.isEmpty
        ? _fallback()
        : Image.network(
            _imageUrl(house.imageUrls.first),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => _fallback(),
          );
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: image),
    );
  }

  String _imageUrl(String path) => path.startsWith('http')
      ? path
      : '${BoardMapApi.baseUrl}${path.startsWith('/') ? '' : '/'}$path';

  Widget _fallback() => ColoredBox(
    color: Color(house.imageColor),
    child: const Center(child: Icon(Icons.house_rounded, size: 42, color: Color(0xFF557461))),
  );
}
