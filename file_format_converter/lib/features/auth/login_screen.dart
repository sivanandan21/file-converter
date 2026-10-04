import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (data.session != null && mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      },
      onError: (_, __) {},
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.smc.fileconverter://login-callback/',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkCardColor : AppColors.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark
                                ? AppColors.darkShadowDark
                                : AppColors.shadowDark)
                            .withValues(alpha: 0.6),
                        offset: const Offset(8, 8),
                        blurRadius: 20,
                      ),
                      BoxShadow(
                        color: (isDark
                                ? AppColors.darkShadowLight
                                : AppColors.shadowLight)
                            .withValues(alpha: 0.9),
                        offset: const Offset(-8, -8),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome to\n${AppConstants.appName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to sync your conversions and unlock features.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? const Color(0xFF1E2433) : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata_rounded,
                            size: 36, color: Color(0xFFDB4437)),
                    label: const Text(
                      'Continue with Google',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
