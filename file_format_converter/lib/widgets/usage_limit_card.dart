import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_providers.dart';

class UsageLimitCard extends ConsumerWidget {
  final VoidCallback onWatchAd;
  final VoidCallback onGoPro;

  const UsageLimitCard({
    super.key,
    required this.onWatchAd,
    required this.onGoPro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freemium = ref.watch(freemiumNotifierProvider);
    final countdown = ref.watch(countdownProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;
    final conversionWord =
        freemium.conversionsRemaining == 1 ? 'conversion' : 'conversions';

    if (freemium.isPro) {
      return _ProBadge();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowDark.withValues(alpha: 0.55),
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
          BoxShadow(
            color: shadowLight.withValues(alpha: 0.9),
            offset: const Offset(-6, -6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${freemium.conversionsRemaining} free $conversionWord today',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    countdown.when(
                      data: (time) => Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 13,
                              color: cs.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            'Resets in $time',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Usage bar
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value:
                  (freemium.conversionsUsed + freemium.conversionsRemaining) > 0
                      ? freemium.conversionsUsed /
                          (freemium.conversionsUsed +
                              freemium.conversionsRemaining)
                      : 0,
              minHeight: 6,
              backgroundColor: cs.onSurface.withValues(alpha: 0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14),
          // Watch Ad button
          GestureDetector(
            onTap: freemium.canWatchRewardedAd ? onWatchAd : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: freemium.canWatchRewardedAd
                        ? AppColors.primary
                        : cs.onSurface.withValues(alpha: 0.3),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    freemium.canWatchRewardedAd
                        ? 'Watch ad for extra conversions'
                        : 'No more ads available today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: freemium.canWatchRewardedAd
                          ? AppColors.primary
                          : cs.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Go Pro button
          GestureDetector(
            onTap: onGoPro,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.proStart, AppColors.proEnd],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.proStart.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Go Pro - Unlimited',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pro Member',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Unlimited conversions \u2022 No ads',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
