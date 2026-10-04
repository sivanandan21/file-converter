import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/buttons.dart';

class _FeatureData {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool comingSoon;
  const _FeatureData(this.icon, this.title, this.subtitle,
      {this.comingSoon = false});
}

class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  static const _features = [
    _FeatureData(Icons.all_inclusive_rounded, 'Unlimited Conversions',
        'No daily limits, convert as much as you need'),
    _FeatureData(
        Icons.block_rounded, 'No Ads', 'Enjoy a completely ad-free experience'),
    _FeatureData(Icons.layers_rounded, 'Batch Conversion',
        'Convert multiple files at once'),
    _FeatureData(Icons.document_scanner_rounded, 'OCR Support',
        'Extract text from scanned documents'),
    _FeatureData(
        Icons.lock_rounded, 'Password PDF', 'Open & create encrypted PDF files',
        comingSoon: true),
    _FeatureData(Icons.bolt_rounded, 'Priority Speed',
        'Faster processing with Pro queue'),
    _FeatureData(Icons.cloud_upload_rounded, 'Cloud Backup',
        'Backup converted files to cloud',
        comingSoon: true),
  ];

  static const _plans = [
    _PlanData(
      id: 'monthly',
      label: 'Monthly',
      price: '\u20b999',
      period: '/month',
      badge: null,
    ),
    _PlanData(
      id: 'yearly',
      label: 'Yearly',
      price: '\u20b9699',
      period: '/year',
      badge: 'Best Value',
    ),
    _PlanData(
      id: 'lifetime',
      label: 'Lifetime',
      price: '\u20b91499',
      period: 'one-time',
      badge: 'Most Popular',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(freemiumNotifierProvider).isPro;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.proStart, AppColors.proEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          if (isPro)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('\u2713 Active',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Icon(Icons.workspace_premium_rounded,
                        size: 64, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'File Format Converter Pro',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unlimited. Ad-free. Powerful.',
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Features
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you get',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: shadowDark.withValues(alpha: 0.4),
                          offset: const Offset(5, 5),
                          blurRadius: 12,
                        ),
                        BoxShadow(
                          color: shadowLight.withValues(alpha: 0.9),
                          offset: const Offset(-5, -5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Column(
                      children: _features.indexed.map((item) {
                        final (i, f) = item;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            border: i < _features.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                      color:
                                          cs.onSurface.withValues(alpha: 0.08),
                                    ),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(f.icon,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          f.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: cs.onSurface,
                                          ),
                                        ),
                                        if (f.comingSoon) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.warning
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Soon',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.warning,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle_rounded,
                                color: f.comingSoon
                                    ? cs.onSurface.withValues(alpha: 0.3)
                                    : AppColors.success,
                                size: 20,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pricing Plans
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._plans.map((plan) => _PlanCard(
                        plan: plan,
                        onTap: () => _subscribe(context, ref, plan),
                        isDark: isDark,
                      )),
                ],
              ),
            ),
          ),

          // Footer
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Text(
                    'Cancel anytime. Payments processed securely.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (!isPro)
                    SecondaryButton(
                      label: 'Restore Purchase',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'In-app billing coming soon. Contact support if you need help.',
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _subscribe(BuildContext context, WidgetRef ref, _PlanData plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${plan.label} Plan'),
        content: Text(
          'This is a demo. Tap Activate to simulate purchasing ${plan.label} Pro for ${plan.price}.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(freemiumNotifierProvider.notifier).activatePro();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Welcome to Pro! Enjoy unlimited conversions.'),
                    backgroundColor: AppColors.success,
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Activate Pro'),
          ),
        ],
      ),
    );
  }
}

class _PlanData {
  final String id;
  final String label;
  final String price;
  final String period;
  final String? badge;

  const _PlanData({
    required this.id,
    required this.label,
    required this.price,
    required this.period,
    this.badge,
  });
}

class _PlanCard extends StatefulWidget {
  final _PlanData plan;
  final VoidCallback onTap;
  final bool isDark;

  const _PlanCard(
      {required this.plan, required this.onTap, required this.isDark});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isPopular = widget.plan.badge != null;
    final cs = Theme.of(context).colorScheme;
    final cardBg =
        widget.isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark =
        widget.isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        widget.isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: isPopular
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5), width: 2)
              : null,
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: shadowDark.withValues(alpha: 0.4),
                    offset: const Offset(2, 2),
                    blurRadius: 6,
                  ),
                ]
              : [
                  BoxShadow(
                    color: shadowDark.withValues(alpha: 0.45),
                    offset: const Offset(5, 5),
                    blurRadius: 12,
                  ),
                  BoxShadow(
                    color: shadowLight.withValues(alpha: 0.9),
                    offset: const Offset(-5, -5),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.plan.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      if (widget.plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.proStart, AppColors.proEnd],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.plan.badge!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.plan.price,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  widget.plan.period,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
