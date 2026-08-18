// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:luci_mobile/state/app_state.dart';
import 'package:luci_mobile/screens/login_screen.dart';
import 'package:luci_mobile/screens/main_screen.dart';
import 'package:luci_mobile/screens/settings_screen.dart';
import 'package:luci_mobile/screens/splash_screen.dart';
import 'package:luci_mobile/screens/onboarding_screen.dart';

import 'package:luci_mobile/models/router_capabilities.dart';
import 'package:luci_mobile/modules/built_in_modules.dart';

import 'package:flutter/foundation.dart';

import 'package:luci_mobile/services/ad_consent_service.dart';
import 'package:luci_mobile/config/app_config.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isAdsEnabled) {
    try {
      await MobileAds.instance.initialize();

      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: const [],
          ),
        );
      }

      await AdConsentService.initializeConsentAndAds();
    } catch (e) {
      debugPrint('MobileAds initialization skipped or failed: $e');
    }
  }

  registerBuiltInModules();
  runApp(
    const ProviderScope(
      child: LuCIApp(),
    ),
  );
}

final appStateProvider = ChangeNotifierProvider<AppState>(
  (ref) => AppState.instance,
);

final routerCapabilitiesProvider = Provider<RouterCapabilities?>((ref) {
  return ref.watch(appStateProvider).capabilities;
});

class LuCIApp extends ConsumerWidget {
  const LuCIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    // Official nightcode Brand Accent Palette (Orange #F97316 & Amber #FB923C)
    const orangePrimary = Color(0xFFF97316);
    const orangeSecondary = Color(0xFFFB923C);

    return MaterialApp(
      title: 'Yet Another LuCI App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orangePrimary,
          primary: orangePrimary,
          secondary: orangeSecondary,
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
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: orangePrimary,
          primary: orangePrimary,
          secondary: orangeSecondary,
          surface: const Color(0xFF151D30),
          surfaceContainer: const Color(0xFF1C2840),
          surfaceContainerHighest: const Color(0xFF243356),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1523),
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
          color: const Color(0xFF151D30),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF151D30),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
