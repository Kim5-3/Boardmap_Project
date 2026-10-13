
import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  static const Color green = Color(0xFF218653);
  static const Color darkGreen = Color(0xFF123D2A);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }

    if (_isRegistering && value.length < 8) {
      return 'Use at least 8 characters.';
    }

    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  void _switchMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _acceptTerms = false;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_isRegistering && !_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms to continue.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Demo navigation only. Connect real authentication here.
    await Future<void>.delayed(
      const Duration(milliseconds: 350),
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(
          username: _isRegistering
              ? _usernameController.text.trim()
              : _emailController.text.trim(),
        ),
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      color: darkGreen,
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              const Text(
                'BoardMap',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: Color(0xFF8EE4AC),
                ),
                SizedBox(width: 7),
                Text(
                  'CABADBARAN CITY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            'Find your place.\nPlan your future.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 42,
              height: 1.18,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Discover boarding houses with a smarter, '
            'map-based way to explore your next home.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontSize: 16,
              height: 1.8,
            ),
          ),
          const SizedBox(height: 35),
          const _FeatureRow(
            icon: Icons.map_outlined,
            title: 'Explore locations',
            subtitle: 'View boarding house locations on a map.',
          ),
          const SizedBox(height: 23),
          const _FeatureRow(
            icon: Icons.recommend_outlined,
            title: 'Discover suitable places',
            subtitle: 'Find options that fit your preferences.',
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 17,
                color: Colors.white.withValues(alpha: 0.65),
              ),
              const SizedBox(width: 9),
              Text(
                'A smarter way to find your next stay.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBrand() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(25, 30, 25, 28),
      decoration: const BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.map_rounded,
            size: 39,
            color: Color(0xFF8EE4AC),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BoardMap',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Find your next place to stay.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel({required bool compact}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 24 : 48,
            vertical: compact ? 30 : 42,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isRegistering
                      ? 'Create your account'
                      : 'Welcome back',
                  style: const TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18251D),
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isRegistering
                      ? 'Enter your details to get started with BoardMap.'
                      : 'Sign in to continue exploring boarding houses.',
                  style: const TextStyle(
                    color: Color(0xFF718077),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 30),

                if (_isRegistering) ...[
                  AppTextField(
                    controller: _nameController,
                    label: 'Full name',
                    hint: 'Enter your full name',
                    prefixIcon: Icons.person_outline,
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 17),
                  AppTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'Choose a username',
                    prefixIcon: Icons.alternate_email,
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 17),
                  AppTextField(
                    controller: _emailController,
                    label: 'Email address',
                    hint: 'you@example.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                  ),
                ] else ...[
                  AppTextField(
                    controller: _emailController,
                    label: 'Email or username',
                    hint: 'Enter your email or username',
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: _requiredValidator,
                  ),
                ],

                const SizedBox(height: 17),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: _isRegistering
                      ? 'At least 8 characters'
                      : 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  validator: _passwordValidator,
                  textInputAction: _isRegistering
                      ? TextInputAction.next
                      : TextInputAction.done,
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),

                if (_isRegistering) ...[
                  const SizedBox(height: 17),
                  AppTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm password',
                    hint: 'Re-enter your password',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    validator: _confirmPasswordValidator,
                    textInputAction: TextInputAction.done,
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword =
                              !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  CheckboxListTile(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptTerms = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: green,
                    dense: true,
                    title: const Text(
                      'I agree to the terms and privacy policy.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF59665D),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Connect password recovery to your backend.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                AppButton(
                  label: _isRegistering
                      ? 'Create account'
                      : 'Sign in',
                  icon: _isRegistering
                      ? Icons.person_add_alt_1
                      : Icons.arrow_forward_rounded,
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: Color(0xFFE1E8E2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Text(
                        _isRegistering
                            ? 'ALREADY A MEMBER?'
                            : 'NEW TO BOARDMAP?',
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF849087),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: Color(0xFFE1E8E2)),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                AppButton(
                  label: _isRegistering
                      ? 'Back to sign in'
                      : 'Create an account',
                  outlined: true,
                  onPressed: _switchMode,
                ),
                const SizedBox(height: 27),
                const Center(
                  child: Text(
                    'BOARDMAP  •  CABADBARAN CITY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.0,
                      color: Color(0xFF98A39B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 850;

          if (compact) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMobileBrand(),
                    _buildFormPanel(compact: true),
                  ],
                ),
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildBrandPanel(),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: _buildFormPanel(compact: false),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 43,
          width: 43,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8EE4AC),
            size: 22,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
