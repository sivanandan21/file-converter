import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _scaleCtrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<Offset> _slideUp;
  late AnimationController _slideCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideUp = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic),
    );

    // 3D rotation for the icon
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Glow pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Particle burst
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _scaleCtrl.forward();
    _fadeCtrl.forward();
    _rotateCtrl.repeat();
    _glowCtrl.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 400));
    _slideCtrl.forward();
    _particleCtrl.repeat();

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) _navigate();
  }

  void _navigate() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    final freemiumService = ref.read(freemiumServiceProvider);
    if (freemiumService.isOnboardingDone) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _slideCtrl.dispose();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surface;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 3D Floating App Icon with rotation and glow
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated glow ring
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, __) {
                        return Container(
                          width: 150 + _glowCtrl.value * 30,
                          height: 150 + _glowCtrl.value * 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                    alpha: 0.15 + _glowCtrl.value * 0.15),
                                blurRadius: 30 + _glowCtrl.value * 20,
                                spreadRadius: 5 + _glowCtrl.value * 10,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Floating particles
                    ...List.generate(8, (i) => _FloatingParticle(
                      controller: _particleCtrl,
                      index: i,
                      radius: 70,
                    )),
                    // 3D rotating icon
                    ScaleTransition(
                      scale: _scale,
                      child: AnimatedBuilder(
                        animation: _rotateCtrl,
                        builder: (_, child) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(
                                  math.sin(_rotateCtrl.value * 2 * math.pi) *
                                      0.15)
                              ..rotateX(
                                  math.cos(_rotateCtrl.value * 2 * math.pi) *
                                      0.08),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCardColor
                                : AppColors.cardColor,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: shadowDark.withValues(alpha: 0.6),
                                offset: const Offset(8, 8),
                                blurRadius: 20,
                              ),
                              BoxShadow(
                                color: shadowLight.withValues(alpha: 0.9),
                                offset: const Offset(-8, -8),
                                blurRadius: 20,
                              ),
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                blurRadius: 25,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.swap_horiz_rounded,
                              size: 54,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Title & Subtitle
              SlideTransition(
                position: _slideUp,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.proEnd,
                          AppColors.primary,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        AppConstants.appName,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.appSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface.withValues(alpha: 0.6),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              // Loading dots with 3D bounce
              SlideTransition(
                position: _slideUp,
                child: _LoadingDots3D(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingParticle extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final double radius;

  const _FloatingParticle({
    required this.controller,
    required this.index,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final angle = (index / 8) * 2 * math.pi +
            controller.value * 2 * math.pi;
        final r = radius + math.sin(controller.value * 4 * math.pi + index) * 8;
        final x = math.cos(angle) * r;
        final y = math.sin(angle) * r;
        final opacity = (0.3 + 0.4 * math.sin(controller.value * 2 * math.pi + index))
            .clamp(0.0, 1.0);
        final size = 3.0 + 3.0 * math.sin(controller.value * 3 * math.pi + index);

        return Transform.translate(
          offset: Offset(x, y),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: opacity * 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingDots3D extends StatefulWidget {
  @override
  State<_LoadingDots3D> createState() => _LoadingDots3DState();
}

class _LoadingDots3DState extends State<_LoadingDots3D>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        _controllers[i].forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) {
            final bounce = math.sin(_controllers[i].value * math.pi);
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..translateByDouble(0.0, -bounce * 12, 0.0, 1.0)
                ..scaleByDouble(1.0 + bounce * 0.3, 1.0 + bounce * 0.3, 1.0, 1.0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary
                          .withValues(alpha: 0.4 + 0.6 * _controllers[i].value),
                      AppColors.proEnd
                          .withValues(alpha: 0.3 + 0.5 * _controllers[i].value),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.3 * _controllers[i].value),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
