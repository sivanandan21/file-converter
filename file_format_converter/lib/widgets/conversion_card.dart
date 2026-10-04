import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'neumorphic_card.dart';

enum ConversionType { pdfToImage, imageToPdf, pdfToDocx, docxToPdf }

class ConversionCardData {
  final ConversionType type;
  final String title;
  final String subtitle;
  final Widget fromIcon;
  final Widget toIcon;

  const ConversionCardData({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.fromIcon,
    required this.toIcon,
  });
}

/// Conversion card with 3D flip entrance animation.
class ConversionCard extends StatefulWidget {
  final ConversionCardData data;
  final VoidCallback onTap;

  const ConversionCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  State<ConversionCard> createState() => _ConversionCardState();
}

class _ConversionCardState extends State<ConversionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flipAnim = Tween<double>(begin: math.pi / 2, end: 0).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeOutBack),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.elasticOut),
    );

    // Stagger entrance based on card type index
    final delay = widget.data.type.index * 120;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _flipCtrl.forward();
    });
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _flipCtrl,
      builder: (_, __) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(_flipAnim.value)
            ..scaleByDouble(_scaleAnim.value, _scaleAnim.value, 1.0, 1.0),
          child: NeumorphicCard(
            padding: const EdgeInsets.all(16),
            onTap: widget.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon row with arrow pulse
                _AnimatedIconRow(
                  fromIcon: widget.data.fromIcon,
                  toIcon: widget.data.toIcon,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.data.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.data.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated arrow that pulses between the from/to icons.
class _AnimatedIconRow extends StatefulWidget {
  final Widget fromIcon;
  final Widget toIcon;

  const _AnimatedIconRow({
    required this.fromIcon,
    required this.toIcon,
  });

  @override
  State<_AnimatedIconRow> createState() => _AnimatedIconRowState();
}

class _AnimatedIconRowState extends State<_AnimatedIconRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _arrowCtrl;

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        widget.fromIcon,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedBuilder(
            animation: _arrowCtrl,
            builder: (_, child) {
              return Transform.translate(
                offset: Offset(_arrowCtrl.value * 4 - 2, 0),
                child: Opacity(
                  opacity: 0.5 + _arrowCtrl.value * 0.5,
                  child: child,
                ),
              );
            },
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        widget.toIcon,
      ],
    );
  }
}

// ── File type icon widgets ────────────────────────────────────────────────────

class PdfIcon extends StatelessWidget {
  final double size;
  const PdfIcon({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.pdfRedLight,
            AppColors.pdfRedLight.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.pdfRed.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'PDF',
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w800,
            color: AppColors.pdfRed,
          ),
        ),
      ),
    );
  }
}

class DocxIcon extends StatelessWidget {
  final double size;
  const DocxIcon({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.docxBlueLight,
            AppColors.docxBlueLight.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.docxBlue.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'W',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w900,
            color: AppColors.docxBlue,
          ),
        ),
      ),
    );
  }
}

class FileImageIcon extends StatelessWidget {
  final double size;
  const FileImageIcon({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.imageGreenLight,
            AppColors.imageGreenLight.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.imageGreen.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.image_rounded,
        size: size * 0.55,
        color: AppColors.imageGreen,
      ),
    );
  }
}
