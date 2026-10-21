
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/renter_home_screen.dart';
import 'screens/report_form_screen.dart';

class BoardMapApp extends StatelessWidget {
  const BoardMapApp({super.key});

  static const Color primaryGreen = Color(0xFF218653);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BoardMap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F8F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const RenterHomeScreen(),
        '/report': (context) => const ReportFormScreen(),
      },
    );
  }
}
