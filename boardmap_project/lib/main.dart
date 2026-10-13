
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const BoardMapApp());
}

class BoardMapApp extends StatelessWidget {
  const BoardMapApp({super.key});

  static const Color primaryGreen = Color(0xFF218653);
  static const Color darkGreen = Color(0xFF123D2A);
  static const Color pageBackground = Color(0xFFF5F8F5);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoardMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
          primary: primaryGreen,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAF8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCE5DD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDCE5DD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: primaryGreen,
              width: 1.7,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
