import 'package:flutter/material.dart';

import 'data/demo_store.dart';

/// The theme preference is local presentation state, never an authorization value.
class BoardMapThemeController extends ChangeNotifier {
  BoardMapThemeController._() {
    String? saved;
    try {
      saved = readDemoValue(_storageKey);
    } catch (_) {
      // Theme preference is optional; keep the app usable when browser storage
      // is disabled or unavailable.
    }
    _mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static final BoardMapThemeController instance = BoardMapThemeController._();
  static const _storageKey = 'boardmap.themeMode';
  late ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      writeDemoValue(_storageKey, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
    } catch (_) {
      // A storage failure must not prevent the in-memory theme from changing.
    }
  }
}

class BoardMapThemeToggle extends StatelessWidget {
  const BoardMapThemeToggle({super.key, this.foregroundColor});
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final controller = BoardMapThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // ThemeMode.system has no explicit dark/light value. Read the actual
        // brightness shown by MaterialApp so the first tap always flips it.
        final dark = Theme.of(context).brightness == Brightness.dark;
        return IconButton(
          tooltip: dark
              ? 'Switch to light appearance'
              : 'Switch to dark appearance',
          color: foregroundColor ?? Theme.of(context).colorScheme.onSurface,
          onPressed: () => controller.setMode(
            dark ? ThemeMode.light : ThemeMode.dark,
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              key: ValueKey(dark),
            ),
          ),
        );
      },
    );
  }
}
