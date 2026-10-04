// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'File Format Converter';
  static const String appSubtitle =
      'Offline-first \u2022 No upload \u2022 Private';
  static const String appVersion = '1.0.0';

  // Freemium
  static const int freeConversionsPerDay = 5;
  static const int maxRewardedAdsPerDay = 3;
  static const int conversionsPerRewardedAd = 5;

  // SharedPreferences keys
  static const String keyConversionCount = 'daily_conversion_count';
  static const String keyConversionDate = 'daily_conversion_date';
  static const String keyRewardedAdCount = 'daily_rewarded_ad_count';
  static const String keyRewardedAdDate = 'daily_rewarded_ad_date';
  static const String keyIsPro = 'is_pro';
  static const String keyOnboardingDone = 'onboarding_done';

  // Hive boxes
  static const String conversionHistoryBox = 'conversion_history';
  static const String settingsBox = 'settings';

  // Conversion types (used in history records)
  static const String pdfToImage = 'PDF \u2192 Image';
  static const String imageToPdf = 'Image \u2192 PDF';
  static const String pdfToDocx = 'PDF \u2192 DOCX';
  static const String docxToPdf = 'DOCX \u2192 PDF';

  // File extensions
  static const List<String> pdfExtensions = ['pdf'];
  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp'
  ];
  static const List<String> docxExtensions = ['docx'];
}
