import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/home/main_scaffold.dart';
import 'features/pro/pro_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/auth/login_screen.dart';
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
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // ── Start analytics session for ALL users on app open ──────────────────
    // This ensures every device is registered in Supabase (even anonymous
    // users) so the admin app can see them and control their plan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnalyticsSession();
    });

    // ── Listen for Supabase auth state changes ─────────────────────────────
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.event == AuthChangeEvent.signedOut) {
          // Restart session as anonymous after sign-out.
          unawaited(_startAnalyticsSession());
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/login', (r) => false);
        } else if (data.session != null) {
          // Re-register with the signed-in user ID and refresh quota.
          unawaited(_onSignedIn(data.session!));
        }
      },
      onError: (_, __) {},
    );
  }

  // ── Session helpers ────────────────────────────────────────────────────────

  /// Always starts an analytics session (signed-in OR anonymous).
  Future<void> _startAnalyticsSession() async {
    // Inject DatabaseManager into the singleton.
    AnalyticsService().injectDb(ref.read(databaseManagerProvider));

    // Register device + start Realtime plan listener for ALL users.
    await AnalyticsService().initSession(onPlanUpdated: _applyPlan);
  }

  /// Called only when a Supabase auth session is active.
  Future<void> _onSignedIn(Session session) async {
    // Bind quota service to the account ID.
    await ref
        .read(freemiumNotifierProvider.notifier)
        .bindAccount(session.user.id);
    if (!mounted) return;

    // Fetch remote quota (conversion counter sync).
    await _refreshAccountQuota();
    if (!mounted) return;

    // Restart analytics session so it uses the user ID, not hardware ID.
    await _startAnalyticsSession();
  }

  Future<void> _refreshAccountQuota() async {
    final snapshot = await ref.read(accountQuotaServiceProvider).fetchToday();
    if (!mounted || snapshot == null) return;
    ref.read(freemiumNotifierProvider.notifier).applyAccountQuota(snapshot);
  }

  /// Called by Realtime whenever the admin changes this device's plan.
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
    _authSubscription?.cancel();
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
        '/login': (_) => const LoginScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/home': (_) => const MainScaffold(),
        '/pro': (_) => const ProScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
