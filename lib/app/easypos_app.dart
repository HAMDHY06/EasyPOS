import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import '../features/setup/setup_screen.dart';
import '../features/shell/home_shell.dart';

class EasyPosApp extends StatelessWidget {
  const EasyPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EasyPOS',
      themeMode: state.themeMode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home:
          !state.initialized
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : state.setupComplete
              ? const HomeShell()
              : const SetupScreen(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    const seed = Color(0xFF1565C0);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light
              ? const Color(0xFFF5F7FB)
              : const Color(0xFF101318),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
    );
  }
}
