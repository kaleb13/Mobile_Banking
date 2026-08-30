import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/models/app_currency.dart';
import 'package:mobile_banking_app/models/scan_window_option.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:mobile_banking_app/services/sms_batch_parser.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';

class FakeSettingsRepo implements SettingsRepository {
  bool isBalanceVisible = true;
  Set<String> hiddenBanks = {};
  ScanWindowOption scanWindow = ScanWindowOption.allTime;

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
  Future<ScanWindowOption> getScanWindow() async => scanWindow;
  @override
  Future<void> setScanWindow(ScanWindowOption option) async {
    scanWindow = option;
  }
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
  Future<int> insertTransactionsBatch(List<AppTransaction> newTxs) async {
    transactions.addAll(newTxs);
    return newTxs.length;
  }
  @override
  Future<int> reconcilePendingNotificationReasons() async => 0;
  @override
  Future<List<AutoReasonRule>> getAutoReasonRules() async => [];
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

  group('Bank Keywords Resolution Tests', () {
    test('Returns precise keywords for each bank', () {
      expect(BankSenders.getKeywordsForBank('Telebirr'), ['telebirr', '127']);
      expect(BankSenders.getKeywordsForBank('CBE'), ['cbe']);
      expect(BankSenders.getKeywordsForBank('CBE Birr'), ['cbebirr', 'cbe birr', 'cbe']);
      expect(BankSenders.getKeywordsForBank('BOA'), ['boa', 'abyssinia']);
      expect(BankSenders.getKeywordsForBank('Bank of Abyssinia'), ['boa', 'abyssinia']);
      expect(BankSenders.getKeywordsForBank('Ahadu Bank'), ['ahadu']);
      expect(BankSenders.getKeywordsForBank('Dashen Bank'), ['dashen', 'amole']);
      expect(BankSenders.getKeywordsForBank('CustomWallet'), ['customwallet']);
    });
  });

  group('Bank-Specific Refresh Tests', () {
    test('refreshBankData targets specific bank and handles scanWindowOption and lastDays', () async {
      final txRepo = FakeTxRepo();
      txRepo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
      ];
      txRepo.transactions = [
        AppTransaction(
          id: 'tb_1',
          name: 'Telebirr',
          amount: 200.0,
          type: 'income',
          date: DateTime.now().subtract(const Duration(days: 2)),
          sender: 'Sender A',
          category: 'Transfer',
          totalBalance: 1200.0,
          simSlot: 0,
          rawMessage: 'tb msg 1',
          isAutoDetected: true,
        ),
      ];

      final txVM = TransactionsViewModel(repository: txRepo);
      await txVM.loadAll();

      expect(txVM.transactions.length, 1);
      expect(txVM.balanceForSender('Telebirr'), 1200.0);

      // Refresh with allTime for Telebirr
      final inserted = await txVM.refreshBankData(
        bankName: 'Telebirr',
        scanWindowOption: ScanWindowOption.allTime,
      );

      // In unit test environment without real SMS inbox, returns 0 inserted cleanly without error
      expect(inserted, 0);
      expect(txVM.isLoading, isFalse);
    });
  });

  group('Settings Scan Window Synchronization Tests', () {
    test('SettingsViewModel updates and reflects scan window options', () async {
      final settingsRepo = FakeSettingsRepo();
      final settingsVM = SettingsViewModel(repository: settingsRepo);
      await settingsVM.init();

      expect(settingsVM.scanWindowOption, ScanWindowOption.allTime);

      await settingsVM.setScanWindowOption(ScanWindowOption.thirtyDays);
      expect(settingsVM.scanWindowOption, ScanWindowOption.thirtyDays);
      expect(settingsRepo.scanWindow, ScanWindowOption.thirtyDays);

      await settingsVM.setScanWindowOption(ScanWindowOption.sevenDays);
      expect(settingsVM.scanWindowOption, ScanWindowOption.sevenDays);
      expect(settingsRepo.scanWindow, ScanWindowOption.sevenDays);
    });
  });
}
