import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// A neumorphic-styled card with 3D perspective tilt on press.
class NeumorphicCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double borderRadius;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = 20,
  });

  @override
  State<NeumorphicCard> createState() => _NeumorphicCardState();
}

class _NeumorphicCardState extends State<NeumorphicCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  Offset _localPosition = Offset.zero;
  late AnimationController _hoverCtrl;
  late Animation<double> _hoverAnim;

  @override
  void initState() {
    super.initState();
    _hoverCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _hoverAnim = CurvedAnimation(parent: _hoverCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hoverCtrl.dispose();
    super.dispose();
  }

  void _onPanDown(DragDownDetails details) {
    setState(() {
      _isPressed = true;
      _localPosition = details.localPosition;
    });
    _hoverCtrl.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _localPosition = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isPressed = false);
    _hoverCtrl.reverse();
  }

  void _onPanCancel() {
    setState(() => _isPressed = false);
    _hoverCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return GestureDetector(
      onPanDown: _onPanDown,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _hoverAnim,
        builder: (_, child) {
          // 3D perspective tilt based on touch position
          double rotateX = 0;
          double rotateY = 0;

          if (_isPressed && context.size != null) {
            final size = context.size!;
            final centerX = size.width / 2;
            final centerY = size.height / 2;
            // Map touch offset from center to rotation angle (max ±6°)
            rotateY = ((_localPosition.dx - centerX) / centerX) * 0.10 *
                _hoverAnim.value;
            rotateX = -((_localPosition.dy - centerY) / centerY) * 0.10 *
                _hoverAnim.value;
          }

          final scale = 1.0 - _hoverAnim.value * 0.03;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX(rotateX)
              ..rotateY(rotateY)
              ..scaleByDouble(scale, scale, 1.0, 1.0),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: shadowDark.withValues(alpha: 0.5),
                      offset: const Offset(2, 2),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: shadowLight.withValues(alpha: 0.8),
                      offset: const Offset(-2, -2),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: shadowDark.withValues(alpha: 0.6),
                      offset: const Offset(6, 6),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: shadowLight.withValues(alpha: 0.9),
                      offset: const Offset(-6, -6),
                      blurRadius: 14,
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A neumorphic icon button (used in headers).
class NeumorphicIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final double size;

  const NeumorphicIconButton({
    super.key,
    required this.onTap,
    required this.child,
    this.size = 44,
  });

  @override
  State<NeumorphicIconButton> createState() => _NeumorphicIconButtonState();
}

class _NeumorphicIconButtonState extends State<NeumorphicIconButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _pressCtrl.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _pressCtrl.reverse();
      },
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (_, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..scaleByDouble(1.0 - _pressCtrl.value * 0.08, 1.0 - _pressCtrl.value * 0.08, 1.0, 1.0),
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: shadowDark.withValues(alpha: 0.5),
                      offset: const Offset(2, 2),
                      blurRadius: 5,
                    ),
                    BoxShadow(
                      color: shadowLight.withValues(alpha: 0.8),
                      offset: const Offset(-2, -2),
                      blurRadius: 5,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: shadowDark.withValues(alpha: 0.6),
                      offset: const Offset(5, 5),
                      blurRadius: 10,
                    ),
                    BoxShadow(
                      color: shadowLight.withValues(alpha: 0.9),
                      offset: const Offset(-5, -5),
                      blurRadius: 10,
                    ),
                  ],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
