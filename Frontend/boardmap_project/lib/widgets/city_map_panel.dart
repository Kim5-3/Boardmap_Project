import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A decorative, draggable Cabadbaran-inspired street map. This is UI only;
/// it does not claim to be a precise navigational map and needs no API key.
class CityMapPanel extends StatefulWidget {
  const CityMapPanel({super.key});

  @override
  State<CityMapPanel> createState() => _CityMapPanelState();
}

class _CityMapPanelState extends State<CityMapPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset _dragOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 32))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => setState(() => _dragOffset += details.delta),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final drift = Offset(math.sin(_controller.value * math.pi * 2) * 13, math.cos(_controller.value * math.pi * 2) * 10);
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.translate(
                  offset: _dragOffset + drift,
                  child: CustomPaint(painter: _CityMapPainter()),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xE6123D2A), Color(0xAA123D2A), Color(0x22123D2A)],
                    ),
                  ),
                ),
                Positioned(
                  top: 26,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.location_on_outlined, color: Color(0xFF8BE0B0), size: 16), SizedBox(width: 6), Text('CABADBARAN CITY', style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800))]),
                  ),
                ),
                Positioned(
                  left: 30,
                  bottom: 26,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.20), borderRadius: BorderRadius.circular(9)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.open_with, size: 15, color: Colors.white70), SizedBox(width: 7), Text('Drag to explore the map', style: TextStyle(color: Colors.white70, fontSize: 11))]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CityMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1D6248));
    final parkPaint = Paint()..color = const Color(0xFF2D7955);
    final parks = [
      Rect.fromLTWH(size.width * .08, size.height * .12, size.width * .20, size.height * .18),
      Rect.fromLTWH(size.width * .50, size.height * .08, size.width * .18, size.height * .13),
      Rect.fromLTWH(size.width * .68, size.height * .56, size.width * .24, size.height * .20),
      Rect.fromLTWH(size.width * .28, size.height * .70, size.width * .17, size.height * .18),
    ];
    for (final park in parks) {
      canvas.drawRRect(RRect.fromRectAndRadius(park, const Radius.circular(14)), parkPaint);
      final dotPaint = Paint()..color = const Color(0xFF438763);
      for (int i = 0; i < 9; i++) {
        final x = park.left + (i % 3 + 1) * park.width / 4;
        final y = park.top + (i ~/ 3 + 1) * park.height / 4;
        canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
      }
    }

    final minor = Paint()..color = const Color(0xFFB8D2B9)..strokeWidth = 5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final major = Paint()..color = const Color(0xFFE5D8A7)..strokeWidth = 10..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final roadPaths = <Path>[
      Path()..moveTo(-20, size.height * .20)..cubicTo(size.width * .24, size.height * .32, size.width * .38, size.height * .08, size.width * .62, size.height * .27)..cubicTo(size.width * .78, size.height * .39, size.width * .82, size.height * .23, size.width + 20, size.height * .34),
      Path()..moveTo(size.width * .06, size.height + 20)..cubicTo(size.width * .26, size.height * .72, size.width * .34, size.height * .45, size.width * .43, -20),
      Path()..moveTo(size.width * .56, size.height + 20)..cubicTo(size.width * .49, size.height * .70, size.width * .74, size.height * .45, size.width * .72, -20),
      Path()..moveTo(-20, size.height * .58)..cubicTo(size.width * .28, size.height * .48, size.width * .60, size.height * .78, size.width + 20, size.height * .66),
      Path()..moveTo(size.width * .12, size.height * .05)..lineTo(size.width * .90, size.height * .94),
    ];
    canvas.drawPath(roadPaths[0], major);
    canvas.drawPath(roadPaths[2], major);
    for (int i = 0; i < roadPaths.length; i++) {
      canvas.drawPath(roadPaths[i], minor);
    }

    final buildingPaint = Paint()..color = const Color(0xFFDAE5D8);
    for (int row = 0; row < 7; row++) {
      for (int col = 0; col < 9; col++) {
        final x = col * size.width / 8.3 + (row.isOdd ? 7 : 0);
        final y = row * size.height / 7.3 + 10;
        if ((row + col) % 4 == 0) continue;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 8, 6), const Radius.circular(1.5)), buildingPaint);
      }
    }

    final pinPoints = [Offset(size.width * .36, size.height * .40), Offset(size.width * .70, size.height * .34), Offset(size.width * .54, size.height * .76)];
    for (final point in pinPoints) {
      canvas.drawCircle(point, 15, Paint()..color = const Color(0x3326A269));
      canvas.drawCircle(point, 8, Paint()..color = const Color(0xFF29A66A));
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
