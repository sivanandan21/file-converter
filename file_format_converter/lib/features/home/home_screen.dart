import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/conversion_card.dart';
import '../../widgets/usage_limit_card.dart';
import '../../widgets/privacy_banner.dart';
import '../../widgets/file_row_tile.dart';
import '../../widgets/neumorphic_card.dart';
import '../convert/convert_screen.dart';
import '../pro/pro_screen.dart';
import '../../services/app_update_service.dart';
import '../../widgets/update_dialog_3d.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;
  double _scrollOffset = 0.0;

  static final List<ConversionCardData> _cards = [
    const ConversionCardData(
      type: ConversionType.pdfToImage,
      title: AppConstants.pdfToImage,
      subtitle: 'Convert PDF pages\nto images',
      fromIcon: PdfIcon(),
      toIcon: FileImageIcon(),
    ),
    const ConversionCardData(
      type: ConversionType.imageToPdf,
      title: AppConstants.imageToPdf,
      subtitle: 'Convert images to\na PDF file',
      fromIcon: FileImageIcon(),
      toIcon: PdfIcon(),
    ),
    const ConversionCardData(
      type: ConversionType.pdfToDocx,
      title: AppConstants.pdfToDocx,
      subtitle: 'Convert PDF to\nWord document',
      fromIcon: PdfIcon(),
      toIcon: DocxIcon(),
    ),
    const ConversionCardData(
      type: ConversionType.docxToPdf,
      title: AppConstants.docxToPdf,
      subtitle: 'Convert Word document\nto PDF',
      fromIcon: DocxIcon(),
      toIcon: PdfIcon(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (mounted) {
          setState(() {
            _scrollOffset = _scrollController.offset;
          });
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForAppUpdate();
    });
  }

  Future<void> _checkForAppUpdate() async {
    try {
      final update = await AppUpdateService().checkForUpdate();
      if (update != null && mounted) {
        UpdateDialog3D.show(context, update);
      }
    } catch (e) {
      debugPrint('App update check error: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onConversionCardTap(
    BuildContext context,
    WidgetRef ref,
    ConversionCardData card,
  ) async {
    await _refreshAccountQuota(ref);
    if (!context.mounted) return;

    final freemium = ref.read(freemiumNotifierProvider);
    if (!freemium.canConvert && !freemium.isPro) {
      _showLimitDialog(context, ref);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ConvertScreen(conversionType: card.type, title: card.title),
      ),
    );
  }

  Future<void> _refreshAccountQuota(WidgetRef ref) async {
    final snapshot = await ref.read(accountQuotaServiceProvider).fetchToday();
    if (snapshot == null) return;
    ref.read(freemiumNotifierProvider.notifier).applyAccountQuota(snapshot);
  }

  void _showLimitDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'No-Entry Daily Limit Reached',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'You have used all ${AppConstants.freeConversionsPerDay} free conversions for today.\nWatch an ad to get ${AppConstants.conversionsPerRewardedAd} more, or upgrade to Pro.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _watchAd(context, ref);
            },
            child: const Text('Watch Ad'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProScreen()),
              );
            },
            child: const Text('Go Pro'),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAd(BuildContext context, WidgetRef ref) async {
    await _refreshAccountQuota(ref);
    if (!context.mounted) return;

    final freemium = ref.read(freemiumNotifierProvider);
    if (!freemium.canWatchRewardedAd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more rewarded ads available today.')),
      );
      return;
    }
    final adService = ref.read(adServiceProvider);
    final earned = await adService.showRewardedAd();
    if (!context.mounted) return;

    if (earned) {
      final freemiumNotifier = ref.read(freemiumNotifierProvider.notifier);
      final accountQuota = ref.read(accountQuotaServiceProvider);
      await freemiumNotifier.recordRewardedAd();
      final quotaSnapshot = await accountQuota.recordRewardedAd();
      if (quotaSnapshot != null) {
        freemiumNotifier.applyAccountQuota(quotaSnapshot);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('+${AppConstants.conversionsPerRewardedAd} conversions unlocked.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(conversionHistoryNotifierProvider);
    final recent = history.take(3).toList();
    final cs = Theme.of(context).colorScheme;

    // Calculate parallax offsets
    final headerParallax = (_scrollOffset * 0.15).clamp(0.0, 20.0);
    final tiltAngle = (_scrollOffset * 0.0003).clamp(-0.06, 0.06);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NeumorphicIconButton(
                      onTap: () {},
                      child: const Icon(Icons.menu_rounded,
                          size: 22, color: AppColors.textSecondary),
                    ),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(tiltAngle)
                        ..translateByDouble(0.0, -headerParallax, 0.0, 1.0),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: NeumorphicDecoration.circle(),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 28,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    NeumorphicIconButton(
                      onTap: () {},
                      child: const Icon(Icons.shield_rounded,
                          size: 22, color: AppColors.privacyGreen),
                    ),
                  ],
                ),
              ),
            ),
            // ── Title ─────────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Transform.translate(
                  offset: Offset(0, -headerParallax * 0.5),
                  child: const Column(
                    children: [
                      Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6),
                      Text(
                        AppConstants.appSubtitle,
                        style: TextStyle(
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Conversion Grid ───────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => ConversionCard(
                    data: _cards[i],
                    onTap: () => _onConversionCardTap(context, ref, _cards[i]),
                  ),
                  childCount: _cards.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.0,
                ),
              ),
            ),
            // ── Usage Limit Card ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: UsageLimitCard(
                  onWatchAd: () => _watchAd(context, ref),
                  onGoPro: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProScreen()),
                    );
                  },
                ),
              ),
            ),
            // ── Privacy Banner ────────────────────────────────────────────────
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: PrivacyBanner()),
            ),
            // ── Recent Files header ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Files',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(activeNavIndexProvider.notifier).state = 1,
                      child: const Row(
                        children: [
                          Text(
                            'View all',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Recent Files list ─────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              sliver: recent.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyRecentWidget())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => FileRowTile(
                          record: recent[i],
                          onStar: () => ref
                              .read(conversionHistoryNotifierProvider.notifier)
                              .toggleStar(recent[i].id),
                          onMore: () =>
                              _showFileOptions(context, ref, recent[i].id),
                        ),
                        childCount: recent.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileOptions(BuildContext context, WidgetRef ref, String id) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                ref
                    .read(conversionHistoryNotifierProvider.notifier)
                    .deleteRecord(id);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecentWidget extends StatelessWidget {
  const _EmptyRecentWidget();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.history_rounded,
              size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'No conversions yet',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your converted files will appear here',
            style: TextStyle(
                fontSize: 12, color: cs.onSurface.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}
