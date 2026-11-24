import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boardmap_project/screens/renter_home_screen.dart';
import 'package:boardmap_project/screens/owner_home_screen.dart';
import 'package:boardmap_project/screens/admin_home_screen.dart';
import 'package:boardmap_project/services/api_service.dart';
import 'package:boardmap_project/theme_controller.dart';

const Color _green = Color(0xFF00843D);
const Color _deepGreen = Color(0xFF003D2D);
const Color _borderColor = Color(0xFFDCEBE1);
const Color _errorRed = Color(0xFFD32F2F);
const Color _successGreen = Color(0xFF16834A);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.startInRegister = false});
  final bool startInRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _createAccount = false;
  bool _acceptTerms = false;
  bool _isLoading = false;
  bool _roleConfirmed = false;
  String? _successMessage;

  String? _selectedRole;

  bool get _passwordsMatch =>
      _confirmPasswordController.text.isNotEmpty &&
      _confirmPasswordController.text == _passwordController.text;

  @override
  void initState() {
    super.initState();
    _createAccount = widget.startInRegister;
    // Revalidate confirmation when either password changes.
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  void _onPasswordChanged() {
    if (!mounted) return;

    // Refresh the live match indicator and any existing confirmation error.
    if (_createAccount && _confirmPasswordController.text.isNotEmpty) {
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

    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_createAccount && !_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms and privacy policy.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_createAccount) {
        await BoardMapApi.instance.register(
              fullName:
                  '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
              email: _emailController.text.trim(),
              password: _passwordController.text,
              role: _selectedRole!,
              contactNumber: _contactController.text.trim(),
            );
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _createAccount = false;
          _roleConfirmed = false;
          _successMessage =
              'Account created successfully. Sign in with your email and password.';
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
        return;
      }
      final session = await BoardMapApi.instance.login(
              _emailController.text.trim(),
              _passwordController.text,
            );
      if (!mounted) return;
      setState(() => _isLoading = false);
      final user = session['user'] as Map<String, dynamic>;
      _openDashboard(user['role'] as String? ?? 'renter');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _openDashboard(String role) {
    final Widget homeScreen = switch (role) {
      'admin' => const AdminHomeScreen(),
      'owner' => const OwnerHomeScreen(),
      _ => const RenterHomeScreen(),
    };
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => homeScreen));
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

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validContactNumber(String? value) {
    final number = (value ?? '').trim();
    if (number.isEmpty) return 'Enter a contact number.';
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || !RegExp(r'^[+0-9() .-]+$').hasMatch(number)) {
      return 'Use 7 or more digits; spaces, +, and hyphens are okay.';
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
          errorBuilder: (_, _, _) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF277A83), _deepGreen, Color(0xFF00291F)],
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
            compact ? 12 : 20,
            compact ? 25 : 48,
            compact ? 12 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'lib/assets/images/cbr_boardmap_logo.png',
                width: compact ? 105 : 145,
                height: compact ? 64 : 120,
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
              Text(
                'BoardMap',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 18 : 22,
                ),
              ),
              SizedBox(height: compact ? 5 : 20),
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
              SizedBox(height: compact ? 8 : 24),
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
                  fontSize: compact ? 24 : 39,
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
              SizedBox(height: compact ? 7 : 16),
              Text(
                compact ? 'Discover boarding houses in Cabadbaran City.' : 'Discover boarding houses with a smarter,\nmap-based way to explore your next home.',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: compact ? 13 : 15,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 28),
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
                            Shadow(color: Colors.black, blurRadius: 3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
          ),
          child: Icon(icon, color: Colors.white, size: compact ? 25 : 34),
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
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: compact ? 11 : 12,
                  height: 1.4,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
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
        final colors = Theme.of(context).colorScheme;
        // Reduce spacing when the available height is limited.
        final bool tight = constraints.maxHeight < 760;
        if (_createAccount && !_roleConfirmed) {
          return _buildRoleSelectionPanel(compact: compact || tight);
        }
        final double horizontalPadding = compact ? 18 : (tight ? 22 : 36);
        final double cardPadding = compact ? 20 : (tight ? 22 : 30);
        final double fieldGap = tight ? 10 : 13;

        final formContent = Container(
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
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
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _createAccount
                            ? Icons.person_add_alt_1_rounded
                            : Icons.lock_person_outlined,
                        color: colors.primary,
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
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: colors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'BOARDMAP',
                            style: GoogleFonts.poppins(
                              color: colors.onSurface,
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
                    color: colors.onSurface,
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
                    color: colors.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                if (_successMessage case final success?) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      success,
                      style: TextStyle(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: tight ? 18 : 24),

                if (_createAccount) ...[
                  _inputField(
                    controller: _firstNameController,
                    label: 'First name',
                    icon: Icons.person_outline_rounded,
                    validator: _required,
                    requiredField: true,
                    compact: compact || tight,
                  ),
                  SizedBox(height: fieldGap),
                  _inputField(
                    controller: _lastNameController,
                    label: 'Last name',
                    icon: Icons.person_outline_rounded,
                    validator: _required,
                    requiredField: true,
                    compact: compact || tight,
                  ),
                  SizedBox(height: fieldGap),
                ],

                if (_createAccount) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedRole == 'owner'
                              ? 'Owner account'
                              : 'Renter account',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: _deepGreen,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _roleConfirmed = false),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  SizedBox(height: fieldGap),
                ],

                _inputField(
                  controller: _emailController,
                  label: _createAccount ? 'Email address' : 'Email or username',
                  icon: Icons.mail_outline_rounded,
                  validator: _createAccount ? _validEmail : _required,
                  requiredField: _createAccount,
                  compact: compact || tight,
                ),
                SizedBox(height: fieldGap),

                if (_createAccount) ...[
                  _inputField(
                    controller: _contactController,
                    label: 'Contact number',
                    icon: Icons.phone_outlined,
                    validator: _validContactNumber,
                    requiredField: true,
                    compact: compact || tight,
                  ),
                  SizedBox(height: fieldGap),
                ],

                _inputField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _hidePassword,
                  validator: _validPassword,
                  requiredField: _createAccount,
                  compact: compact || tight,
                  suffix: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _hidePassword = !_hidePassword;
                      });
                    },
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: colors.onSurfaceVariant,
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
                              _hideConfirmPassword = !_hideConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _hideConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: colors.onSurfaceVariant,
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
                            : colors.onSurfaceVariant,
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
                                : colors.onSurfaceVariant,
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
                    child: Material(
                      color: Colors.transparent,
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
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: _green.withValues(alpha: .22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Row(
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
                              const Icon(Icons.arrow_forward_rounded, size: 17),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: tight ? 14 : 20),

                Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: GoogleFonts.poppins(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
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
                      side: const BorderSide(color: _borderColor, width: 1.4),
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
                            color: colors.onSurfaceVariant,
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
            color: Theme.of(context).scaffoldBackgroundColor,
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
          color: Theme.of(context).scaffoldBackgroundColor,
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
      _successMessage = null;
      _createAccount = !_createAccount;
      _acceptTerms = false;
      _selectedRole = null;
      _roleConfirmed = false;
      _hidePassword = true;
      _hideConfirmPassword = true;

      // Avoid carrying validation messages into the other form.
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _contactController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });

    _formKey.currentState?.reset();
  }

  Widget _buildRoleSelectionPanel({bool compact = false}) => Container(
    color: Theme.of(context).scaffoldBackgroundColor,
    alignment: Alignment.center,
    child: SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 18 : 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 20 : 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.map_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'How will you use BoardMap?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the account that fits what you need. You can continue to the matching sign-up form next.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                _roleCards(compact: compact),
                if (_selectedRole != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _selectedRole == 'renter'
                        ? 'Find boarding houses, explore map locations, compare prices, save favorites, and contact owners.'
                        : 'Add and manage properties, update availability, respond to renter inquiries, and review listing status.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _selectedRole == null
                        ? null
                        : () => setState(() => _roleConfirmed = true),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continue to sign up'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _toggleForm,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _roleCards({bool compact = false}) {
    return FormField<String>(
      initialValue: _selectedRole,
      validator: (value) => value == 'renter' || value == 'owner'
          ? null
          : 'Choose a role to continue.',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your account type',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 7 : 9),
          Row(
            children: [
              Expanded(
                child: _roleChoiceCard(
                  field,
                  'renter',
                  Icons.search_rounded,
                  'Renter',
                  'Find and save homes',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _roleChoiceCard(
                  field,
                  'owner',
                  Icons.home_work_outlined,
                  'Owner',
                  'Manage listings',
                ),
              ),
            ],
          ),
          if (field.errorText != null) ...[
            const SizedBox(height: 5),
            Text(
              field.errorText!,
              style: GoogleFonts.poppins(color: _errorRed, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _roleChoiceCard(
    FormFieldState<String> field,
    String role,
    IconData icon,
    String title,
    String description,
  ) {
    final selected = field.value == role;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $description',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          field.didChange(role);
          setState(() => _selectedRole = role);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected
                ? colors.secondaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget roleDropdown({bool compact = false}) {
    final colors = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Account type',
        prefixIcon: const Icon(
          Icons.manage_accounts_outlined,
          color: _deepGreen,
          size: 20,
        ),
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 13 : 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E4DC), width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.6),
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
      validator: (value) => value == 'renter' || value == 'owner'
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
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      autovalidateMode: showLiveValidation
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      style: GoogleFonts.poppins(
        fontSize: 13,
        color: colors.onSurface,
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
          color: colors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          color: _green,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: colors.primary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 13 : 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9E4DC), width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1.1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _errorRed, width: 1.5),
        ),
        errorStyle: GoogleFonts.poppins(fontSize: 10, height: 1.3),
      ),
    );
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_reset_rounded, color: _green, size: 42),
        title: Text(
          'Forgot password?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Password recovery needs to be connected to your authentication '
          'service before it can send a reset link.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.6,
            color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
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
      data: Theme.of(context),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            LayoutBuilder(
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
                    Expanded(flex: 53, child: _buildPromoPanel()),
                    Expanded(flex: 47, child: _buildFormPanel()),
                  ],
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: Material(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: .9),
                  shape: const CircleBorder(),
                  child: const BoardMapThemeToggle(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
