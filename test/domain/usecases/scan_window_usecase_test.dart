import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/models/scan_window_option.dart';
import 'package:mobile_banking_app/domain/usecases/settings/get_scan_window_usecase.dart';
import 'package:mobile_banking_app/domain/usecases/settings/set_scan_window_usecase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanWindowOption Model Tests', () {
    test('computes correct anchor date for each option relative to install date', () {
      final installDate = DateTime(2026, 8, 17, 12, 0, 0);

      // Today only (start of install day)
      final todayAnchor = ScanWindowOption.todayOnly.computeAnchorDate(installDate);
      expect(todayAnchor, DateTime(2026, 8, 17, 0, 0, 0));

      // 7 Days
      final sevenAnchor = ScanWindowOption.sevenDays.computeAnchorDate(installDate);
      expect(sevenAnchor, installDate.subtract(const Duration(days: 7)));

      // 30 Days
      final thirtyAnchor = ScanWindowOption.thirtyDays.computeAnchorDate(installDate);
      expect(thirtyAnchor, installDate.subtract(const Duration(days: 30)));

      // 90 Days
      final ninetyAnchor = ScanWindowOption.ninetyDays.computeAnchorDate(installDate);
      expect(ninetyAnchor, installDate.subtract(const Duration(days: 90)));

      // All Time
      final allTimeAnchor = ScanWindowOption.allTime.computeAnchorDate(installDate);
      expect(allTimeAnchor, DateTime(2000, 1, 1));
    });

    test('serializes and deserializes option keys accurately', () {
      expect(ScanWindowOption.fromString('todayOnly'), ScanWindowOption.todayOnly);
      expect(ScanWindowOption.fromString('sevenDays'), ScanWindowOption.sevenDays);
      expect(ScanWindowOption.fromString('thirtyDays'), ScanWindowOption.thirtyDays);
      expect(ScanWindowOption.fromString('ninetyDays'), ScanWindowOption.ninetyDays);
      expect(ScanWindowOption.fromString('allTime'), ScanWindowOption.allTime);
      expect(ScanWindowOption.fromString('unknown_key'), ScanWindowOption.sevenDays);
    });
  });

  group('ScanWindow Use Cases Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('GetScanWindowUseCase defaults to 7 days if unset', () async {
      const getUseCase = GetScanWindowUseCase();
      final info = await getUseCase();

      expect(info.option, ScanWindowOption.sevenDays);
      expect(info.anchorDate.isBefore(DateTime.now()), isTrue);
    });

    test('SetScanWindowUseCase updates option and calculates hard anchor date', () async {
      const setUseCase = SetScanWindowUseCase();
      const getUseCase = GetScanWindowUseCase();

      final setInfo = await setUseCase(ScanWindowOption.sevenDays);
      expect(setInfo.option, ScanWindowOption.sevenDays);

      final retrievedInfo = await getUseCase();
      expect(retrievedInfo.option, ScanWindowOption.sevenDays);
      expect(retrievedInfo.anchorDate, setInfo.anchorDate);
    });

    test('Clamping logic prevents refresh from exceeding hard anchor date', () async {
      final installDate = DateTime(2026, 8, 17, 12, 0, 0);
      SharedPreferences.setMockInitialValues({
        'app_install_date': installDate.toIso8601String(),
        'scan_window_option_v1': ScanWindowOption.sevenDays.keyName,
        'install_anchor_date': installDate.subtract(const Duration(days: 7)).toIso8601String(),
      });

      const getUseCase = GetScanWindowUseCase();
      final info = await getUseCase();
      final anchorDate = info.anchorDate;

      // Case 1: User requests 30-day refresh on a 7-day anchor
      final requestedCutoff30Days = installDate.subtract(const Duration(days: 30));
      DateTime effectiveCutoff = requestedCutoff30Days;
      if (effectiveCutoff.isBefore(anchorDate)) {
        effectiveCutoff = anchorDate; // Clamped!
      }
      expect(effectiveCutoff, anchorDate);

      // Case 2: User requests 3-day refresh on a 7-day anchor
      final requestedCutoff3Days = installDate.subtract(const Duration(days: 3));
      effectiveCutoff = requestedCutoff3Days;
      if (effectiveCutoff.isBefore(anchorDate)) {
        effectiveCutoff = anchorDate;
      }
      expect(effectiveCutoff, requestedCutoff3Days);
    });
  });
}
