import 'package:flutter/material.dart';

import 'boardmap_theme.dart';
import 'data/demo_store.dart';
import 'screens/report_form_screen.dart';
import 'screens/login_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/issue_reports_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/owner_home_screen.dart';
import 'screens/renter_home_screen.dart';
import 'services/api_service.dart';
import 'theme_controller.dart';

void main() {
  // Remove credentials from the old local-only demo login implementation.
  removeDemoValue('cbrBoardMap.demoAccounts');
  removeDemoValue('cbrBoardMap.activeDemoSession');
  runApp(const BoardMapApp());
}

class BoardMapApp extends StatelessWidget {
  const BoardMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = BoardMapThemeController.instance;
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        title: 'BoardMap',
        debugShowCheckedModeBanner: false,
        theme: BoardMapTheme.light(),
        darkTheme: BoardMapTheme.dark(),
        themeAnimationDuration: const Duration(milliseconds: 240),
        themeAnimationCurve: Curves.easeInOut,
        themeMode: themeController.mode,
        home: const _SessionGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/report': (context) => const ReportFormScreen(),
          '/reports/my': (context) => const MyIssueReportsScreen(),
        },
      ),
    );
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  Map<String, dynamic>? _user;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await BoardMapApi.instance.restoreSession();
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _restore,
                      child: const Text('Retry'),
                    ),
                    FilledButton(
                      onPressed: () => setState(() {
                        BoardMapApi.instance.logout();
                        _error = null;
                      }),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final role = _user?['role'];
    if (role == 'admin') return const AdminHomeScreen();
    if (role == 'owner') return const OwnerHomeScreen();
    if (role == 'renter') return const RenterHomeScreen();
    return const LandingScreen();
  }
}
