import 'package:file_format_converter/core/constants/app_constants.dart';
import 'package:file_format_converter/services/freemium_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FreemiumService> createService() async {
    return FreemiumService(await SharedPreferences.getInstance());
  }

  group('FreemiumService account quota', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('keeps used free conversions for the same account after logout/login',
        () async {
      final service = await createService();
      await service.bindAccount('user-a');

      for (var i = 0; i < AppConstants.freeConversionsPerDay; i++) {
        expect(service.canConvert, isTrue);
        await service.recordConversion();
      }

      expect(service.canConvert, isFalse);
      await service.bindAccount(null);
      await service.bindAccount('user-a');

      expect(service.canConvert, isFalse);
      expect(service.conversionsRemainingToday, 0);
    });

    test('keeps separate free quotas for separate accounts', () async {
      final service = await createService();
      await service.bindAccount('user-a');

      for (var i = 0; i < AppConstants.freeConversionsPerDay; i++) {
        await service.recordConversion();
      }

      await service.bindAccount('user-b');

      expect(service.canConvert, isTrue);
      expect(
        service.conversionsRemainingToday,
        AppConstants.freeConversionsPerDay,
      );
    });

    test('migrates old global quota only to the first signed-in account',
        () async {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      SharedPreferences.setMockInitialValues({
        AppConstants.keyConversionDate: today,
        AppConstants.keyConversionCount: AppConstants.freeConversionsPerDay,
      });

      final service = await createService();
      await service.bindAccount('user-a');
      expect(service.canConvert, isFalse);

      await service.bindAccount('user-b');
      expect(service.canConvert, isTrue);
      expect(
        service.conversionsRemainingToday,
        AppConstants.freeConversionsPerDay,
      );
    });

    test('uses remote quota when it is higher than local quota', () async {
      final service = await createService();
      await service.bindAccount('user-a');
      service.applyRemoteQuota(
        conversionsUsedToday: AppConstants.freeConversionsPerDay,
        rewardedAdsWatchedToday: 0,
      );

      expect(service.canConvert, isFalse);
      expect(service.conversionsUsedToday, AppConstants.freeConversionsPerDay);
    });
  });
}
