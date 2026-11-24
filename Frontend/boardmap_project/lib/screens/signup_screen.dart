import 'package:flutter/material.dart';

import 'login_screen.dart';

/// Compatibility entry point: registration is handled by the authenticated API
/// flow in LoginScreen so there is only one registration implementation.
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) => const LoginScreen(startInRegister: true);
}