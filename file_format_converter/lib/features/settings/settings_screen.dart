import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../pro/pro_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(freemiumNotifierProvider).isPro;
    final darkMode = ref.watch(darkModeProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pro banner
          if (!isPro)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProScreen()),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.proStart, AppColors.proEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.proStart.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text('\u{1F451}', style: TextStyle(fontSize: 28)),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upgrade to Pro',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Unlimited • Ad-free • Batch',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),

          // Appearance section
          const _SectionHeader('Appearance'),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            label: 'Dark Mode',
            trailing: Switch.adaptive(
              value: darkMode,
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
              onChanged: (v) => ref.read(darkModeProvider.notifier).set(v),
            ),
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Data'),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            label: 'Clear Conversion History',
            iconColor: AppColors.error,
            onTap: () => _confirmClearHistory(context, ref),
          ),

          const SizedBox(height: 20),
          const _SectionHeader('Account'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            iconColor: AppColors.error,
            onTap: () => _confirmLogout(context, ref),
          ),

          const SizedBox(height: 20),
          const _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _launchUrl('https://fileconverter-smc.netlify.app/#policy'),
          ),
          _SettingsTile(
            icon: Icons.gavel_rounded,
            label: 'Terms of Service',
            onTap: () => _launchUrl('https://fileconverter-smc.netlify.app/#policy'),
          ),
          _SettingsTile(
            icon: Icons.star_outline_rounded,
            label: 'Rate the App',
            onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.smc.fileconverter'),
          ),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            label: 'Contact Support',
            onTap: () => _launchUrl('mailto:privacy@smc-apps.com?subject=File%20Converter%20Support'),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'App Version',
            trailing: Text(
              AppConstants.appVersion,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Text(
                  '\u{1F512} Offline-first \u2022 No upload \u2022 Private',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your files never leave your device.',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // silently fail — user can try again
    }
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear History'),
        content: const Text(
            'This will remove all conversion history records. Output files will not be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(conversionHistoryNotifierProvider.notifier).clearAll();
            },
            child:
                const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onSurface.withValues(alpha: 0.4),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowDark.withValues(alpha: 0.35),
              offset: const Offset(4, 4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: shadowLight.withValues(alpha: 0.9),
              offset: const Offset(-4, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right_rounded,
                        size: 20, color: cs.onSurface.withValues(alpha: 0.4))
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
