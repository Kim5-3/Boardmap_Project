
import 'package:flutter/material.dart';

class CityBackground extends StatelessWidget {
  const CityBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/assets/images/cabadbaran_city.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFF004D3A),
              alignment: Alignment.center,
              child: const Text(
                'Cabadbaran City',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
            );
          },
        ),

        // Green overlay for readable white text.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF003F30).withOpacity(0.96),
                const Color(0xFF00513B).withOpacity(0.75),
                const Color(0xFF004D3A).withOpacity(0.32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
