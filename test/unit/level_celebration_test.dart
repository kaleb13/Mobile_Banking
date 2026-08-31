import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/presentation/viewmodels/analytics_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';
import 'package:mobile_banking_app/models/app_currency.dart';
import 'package:mobile_banking_app/models/scan_window_option.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';

class MockSettingsRepository implements SettingsRepository {
  int _lastCelebratedLevel = 1;
  bool _isOnboardingComplete = true;
  bool _isBalanceVisible = true;

  @override
  Future<int> getLastCelebratedLevel() async => _lastCelebratedLevel;

  @override
  Future<void> setLastCelebratedLevel(int level) async {
    _lastCelebratedLevel = level;
  }

  @override
  Future<bool> getIsOnboardingComplete() async => _isOnboardingComplete;
  @override
  Future<void> setOnboardingComplete(bool complete) async {
    _isOnboardingComplete = complete;
  }

  @override
  Future<bool> getIsBalanceVisible() async => _isBalanceVisible;
  @override
  Future<void> setIsBalanceVisible(bool value) async {
    _isBalanceVisible = value;
  }

  @override
  Future<AppThemeMode> getThemeMode() async => AppThemeMode.dark;
  @override
  Future<void> setThemeMode(AppThemeMode mode) async {}

  @override
  Future<AppCurrency> getCurrency() async => AppCurrency.defaultCurrency;
  @override
  Future<void> setCurrency(String code) async {}

  @override
  Future<bool> getSmsListeningEnabled() async => true;
  @override
  Future<void> setSmsListeningEnabled(bool value) async {}

  @override
  Future<bool> getPushNotificationsEnabled() async => false;
  @override
  Future<void> setPushNotificationsEnabled(bool value) async {}

  @override
  Future<bool> getReportDailyEnabled() async => false;
  @override
  Future<void> setReportDailyEnabled(bool value) async {}

  @override
  Future<bool> getReportWeeklyEnabled() async => false;
  @override
  Future<void> setReportWeeklyEnabled(bool value) async {}

  @override
  Future<bool> getReportMonthlyEnabled() async => false;
  @override
  Future<void> setReportMonthlyEnabled(bool value) async {}

  @override
  Future<String> getNotifQuickButton1() async => '';
  @override
  Future<void> setNotifQuickButton1(String value) async {}

  @override
  Future<String> getNotifQuickButton2() async => '';
  @override
  Future<void> setNotifQuickButton2(String value) async {}

  @override
  Future<DateTime?> getCustomMonthAnchorDate() async => null;
  @override
  Future<void> setCustomMonthAnchorDate(DateTime? date) async {}

  @override
  Future<String?> getUserName() async => null;
  @override
  Future<void> setUserName(String name) async {}

  @override
  Future<ScanWindowOption> getScanWindow() async => ScanWindowOption.thirtyDays;
  @override
  Future<void> setScanWindow(ScanWindowOption option) async {}

  @override
  Future<DateTime?> getScanWindowStartDate() async => null;
  @override
  Future<void> setScanWindowStartDate(DateTime? date) async {}

  @override
  Future<DateTime?> getEffectiveScanWindowAnchorDate() async => null;

  @override
  Future<Set<String>> getHiddenBalanceBanks() async => {};
  @override
  Future<void> setHiddenBalanceBanks(Set<String> banks) async {}
}

AppTransaction _createTx(String bank, double totalBalance) {
  return AppTransaction(
    id: 'TX_${DateTime.now().millisecondsSinceEpoch}',
    name: bank,
    sender: bank,
    amount: 100.0,
    type: 'income',
    date: DateTime.now(),
    category: 'General',
    rawMessage: 'Sample SMS',
    isAutoDetected: true,
    totalBalance: totalBalance,
  );
}

void main() {
  group('Level Progression & Celebration System Tests', () {
    late AnalyticsViewModel analyticsVM;
    late SettingsViewModel settingsVM;
    late MockSettingsRepository mockSettingsRepo;

    setUp(() async {
      mockSettingsRepo = MockSettingsRepository();
      settingsVM = SettingsViewModel(
        repository: mockSettingsRepo,
        initialOnboardingComplete: true,
      );
      await settingsVM.init();

      analyticsVM = AnalyticsViewModel();
      analyticsVM.getSenders = () => [
            AppSender(senderName: 'Telebirr'),
          ];
    });

    test('Initial user level starts at Level 1 (Survivor) for zero/low balance', () {
      expect(analyticsVM.userLevel, 1);
      expect(analyticsVM.userLevelName, 'Survivor');
      expect(analyticsVM.nextLevelName, 'Builder');
    });

    test('Level calculation thresholds match expected financial tiers', () {
      // Level 1: 0 - 100,000 ETB
      analyticsVM.getTransactions = () => [_createTx('Telebirr', 50000)];
      analyticsVM.recalculate();
      expect(analyticsVM.userLevel, 1);
      expect(analyticsVM.userLevelName, 'Survivor');

      // Level 2: 100,001 - 500,000 ETB
      analyticsVM.getTransactions = () => [_createTx('Telebirr', 150000)];
      analyticsVM.recalculate();
      expect(analyticsVM.userLevel, 2);
      expect(analyticsVM.userLevelName, 'Builder');
      expect(analyticsVM.nextLevelName, 'Flourishing');

      // Level 3: 500,001 - 1,000,000 ETB
      analyticsVM.getTransactions = () => [_createTx('Telebirr', 750000)];
      analyticsVM.recalculate();
      expect(analyticsVM.userLevel, 3);
      expect(analyticsVM.userLevelName, 'Flourishing');
      expect(analyticsVM.nextLevelName, 'Prospering');

      // Level 4: 1,000,001 - 5,000,000 ETB
      analyticsVM.getTransactions = () => [_createTx('Telebirr', 2500000)];
      analyticsVM.recalculate();
      expect(analyticsVM.userLevel, 4);
      expect(analyticsVM.userLevelName, 'Prospering');
      expect(analyticsVM.nextLevelName, 'Elite');

      // Level 5: > 5,000,000 ETB
      analyticsVM.getTransactions = () => [_createTx('Telebirr', 8000000)];
      analyticsVM.recalculate();
      expect(analyticsVM.userLevel, 5);
      expect(analyticsVM.userLevelName, 'Elite');
      expect(analyticsVM.nextLevelName, isNull);
    });

    test('SettingsViewModel tracks and updates lastCelebratedLevel', () async {
      expect(settingsVM.lastCelebratedLevel, 1);

      await settingsVM.setLastCelebratedLevel(2);
      expect(settingsVM.lastCelebratedLevel, 2);
      expect(await mockSettingsRepo.getLastCelebratedLevel(), 2);
    });

    test('Level transition triggers celebration flag when advancing', () async {
      expect(settingsVM.lastCelebratedLevel, 1);

      // Advance balance to Level 2
      analyticsVM.getTransactions = () => [_createTx('Telebirr', 200000)];
      analyticsVM.recalculate();

      final currentLevel = analyticsVM.userLevel;
      final shouldCelebrate = currentLevel > settingsVM.lastCelebratedLevel;

      expect(shouldCelebrate, isTrue);

      // Celebrate and record
      await settingsVM.setLastCelebratedLevel(currentLevel);
      expect(settingsVM.lastCelebratedLevel, 2);

      // Subsequent check without level change should not re-trigger
      final shouldCelebrateAgain = analyticsVM.userLevel > settingsVM.lastCelebratedLevel;
      expect(shouldCelebrateAgain, isFalse);
    });

    test('Down-leveling does not trigger celebration', () async {
      // Set recorded level to 3
      await settingsVM.setLastCelebratedLevel(3);

      // Balance dips to Level 2
      analyticsVM.getTransactions = () => [_createTx('Telebirr', 200000)];
      analyticsVM.recalculate();

      expect(analyticsVM.userLevel, 2);
      expect(analyticsVM.userLevel > settingsVM.lastCelebratedLevel, isFalse);
    });
  });
}
