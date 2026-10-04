import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/aws_config.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AwsConfig.initCredentials();
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_admin_logged_in') ?? false;

  runApp(AdminApp(isLoggedIn: isLoggedIn));
}

class AdminApp extends StatelessWidget {
  final bool isLoggedIn;
  const AdminApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AWS File Converter Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4B6BFB),
          secondary: Color(0xFF7C5CFC),
          surface: Color(0xFF111827),
          onSurface: Color(0xFFE2E8F0),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
