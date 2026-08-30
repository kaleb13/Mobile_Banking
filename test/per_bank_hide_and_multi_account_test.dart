import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/models/app_currency.dart';
import 'package:mobile_banking_app/models/scan_window_option.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';

class FakeSettingsRepo implements SettingsRepository {
  bool isBalanceVisible = true;
  Set<String> hiddenBanks = {};

  @override
  Future<bool> getIsBalanceVisible() async => isBalanceVisible;
  @override
  Future<void> setIsBalanceVisible(bool value) async => isBalanceVisible = value;
  @override
  Future<Set<String>> getHiddenBalanceBanks() async => hiddenBanks;
  @override
  Future<void> setHiddenBalanceBanks(Set<String> banks) async {
    hiddenBanks = banks;
  }
  @override
  Future<AppThemeMode> getThemeMode() async => AppThemeMode.dark;
  @override
  Future<void> setThemeMode(AppThemeMode mode) async {}
  @override
  Future<AppCurrency> getCurrency() async => const AppCurrency(
        code: 'birr',
        symbol: 'Br',
        shortLabel: 'Birr',
        name: 'Ethiopian Birr',
      );
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
  Future<bool> getIsOnboardingComplete() async => true;
  @override
  Future<void> setOnboardingComplete(bool complete) async {}
  @override
  Future<ScanWindowOption> getScanWindow() async => ScanWindowOption.thirtyDays;
  @override
  Future<void> setScanWindow(ScanWindowOption option) async {}
}

class FakeTxRepo implements TransactionRepository {
  List<AppSender> senders = [];
  List<AppTransaction> transactions = [];
  List<AppReason> reasons = [];
  List<AppReasonLink> reasonLinks = [];
  Set<String> pausedBanks = {};

  @override
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) async => transactions;
  @override
  Future<List<AppSender>> getSenders() async => senders;
  @override
  Future<List<AppReason>> getReasons() async => reasons;
  @override
  Future<List<AppReasonLink>> getReasonLinks() async => reasonLinks;
  @override
  Future<Set<String>> getPausedBanks() async => pausedBanks;
  @override
  Future<void> setPausedBanks(Set<String> paused) async {
    pausedBanks = paused;
  }
  @override
  Future<int> deleteUncategorizedTransactionsForBank(String bankName) async => 0;
  @override
  Future<int> deleteUncategorizedNotificationsForBank(String bankName) async => 0;
  List<TransactionSplit> splits = [];

  @override
  Future<List<TransactionSplit>> getAllTransactionSplits() async => splits;

  @override
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId) async =>
      splits.where((s) => s.transactionId == transactionId).toList();

  @override
  Future<void> saveTransactionSplits(String transactionId, List<TransactionSplit> newSplits) async {
    splits.removeWhere((s) => s.transactionId == transactionId);
    splits.addAll(newSplits);
  }

  @override
  Future<int> deleteTransactionSplits(String transactionId) async {
    final count = splits.where((s) => s.transactionId == transactionId).length;
    splits.removeWhere((s) => s.transactionId == transactionId);
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Per-Bank Balance Visibility Tests', () {
    test('Can toggle and persist hide balance for an individual bank', () async {
      final settingsRepo = FakeSettingsRepo();
      final settingsVM = SettingsViewModel(repository: settingsRepo);
      await settingsVM.init();

      expect(settingsVM.isBankBalanceHidden('Telebirr'), isFalse);
      expect(settingsVM.isBankBalanceHidden('CBE'), isFalse);

      // Hide Telebirr balance
      await settingsVM.toggleBankBalanceVisibility('Telebirr');
      expect(settingsVM.isBankBalanceHidden('Telebirr'), isTrue);
      expect(settingsVM.isBankBalanceHidden('CBE'), isFalse);
      expect(settingsRepo.hiddenBanks.contains('Telebirr'), isTrue);

      // Re-initialize SettingsViewModel from repository
      final newSettingsVM = SettingsViewModel(repository: settingsRepo);
      await newSettingsVM.init();
      expect(newSettingsVM.isBankBalanceHidden('Telebirr'), isTrue);
      expect(newSettingsVM.isBankBalanceHidden('CBE'), isFalse);

      // Show Telebirr balance again
      await newSettingsVM.toggleBankBalanceVisibility('Telebirr');
      expect(newSettingsVM.isBankBalanceHidden('Telebirr'), isFalse);
      expect(settingsRepo.hiddenBanks.contains('Telebirr'), isFalse);
    });
  });

  group('Multi-Account Per-Account Pausing Tests', () {
    test('Independent pause and resume tracking for accounts of a multi-account bank', () async {
      final txRepo = FakeTxRepo();
      txRepo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
      ];

      // Add 2 accounts for CBE: Account 1 (simSlot 0) and Account 2 (simSlot 1)
      txRepo.transactions = [
        AppTransaction(
          id: 'cbe_tx_1',
          name: 'CBE',
          amount: 500.0,
          type: 'income',
          date: DateTime.now(),
          sender: 'Sender A',
          category: 'Salary',
          totalBalance: 5000.0,
          simSlot: 0,
          rawMessage: 'msg 1',
          isAutoDetected: true,
        ),
        AppTransaction(
          id: 'cbe_tx_2',
          name: 'CBE',
          amount: 300.0,
          type: 'income',
          date: DateTime.now(),
          sender: 'Sender B',
          category: 'Freelance',
          totalBalance: 3000.0,
          simSlot: 1,
          rawMessage: 'msg 2',
          isAutoDetected: true,
        ),
      ];

      final txVM = TransactionsViewModel(repository: txRepo);
      await txVM.loadAll();

      final accounts = txVM.accountsForBank('CBE');
      expect(accounts.length, 2);
      expect(accounts, [0, 1]);

      // Both accounts active initially
      expect(txVM.isAccountPaused('CBE', 0), isFalse);
      expect(txVM.isAccountPaused('CBE', 1), isFalse);
      expect(txVM.isTrackingPaused('CBE'), isFalse);
      // Combined balance: 5000 + 3000 = 8000
      expect(txVM.balanceForSender('CBE'), 8000.0);

      // Pause Account 1 (slot 0)
      await txVM.pauseAccountTracking('CBE', 0);
      expect(txVM.isAccountPaused('CBE', 0), isTrue);
      expect(txVM.isAccountPaused('CBE', 1), isFalse);
      expect(txVM.isTrackingPaused('CBE'), isFalse); // Bank is still active because Account 2 is active!
      // Balance reflects only Account 2 (3000.0)
      expect(txVM.balanceForSender('CBE'), 3000.0);

      // Active accounts count is 1 (the 2 Accounts badge is removed)
      final activeAccounts = accounts.where((slot) => !txVM.isAccountPaused('CBE', slot)).toList();
      expect(activeAccounts.length, 1);

      // Pause Account 2 (slot 1) as well
      await txVM.pauseAccountTracking('CBE', 1);
      expect(txVM.isAccountPaused('CBE', 0), isTrue);
      expect(txVM.isAccountPaused('CBE', 1), isTrue);
      // Now all accounts are paused -> the whole bank is considered paused
      expect(txVM.isTrackingPaused('CBE'), isTrue);
      expect(txVM.balanceForSender('CBE'), 0.0);

      // Active accounts count is 0
      final activeAccountsAfterBothPaused = accounts.where((slot) => !txVM.isAccountPaused('CBE', slot)).toList();
      expect(activeAccountsAfterBothPaused.length, 0);

      // Resume Account 1
      await txVM.resumeAccountTracking('CBE', 0);
      expect(txVM.isAccountPaused('CBE', 0), isFalse);
      expect(txVM.isAccountPaused('CBE', 1), isTrue);
      expect(txVM.isTrackingPaused('CBE'), isFalse); // Active again!
      expect(txVM.balanceForSender('CBE'), 5000.0);

      // Resume whole bank
      await txVM.resumeTracking('CBE');
      expect(txVM.isAccountPaused('CBE', 0), isFalse);
      expect(txVM.isAccountPaused('CBE', 1), isFalse);
      expect(txVM.isTrackingPaused('CBE'), isFalse);
      expect(txVM.balanceForSender('CBE'), 8000.0);
    });
  });
}
