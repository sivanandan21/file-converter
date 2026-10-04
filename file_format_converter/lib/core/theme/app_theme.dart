import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Background
  static const Color background = Color(0xFFEEF0F5);
  static const Color surface = Color(0xFFEEF0F5);
  static const Color cardColor = Color(0xFFEEF0F5);

  // Primary
  static const Color primary = Color(0xFF4B6BFB);
  static const Color primaryLight = Color(0xFF7B93FF);
  static const Color primaryDark = Color(0xFF2E4DE0);

  // Accent colors
  static const Color pdfRed = Color(0xFFFF6B6B);
  static const Color pdfRedLight = Color(0xFFFFE0E0);
  static const Color docxBlue = Color(0xFF5B93FF);
  static const Color docxBlueLight = Color(0xFFDDE9FF);
  static const Color imageGreen = Color(0xFF4CAF7D);
  static const Color imageGreenLight = Color(0xFFDDF2E8);
  static const Color privacyGreen = Color(0xFF4CAF7D);
  static const Color privacyGreenLight = Color(0xFFDDF2E8);

  // Text
  static const Color textPrimary = Color(0xFF1A1E3C);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Neumorphic shadows
  static const Color shadowLight = Color(0xFFFFFFFF);
  static const Color shadowDark = Color(0xFFCACDD8);

  // Status
  static const Color success = Color(0xFF4CAF7D);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Pro gradient
  static const Color proStart = Color(0xFF667EEA);
  static const Color proEnd = Color(0xFF764BA2);

  // Dark mode
  static const Color darkBackground = Color(0xFF1A1D2E);
  static const Color darkSurface = Color(0xFF252840);
  static const Color darkCardColor = Color(0xFF252840);
  static const Color darkShadowLight = Color(0xFF2E3252);
  static const Color darkShadowDark = Color(0xFF0F1020);
  static const Color darkTextPrimary = Color(0xFFEEF0F5);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.textTertiary,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: Perspective3DPageTransitionsBuilder(),
          TargetPlatform.iOS: Perspective3DPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        surface: AppColors.darkSurface,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme:
          GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        titleSmall: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextSecondary,
        ),
        bodySmall: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextSecondary,
        ),
        labelLarge: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: Perspective3DPageTransitionsBuilder(),
          TargetPlatform.iOS: Perspective3DPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// Neumorphic helpers
class NeumorphicDecoration {
  static BoxDecoration card({
    double radius = 20,
    bool isPressed = false,
    Color? color,
  }) {
    final bgColor = color ?? AppColors.cardColor;
    return BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.5),
                offset: const Offset(2, 2),
                blurRadius: 6,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: AppColors.shadowLight.withValues(alpha: 0.8),
                offset: const Offset(-2, -2),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.6),
                offset: const Offset(6, 6),
                blurRadius: 14,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: AppColors.shadowLight.withValues(alpha: 0.9),
                offset: const Offset(-6, -6),
                blurRadius: 14,
                spreadRadius: 0,
              ),
            ],
    );
  }

  static BoxDecoration circle({bool isPressed = false, Color? color}) {
    final bgColor = color ?? AppColors.cardColor;
    return BoxDecoration(
      color: bgColor,
      shape: BoxShape.circle,
      boxShadow: isPressed
          ? [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.5),
                offset: const Offset(2, 2),
                blurRadius: 5,
              ),
              BoxShadow(
                color: AppColors.shadowLight.withValues(alpha: 0.8),
                offset: const Offset(-2, -2),
                blurRadius: 5,
              ),
            ]
          : [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.6),
                offset: const Offset(5, 5),
                blurRadius: 10,
              ),
              BoxShadow(
                color: AppColors.shadowLight.withValues(alpha: 0.9),
                offset: const Offset(-5, -5),
                blurRadius: 10,
              ),
            ],
    );
  }
}

/// Custom 3D perspective page transition.
/// Incoming page slides in from the right with a subtle Y-rotation and scale.
/// Outgoing page scales down and slightly rotates for depth.
class Perspective3DPageTransitionsBuilder extends PageTransitionsBuilder {
  const Perspective3DPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _Perspective3DTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _Perspective3DTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _Perspective3DTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Incoming page: slide from right + slight 3D rotation
    final slideIn = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));

    final scaleIn = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    final rotateIn = Tween<double>(begin: 0.08, end: 0.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    // Outgoing page: scale down slightly
    final scaleOut = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
    );

    final fadeOut = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondaryAnimation]),
      builder: (_, __) {
        // If this page is being pushed on top (secondary animation)
        if (secondaryAnimation.value > 0) {
          return FadeTransition(
            opacity: fadeOut,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..scaleByDouble(scaleOut.value, scaleOut.value, 1.0, 1.0),
              child: child,
            ),
          );
        }

        return SlideTransition(
          position: slideIn,
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(-rotateIn.value)
              ..scaleByDouble(scaleIn.value, scaleIn.value, 1.0, 1.0),
            child: child,
          ),
        );
      },
    );
  }
}
