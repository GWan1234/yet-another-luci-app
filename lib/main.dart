import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/screens/login_screen.dart';
import 'package:luci_mobile/screens/main_screen.dart';
import 'package:luci_mobile/screens/settings_screen.dart';
import 'package:luci_mobile/screens/splash_screen.dart';
import 'package:luci_mobile/screens/onboarding_screen.dart';

import 'package:luci_mobile/modules/built_in_modules.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerBuiltInModules();
  runApp(ProviderScope(child: const LuCIApp()));
}

final appStateProvider = ChangeNotifierProvider<AppState>(
  (ref) => AppState.instance,
);

class LuCIApp extends ConsumerWidget {
  const LuCIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    
    // Custom High-End Cyber Emerald Theme Palette
    const emeraldPrimary = Color(0xFF10B981);
    const cyanSecondary = Color(0xFF06B6D4);

    return MaterialApp(
      title: 'Yet Another LuCI App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emeraldPrimary,
          primary: emeraldPrimary,
          secondary: cyanSecondary,
          surface: const Color(0xFFFFFFFF),
          surfaceContainer: const Color(0xFFF8FAFC),
          surfaceContainerHighest: const Color(0xFFE2E8F0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: const Color(0xFFFFFFFF),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emeraldPrimary,
          primary: emeraldPrimary,
          secondary: cyanSecondary,
          surface: const Color(0xFF131B2E),
          surfaceContainer: const Color(0xFF1B2640),
          surfaceContainerHighest: const Color(0xFF243356),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF8FAFC),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: const Color(0xFF131B2E),
        ),
      ),
      themeMode: appState.themeMode,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/': (context) => const MainScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
