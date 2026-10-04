import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'models/conversion_record.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/supabase_config.dart';
import 'providers/app_providers.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status bar style — let the system handle brightness based on theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ConversionRecordAdapter());
  await Hive.openBox<ConversionRecord>(AppConstants.conversionHistoryBox);

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Initialize Google Mobile Ads
  await MobileAds.instance.initialize();

  // Analytics session is now started inside App's initState for real-time updates

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const App(),
    ),
  );
}
