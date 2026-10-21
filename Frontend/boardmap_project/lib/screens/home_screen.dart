import 'package:flutter/material.dart';
import 'owner_home_screen.dart';
import 'renter_home_screen.dart';

/// Open this after your demo login succeeds.
/// role must be either "renter" or "owner".
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.role});

  final String role;
  
  @override

  
  Widget build(BuildContext context) {
    final home = role.toLowerCase() == 'owner'
        ? const OwnerHomeScreen()
        : const RenterHomeScreen();

    return Scaffold(
      body: home,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/report'),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Report an issue'),
      ),
    );
  }
}


