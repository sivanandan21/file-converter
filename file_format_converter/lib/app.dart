import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/main_scaffold.dart';
import 'features/pro/pro_screen.dart';
import 'features/settings/settings_screen.dart';
import 'providers/app_providers.dart';
import 'core/database/db_providers.dart';
import 'services/analytics_service.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // ── Start analytics session for ALL users on app open ──────────────────
    // Registers device in AWS DynamoDB so admin can see and control plan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnalyticsSession();
    });
  }

  // ── Session helpers ────────────────────────────────────────────────────────

  /// Starts an analytics session and registers device in DynamoDB.
  Future<void> _startAnalyticsSession() async {
    // Inject DatabaseManager into the singleton.
    AnalyticsService().injectDb(ref.read(databaseManagerProvider));

    // Register device + start periodic plan poller for all users.
    await AnalyticsService().initSession(onPlanUpdated: _applyPlan);
  }

  /// Called whenever the admin changes this device's plan.
  void _applyPlan(String plan) {
    if (!mounted) return;
    if (plan == 'premium' || plan == 'lifetime') {
      unawaited(ref.read(freemiumNotifierProvider.notifier).activatePro());
    } else {
      unawaited(ref.read(freemiumNotifierProvider.notifier).deactivatePro());
    }
  }

  @override
  void dispose() {
    AnalyticsService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(darkModeProvider);

    return MaterialApp(
      title: 'File Format Converter',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/home': (_) => const MainScaffold(),
        '/pro': (_) => const ProScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

