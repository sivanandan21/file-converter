import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/buttons.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      emoji: '\u26A1',
      title: 'Convert Files Instantly',
      subtitle:
          'Transform PDF, Word, and Image files in seconds \u2014 all done on your phone, no waiting.',
      accentColor: AppColors.primary,
    ),
    _OnboardingPage(
      emoji: '\u{1F512}',
      title: 'Your Files Stay on Your Device',
      subtitle:
          'We never upload your files to any server. Everything is processed locally for complete privacy.',
      accentColor: AppColors.privacyGreen,
    ),
    _OnboardingPage(
      emoji: '\u{1F381}',
      title: '5 Free Conversions Daily',
      subtitle:
          'Get 5 free conversions every day. Watch a short ad for more, or upgrade to Pro for unlimited access.',
      accentColor: AppColors.docxBlue,
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(freemiumServiceProvider).completeOnboarding();
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: _finish,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageView(page: _pages[index]);
                },
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? _pages[i].accentColor
                        : shadowDark.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  PrimaryButton(
                    label: _currentPage < _pages.length - 1
                        ? 'Continue'
                        : 'Get Started',
                    onPressed: _next,
                    icon: _currentPage < _pages.length - 1
                        ? null
                        : const Icon(Icons.rocket_launch_rounded,
                            color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: page.accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: page.accentColor.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 72),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
