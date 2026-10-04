import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class PrivacyBanner extends StatelessWidget {
  const PrivacyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.privacyGreen.withValues(alpha: 0.15)
        : AppColors.privacyGreenLight;
    final borderColor = AppColors.privacyGreen.withValues(alpha: 0.3);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.privacyGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppColors.privacyGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your files never leave your device',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '100% offline. Your privacy is always protected.',
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
