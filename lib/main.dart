// Copyright 2026 Tuhin Garai. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:yet_another_luci_app/state/app_state.dart';
import 'package:yet_another_luci_app/screens/login_screen.dart';
import 'package:yet_another_luci_app/screens/main_screen.dart';
import 'package:yet_another_luci_app/screens/settings_screen.dart';
import 'package:yet_another_luci_app/screens/splash_screen.dart';
import 'package:yet_another_luci_app/screens/onboarding_screen.dart';

import 'package:yet_another_luci_app/models/router_capabilities.dart';
import 'package:yet_another_luci_app/modules/built_in_modules.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';

import 'package:yet_another_luci_app/services/ad_consent_service.dart';
import 'package:yet_another_luci_app/config/app_config.dart';
import 'package:yet_another_luci_app/widgets/luci_toast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

void main() {
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Low-RAM & Smooth Scrolling Optimization: Cap image memory cache (30MB max, 100 entries max)
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 100;

  registerBuiltInModules();

  runApp(
    const ProviderScope(
      child: LuCIApp(),
    ),
  );

  // Defer secondary bindings & SDK initializations post-first-frame to eliminate startup latency
  binding.addPostFrameCallback((_) {
    SemanticsBinding.instance.ensureSemantics();
    if (AppConfig.isAdsEnabled) {
      _initDeferredAds();
    }
  });
}

/// Standardized scroll behavior ensuring native long/autoscroll screenshot engine compatibility
/// across all Android OEMs (Xiaomi MIUI/HyperOS, Samsung OneUI, Oppo ColorOS, Vivo FuntouchOS, Stock Android 12+).
class LuciScrollBehavior extends MaterialScrollBehavior {
  const LuciScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

Future<void> _initDeferredAds() async {
  try {
    await MobileAds.instance.initialize();
    if (kDebugMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: const []),
      );
    }
    await AdConsentService.initializeConsentAndAds();
  } catch (e) {
    debugPrint('MobileAds deferred initialization skipped or failed: $e');
  }
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
      navigatorKey: LuciToastManager.navigatorKey,
      title: 'Yet Another LuCI App',
      restorationScopeId: 'root_luci_app',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const LuciScrollBehavior(),
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
        splashFactory: InkRipple.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          },
        ),
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        expansionTileTheme: const ExpansionTileThemeData(
          shape: Border(),
          collapsedShape: Border(),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        expansionTileTheme: const ExpansionTileThemeData(
          shape: Border(),
          collapsedShape: Border(),
        ),
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
        splashFactory: InkRipple.splashFactory,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          },
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF151D30),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF151D30),
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
