import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BottomNavBar extends ConsumerWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(activeNavIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkCardColor : AppColors.background;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: shadowDark.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: shadowLight.withValues(alpha: 0.8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem3D(
                icon: Icons.home_rounded,
                label: 'Home',
                index: 0,
                active: activeIndex == 0,
                onTap: () =>
                    ref.read(activeNavIndexProvider.notifier).state = 0,
              ),
              _NavItem3D(
                icon: Icons.access_time_rounded,
                label: 'Recent',
                index: 1,
                active: activeIndex == 1,
                onTap: () =>
                    ref.read(activeNavIndexProvider.notifier).state = 1,
              ),
              _NavItem3D(
                icon: Icons.transform_rounded,
                label: 'Convert',
                index: 2,
                active: activeIndex == 2,
                onTap: () =>
                    ref.read(activeNavIndexProvider.notifier).state = 2,
                isCenter: true,
              ),
              _NavItem3D(
                icon: Icons.folder_rounded,
                label: 'Files',
                index: 3,
                active: activeIndex == 3,
                onTap: () =>
                    ref.read(activeNavIndexProvider.notifier).state = 3,
              ),
              _NavItem3D(
                icon: Icons.settings_rounded,
                label: 'Settings',
                index: 4,
                active: activeIndex == 4,
                onTap: () =>
                    ref.read(activeNavIndexProvider.notifier).state = 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nav item with 3D press animation and glow effect.
class _NavItem3D extends StatefulWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool active;
  final VoidCallback onTap;
  final bool isCenter;

  const _NavItem3D({
    required this.icon,
    required this.label,
    required this.index,
    required this.active,
    required this.onTap,
    this.isCenter = false,
  });

  @override
  State<_NavItem3D> createState() => _NavItem3DState();
}

class _NavItem3DState extends State<_NavItem3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapCtrl;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => _tapCtrl.forward(),
      onTapUp: (_) {
        _tapCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapCtrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _tapCtrl,
        builder: (_, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..scaleByDouble(1.0 - _tapCtrl.value * 0.1, 1.0 - _tapCtrl.value * 0.1, 1.0, 1.0)
              ..translateByDouble(0.0, -_tapCtrl.value * 2, 0.0, 1.0),
            child: child,
          );
        },
        child: SizedBox(
          width: 65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: widget.active ? 48 : 44,
                height: widget.active ? 38 : 36,
                decoration: BoxDecoration(
                  gradient: widget.active
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.proEnd.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  color: widget.active ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: widget.active
                      ? [
                          BoxShadow(
                            color:
                                AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.active ? 24 : 22,
                  color: widget.active
                      ? AppColors.primary
                      : cs.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: widget.active ? 10.5 : 10,
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w400,
                  color: widget.active
                      ? AppColors.primary
                      : cs.onSurface.withValues(alpha: 0.4),
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
