import 'package:flutter/material.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/city_map_panel.dart';

/// Separate UI-only sign-up screen. It deliberately does not authenticate or
/// save account details. After validation, it returns the user to sign-in.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Please enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  String? _confirmValidator(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != _passwordController.text) return 'Passwords do not match.';
    return null;
  }

  void _createAccount() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm that you agree to the terms.')));
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF218653), size: 48),
        title: const Text('Account created successfully!'),
        content: const Text('Your sign-up form is complete. You may now return to the sign-in screen. This UI demo does not save account details yet.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go to sign in'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white, title: const Text('Create an account', style: TextStyle(fontWeight: FontWeight.w800)), leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        if (wide) {
          return Row(children: [const Expanded(flex: 42, child: CityMapPanel()), Expanded(flex: 58, child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: _form()))))]);
        }
        return SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500), child: _form())));
      }),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Create your account', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -.8, color: Color(0xFF18261F))),
        const SizedBox(height: 8),
        const Text('Join BoardMap and find a place that feels like home.', style: TextStyle(color: Color(0xFF718077), height: 1.5)),
        const SizedBox(height: 24),
        AppTextField(controller: _nameController, label: 'Full name', hint: 'Enter your full name', prefixIcon: Icons.badge_outlined, validator: _required),
        const SizedBox(height: 14),
        AppTextField(controller: _usernameController, label: 'Username', hint: 'Choose a username', prefixIcon: Icons.person_outline_rounded, validator: _required),
        const SizedBox(height: 14),
        AppTextField(controller: _emailController, label: 'Email address', hint: 'you@example.com', prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: _emailValidator),
        const SizedBox(height: 14),
        AppTextField(controller: _passwordController, label: 'Password', hint: 'At least 8 characters', prefixIcon: Icons.lock_outline_rounded, obscureText: _obscurePassword, validator: _passwordValidator, suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
        const SizedBox(height: 14),
        AppTextField(controller: _confirmController, label: 'Confirm password', hint: 'Re-enter your password', prefixIcon: Icons.lock_reset_rounded, obscureText: _obscureConfirm, validator: _confirmValidator, suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined))),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _acceptedTerms,
          onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: const Color(0xFF218653),
          title: const Text('I agree to the terms and privacy policy.', style: TextStyle(fontSize: 12, color: Color(0xFF59675F))),
        ),
        const SizedBox(height: 14),
        AppButton(label: 'Create account', icon: Icons.person_add_alt_1_rounded, onPressed: _createAccount),
        const SizedBox(height: 16),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Already have an account? Sign in', style: TextStyle(color: Color(0xFF218653), fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
