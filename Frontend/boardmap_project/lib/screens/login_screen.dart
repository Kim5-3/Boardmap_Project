import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boardmap_project/screens/renter_home_screen.dart';
import 'package:boardmap_project/screens/owner_home_screen.dart';

const Color _green = Color(0xFF00843D);
const Color _deepGreen = Color(0xFF003D2D);
const Color _ink = Color(0xFF102A2A);
const Color _mintBackground = Color(0xFFF1F7F3);
const Color _fieldBackground = Color(0xFFF8FBF9);
const Color _borderColor = Color(0xFFDCEBE1);
const Color _errorRed = Color(0xFFD32F2F);
const Color _successGreen = Color(0xFF16834A);

class _DemoAccount {
  const _DemoAccount({
    required this.password,
    required this.role,
  });

  final String password;
  final String role;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _createAccount = false;
  bool _acceptTerms = false;

  // Demo-only account storage. This is cleared when the app restarts.
  // Replace it with your backend/authentication service for production.
  final Map<String, _DemoAccount> _demoAccounts = {};
  String _selectedRole = 'renter';

  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text == _passwordController.text;

  @override
  void initState() {
    super.initState();

    // Revalidate confirmation when either password changes.
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  void _onPasswordChanged() {
    if (!mounted) return;

    // Refresh the live match indicator and any existing confirmation error.
    if (_createAccount &&
        _confirmPasswordController.text.isNotEmpty) {
      _formKey.currentState?.validate();
    }

    setState(() {});
  }

  void _onConfirmPasswordChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);

    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_createAccount) {
      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please agree to the terms and privacy policy.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final email = _emailController.text.trim().toLowerCase();
      final username = _usernameController.text.trim().toLowerCase();
      if (_demoAccounts.containsKey(email) ||
          _demoAccounts.containsKey(username)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That email or username is already registered.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // DEMO ONLY: store this account in memory so you can test both roles.
      // The account is not saved to a database and disappears on app restart.
      final account = _DemoAccount(
        password: _passwordController.text,
        role: _selectedRole,
      );
      _demoAccounts[email] = account;
      _demoAccounts[username] = account;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: const Icon(
            Icons.check_circle_rounded,
            color: _green,
            size: 54,
          ),
          title: Text(
            'Successfully Created',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          content: Text(
            'Your form is complete. Connect BoardMap to an authentication '
            'service to save your account and allow you to sign in.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.6,
              color: const Color(0xFF586A61),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Back to sign in',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;

      setState(() {
        _createAccount = false;
        _acceptTerms = false;
        _selectedRole = 'renter';
        _nameController.clear();
        _usernameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _hidePassword = true;
        _hideConfirmPassword = true;
      });

      _formKey.currentState?.reset();
      return;
    }

    // DEMO ONLY: verify against accounts created during this app session.
    // Use your real authentication backend before releasing the app.
    final identifier = _emailController.text.trim().toLowerCase();
    final account = _demoAccounts[identifier];

    if (account == null ||
        account.password != _passwordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account not found or password is incorrect. Create a demo account first.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (account.role != _selectedRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This account is registered as ${account.role}. Select ${account.role} to continue.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    final Widget homeScreen = account.role == 'owner'
        ? const OwnerHomeScreen()
        : const RenterHomeScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => homeScreen),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _validEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
        .hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please choose a username.';
    }

    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters.';
    }

    if (value.trim().contains(RegExp(r'\s'))) {
      return 'Username cannot contain spaces.';
    }

    return null;
  }

  String? _validPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password.';
    }

    if (value.length < 8) {
      return 'Use at least 8 characters.';
    }

    return null;
  }

  String? _validConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  Widget _buildPromoPanel({bool compact = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/assets/images/cabadbaran_city.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF277A83),
                  _deepGreen,
                  Color(0xFF00291F),
                ],
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _deepGreen.withValues(alpha: 0.85),
                _green.withValues(alpha: 0.55),
                _green.withValues(alpha: 0.15),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.70, 1.0],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 25 : 58,
            compact ? 22 : 38,
            compact ? 25 : 48,
            compact ? 24 : 35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'lib/assets/images/boardmap_logo.png',
                width: compact ? 105 : 145,
                height: compact ? 105 : 145,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'CBR BoardMap',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 30),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(30),
                  color: _deepGreen.withValues(alpha: .30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 21,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'CABADBARAN CITY',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 24),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Find your place.\n'),
                    TextSpan(
                      text: 'Plan your future.',
                      style: TextStyle(
                        color: const Color(0xFF4BFF91),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: .35),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                style: GoogleFonts.poppins(
                  fontSize: compact ? 31 : 39,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.1,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Discover boarding houses with a smarter,\n'
                'map-based way to explore your next home.',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: compact ? 13 : 15,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 20 : 28),
              _feature(
                Icons.home_work_outlined,
                'Explore Locations',
                'Find the best boarding houses\nnear you.',
                compact,
              ),
              const SizedBox(height: 13),
              _feature(
                Icons.map_outlined,
                'View on Map',
                'Easily search and explore\nCabadbaran City.',
                compact,
              ),
              const SizedBox(height: 13),
              _feature(
                Icons.star_outline,
                'Make Better Choices',
                'Plan your stay with confidence.',
                compact,
              ),
              const Spacer(),
              Container(
                height: 1,
                width: compact ? 200 : 280,
                color: Colors.white.withValues(alpha: .65),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF4BFF91),
                    size: 23,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Cabadbaran City, Agusan del Norte',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _feature(
    IconData icon,
    String title,
    String description,
    bool compact,
  ) {
    return Row(
      children: [
        Container(
          width: compact ? 48 : 70,
          height: compact ? 48 : 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _green.withValues(alpha: .85),
            border: Border.all(
              color: Colors.white.withValues(alpha: .25),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: compact ? 25 : 34,
          ),
        ),
        SizedBox(width: compact ? 12 : 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: compact ? 11 : 12,
                  height: 1.4,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormPanel({bool compact = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reduce spacing when the available height is limited.
        final bool tight = constraints.maxHeight < 760;
        final double horizontalPadding =
            compact ? 18 : (tight ? 22 : 36);
        final double cardPadding =
            compact ? 20 : (tight ? 22 : 30);
        final double fieldGap = tight ? 10 : 13;

        final formContent = Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: _deepGreen.withValues(alpha: .07),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _createAccount
                            ? Icons.person_add_alt_1_rounded
                            : Icons.lock_person_outlined,
                        color: _green,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F8F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: _green,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'BOARDMAP',
                            style: GoogleFonts.poppins(
                              color: _deepGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tight ? 14 : 20),
                Text(
                  _createAccount ? 'Create your account' : 'Welcome back!',
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 26 : (tight ? 27 : 31),
                    height: 1.2,
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _createAccount
                      ? 'Join BoardMap and discover your next home.'
                      : 'Sign in to continue exploring BoardMap.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64746B),
                    height: 1.6,
                  ),
                ),
                SizedBox(height: tight ? 18 : 24),

                if (_createAccount) ...[
                  _inputField(
                    controller: _nameController,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    validator: _required,
                    requiredField: true,
                    compact: compact || tight,
                  ),
                  SizedBox(height: fieldGap),
                  _inputField(
                    controller: _usernameController,
                    label: 'Username',
                    icon: Icons.alternate_email_rounded,
                    validator: _validUsername,
                    requiredField: true,
                    compact: compact || tight,
                  ),
                  SizedBox(height: fieldGap),
                ],

                _roleDropdown(compact: compact || tight),
                SizedBox(height: fieldGap),

                _inputField(
                  controller: _emailController,
                  label: _createAccount ? 'Email address' : 'Email or username',
                  icon: Icons.mail_outline_rounded,
                  validator: _createAccount ? _validEmail : _required,
                  requiredField: _createAccount,
                  compact: compact || tight,
                ),
                SizedBox(height: fieldGap),

                _inputField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _hidePassword,
                  validator: _validPassword,
                  requiredField: _createAccount,
                  compact: compact || tight,
                  suffix: IconButton(
                    tooltip: _hidePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _hidePassword = !_hidePassword;
                      });
                    },
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF738078),
                      size: 21,
                    ),
                  ),
                ),

                if (_createAccount) ...[
                  SizedBox(height: fieldGap),
                  _inputField(
                    controller: _confirmPasswordController,
                    label: 'Confirm password',
                    icon: Icons.lock_reset_rounded,
                    obscure: _hideConfirmPassword,
                    validator: _validConfirmPassword,
                    requiredField: true,
                    compact: compact || tight,
                    showLiveValidation: true,
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_passwordsMatch)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _successGreen,
                            size: 20,
                          ),
                        IconButton(
                          tooltip: _hideConfirmPassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              _hideConfirmPassword =
                                  !_hideConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _hideConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF738078),
                            size: 21,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _passwordsMatch
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: _passwordsMatch
                            ? _successGreen
                            : const Color(0xFF738078),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _passwordController.text.isEmpty ||
                                  _confirmPasswordController.text.isEmpty
                              ? 'Use at least 8 characters and confirm your password.'
                              : _passwordsMatch
                                  ? 'Your passwords match.'
                                  : 'Your passwords do not match yet.',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            height: 1.5,
                            color: _passwordsMatch
                                ? _successGreen
                                : const Color(0xFF738078),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme: CheckboxThemeData(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: _green,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text.rich(
                        TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _ink,
                          ),
                          children: const [
                            TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _green,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _green,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPassword,
                      style: TextButton.styleFrom(
                        foregroundColor: _deepGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                      ),
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: tight ? 12 : 18),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: _green.withValues(alpha: .22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _createAccount
                              ? Icons.person_add_alt_1_rounded
                              : Icons.login_rounded,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _createAccount ? 'Create account' : 'Sign in',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: tight ? 14 : 20),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.blueGrey.shade100,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF87938C),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.blueGrey.shade100,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: tight ? 14 : 20),

                SizedBox(
                  width: double.infinity,
                  height: 49,
                  child: OutlinedButton(
                    onPressed: _toggleForm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _deepGreen,
                      side: const BorderSide(
                        color: _borderColor,
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _createAccount
                              ? Icons.login_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          _createAccount
                              ? 'Back to sign in'
                              : 'Create an account',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: tight ? 14 : 20),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: _green,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'BoardMap • Cabadbaran City',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF718078),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

        // On desktop, keep the card in the available panel space.
        // On compact screens, scrolling prevents keyboard and height overflow.
        if (compact) {
          return Container(
            color: _mintBackground,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: formContent,
                ),
              ),
            ),
          );
        }

        return Container(
          color: _mintBackground,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: tight ? 12 : 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: formContent,
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleForm() {
    FocusScope.of(context).unfocus();

    setState(() {
      _createAccount = !_createAccount;
      _acceptTerms = false;
      _selectedRole = 'renter';
      _hidePassword = true;
      _hideConfirmPassword = true;

      // Avoid carrying validation messages into the other form.
      _nameController.clear();
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });

    _formKey.currentState?.reset();
  }

  Widget _roleDropdown({bool compact = false}) {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Account type',
        prefixIcon: const Icon(
          Icons.manage_accounts_outlined,
          color: _deepGreen,
          size: 20,
        ),
        filled: true,
        fillColor: _fieldBackground,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 13 : 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFD9E4DC),
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _green,
            width: 1.6,
          ),
        ),
      ),
      items: const [
        DropdownMenuItem<String>(
          value: 'renter',
          child: Text('Renter — find a boarding house'),
        ),
        DropdownMenuItem<String>(
          value: 'owner',
          child: Text('Owner — manage a boarding house'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedRole = value);
      },
      validator: (value) =>
          value == 'renter' || value == 'owner'
              ? null
              : 'Choose an account type.',
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscure = false,
    Widget? suffix,
    bool requiredField = false,
    bool showLiveValidation = false,
    bool compact = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      autovalidateMode: showLiveValidation
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      style: GoogleFonts.poppins(
        fontSize: 13,
        color: _ink,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        label: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: label),
              if (requiredField)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: _errorRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
        labelStyle: GoogleFonts.poppins(
          color: const Color(0xFF738078),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          color: _green,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          icon,
          color: _deepGreen,
          size: 20,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: _fieldBackground,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 13 : 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFD9E4DC),
            width: 1.1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _green,
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _errorRed,
            width: 1.1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _errorRed,
            width: 1.5,
          ),
        ),
        errorStyle: GoogleFonts.poppins(
          fontSize: 10,
          height: 1.3,
        ),
      ),
    );
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: const Icon(
          Icons.lock_reset_rounded,
          color: _green,
          size: 42,
        ),
        title: Text(
          'Forgot password?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        content: Text(
          'Password recovery needs to be connected to your authentication '
          'service before it can send a reset link.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.6,
            color: const Color(0xFF64746B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                color: _green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _green,
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: _mintBackground,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 850;

            if (compact) {
              return SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: constraints.maxHeight < 700 ? 350 : 430,
                        child: _buildPromoPanel(compact: true),
                      ),
                      _buildFormPanel(compact: true),
                    ],
                  ),
                ),
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 53,
                  child: _buildPromoPanel(),
                ),
                Expanded(
                  flex: 47,
                  child: _buildFormPanel(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}