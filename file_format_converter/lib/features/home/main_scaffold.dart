import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/conversion_card.dart';
import '../home/home_screen.dart';
import '../recent/recent_screen.dart';
import '../files/files_screen.dart';
import '../settings/settings_screen.dart';
import '../convert/convert_screen.dart';

/// Main scaffold that hosts the bottom navigation.
class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(activeNavIndexProvider);

    final screens = [
      const HomeScreen(),
      const RecentScreen(),
      const _ConvertPickerScreen(),
      const FilesScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: activeIndex,
        children: screens,
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

/// A screen shown when the "Convert" tab is active that lets the user pick
/// a conversion type before proceeding to the conversion flow.
class _ConvertPickerScreen extends StatelessWidget {
  const _ConvertPickerScreen();

  static const _options = [
    (
      ConversionType.pdfToImage,
      AppConstants.pdfToImage,
      'Convert PDF pages to PNG images',
    ),
    (
      ConversionType.imageToPdf,
      AppConstants.imageToPdf,
      'Combine images into a PDF',
    ),
    (
      ConversionType.pdfToDocx,
      AppConstants.pdfToDocx,
      'Convert PDF to Word document',
    ),
    (
      ConversionType.docxToPdf,
      AppConstants.docxToPdf,
      'Convert Word document to PDF',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Convert'),
        automaticallyImplyLeading: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final (type, title, subtitle) = _options[i];
          return _ConversionOption(
            type: type,
            title: title,
            subtitle: subtitle,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ConvertScreen(conversionType: type, title: title),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversionOption extends StatefulWidget {
  final ConversionType type;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ConversionOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_ConversionOption> createState() => _ConversionOptionState();
}

class _ConversionOptionState extends State<_ConversionOption> {
  bool _pressed = false;

  Color get _accentColor {
    switch (widget.type) {
      case ConversionType.pdfToImage:
      case ConversionType.pdfToDocx:
        return AppColors.pdfRed;
      case ConversionType.imageToPdf:
        return AppColors.imageGreen;
      case ConversionType.docxToPdf:
        return AppColors.docxBlue;
    }
  }

  Color get _accentBg {
    switch (widget.type) {
      case ConversionType.pdfToImage:
      case ConversionType.pdfToDocx:
        return AppColors.pdfRedLight;
      case ConversionType.imageToPdf:
        return AppColors.imageGreenLight;
      case ConversionType.docxToPdf:
        return AppColors.docxBlueLight;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ConversionType.pdfToImage:
        return Icons.picture_as_pdf_rounded;
      case ConversionType.imageToPdf:
        return Icons.image_rounded;
      case ConversionType.pdfToDocx:
        return Icons.picture_as_pdf_rounded;
      case ConversionType.docxToPdf:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? AppColors.darkCardColor : AppColors.cardColor;
    final shadowDark = isDark ? AppColors.darkShadowDark : AppColors.shadowDark;
    final shadowLight =
        isDark ? AppColors.darkShadowLight : AppColors.shadowLight;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _pressed
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
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _accentBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_icon, color: _accentColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
