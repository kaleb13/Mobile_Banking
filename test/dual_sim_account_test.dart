import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';
import 'package:mobile_banking_app/services/sms_service.dart';
import 'package:mobile_banking_app/services/sms_batch_parser.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';

class MockTransactionRepository implements TransactionRepository {
  List<AppTransaction> storedTxs = [];
  Set<String> pausedBanks = {};

  @override
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) async => storedTxs;

  @override
  Future<Set<String>> getPausedBanks() async => pausedBanks;

  @override
  Future<void> setPausedBanks(Set<String> banks) async {
    pausedBanks = banks;
  }

  @override
  Future<List<AppSender>> getSenders() async => [
        AppSender(senderName: 'Telebirr'),
        AppSender(senderName: 'CBE'),
      ];

  @override
  Future<List<AppReason>> getReasons() async => [];

  @override
  Future<List<AppReasonLink>> getReasonLinks() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Dual-SIM & Multi-Account per Bank Tests', () {
    late MockTransactionRepository repo;
    late TransactionsViewModel txVM;

    setUp(() {
      repo = MockTransactionRepository();
      txVM = TransactionsViewModel(repository: repo);
    });

    test('Parses raw SMS with distinct simSlot into AppTransaction', () {
      final raw1 = RawSmsData(
        sender: '127',
        body: 'you have received ETB 500.00 from Abebe on 12/04/2026 10:00:00. your current balance is ETB 5,000.00. transaction number is FT11111.',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        simSlot: 0,
      );

      final raw2 = RawSmsData(
        sender: '127',
        body: 'you have received ETB 200.00 from Chala on 12/04/2026 11:00:00. your current balance is ETB 2,000.00. transaction number is FT22222.',
        date: DateTime.now().subtract(const Duration(hours: 1)),
        simSlot: 1,
      );

      final result = SmsBatchParser.parseSync(
        BatchParseParams(
          rawMessages: [raw1, raw2],
          pausedBanks: [],
          customSenders: [],
          autoReasonRules: [],
          initialBankBalances: {},
        ),
      );

      expect(result.transactions.length, 2);
      expect(result.transactions[0].simSlot, 0);
      expect(result.transactions[0].totalBalance, 5000.0);
      expect(result.transactions[1].simSlot, 1);
      expect(result.transactions[1].totalBalance, 2000.0);
    });

    test('Tracks independent balances for SIM 1 & SIM 2 without flipping', () async {
      final tx1 = AppTransaction(
        id: 'tx_sim1',
        name: 'Telebirr',
        amount: 500.0,
        type: 'income',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        sender: '127',
        category: 'Auto',
        rawMessage: 'msg1',
        isAutoDetected: true,
        totalBalance: 5000.0,
        simSlot: 0,
      );

      final tx2 = AppTransaction(
        id: 'tx_sim2',
        name: 'Telebirr',
        amount: 200.0,
        type: 'income',
        date: DateTime.now().subtract(const Duration(hours: 1)),
        sender: '127',
        category: 'Auto',
        rawMessage: 'msg2',
        isAutoDetected: true,
        totalBalance: 2000.0,
        simSlot: 1,
      );

      repo.storedTxs = [tx2, tx1]; // Newest first
      await txVM.loadAll();

      // Verify accounts discovered
      final accounts = txVM.accountsForBank('Telebirr');
      expect(accounts, [0, 1]);

      // Verify individual balances
      expect(txVM.balanceForAccount('Telebirr', 0), 5000.0);
      expect(txVM.balanceForAccount('Telebirr', 1), 2000.0);

      // Verify combined balance sums both SIM accounts
      expect(txVM.balanceForSender('Telebirr'), 7000.0);
    });

    test('Granular account pausing pauses only targeted SIM slot', () async {
      final tx1 = AppTransaction(
        id: 'tx_sim1',
        name: 'Telebirr',
        amount: 500.0,
        type: 'income',
        date: DateTime.now().subtract(const Duration(hours: 2)),
        sender: '127',
        category: 'Auto',
        rawMessage: 'msg1',
        isAutoDetected: true,
        totalBalance: 5000.0,
        simSlot: 0,
      );

      final tx2 = AppTransaction(
        id: 'tx_sim2',
        name: 'Telebirr',
        amount: 200.0,
        type: 'income',
        date: DateTime.now().subtract(const Duration(hours: 1)),
        sender: '127',
        category: 'Auto',
        rawMessage: 'msg2',
        isAutoDetected: true,
        totalBalance: 2000.0,
        simSlot: 1,
      );

      repo.storedTxs = [tx2, tx1];
      await txVM.loadAll();

      expect(txVM.isAccountPaused('Telebirr', 1), isFalse);
      expect(txVM.balanceForSender('Telebirr'), 7000.0);

      // Pause SIM 2
      await txVM.pauseAccountTracking('Telebirr', 1);

      expect(txVM.isAccountPaused('Telebirr', 1), isTrue);
      expect(txVM.isAccountPaused('Telebirr', 0), isFalse);

      // Combined balance now only reflects SIM 1
      expect(txVM.balanceForSender('Telebirr'), 5000.0);

      // Filtered transactions list only contains SIM 1
      expect(txVM.transactions.length, 1);
      expect(txVM.transactions.first.id, 'tx_sim1');

      // Resume SIM 2
      await txVM.resumeAccountTracking('Telebirr', 1);
      expect(txVM.balanceForSender('Telebirr'), 7000.0);
      expect(txVM.transactions.length, 2);
    });

    test('Auto-links dual-SIM transfers with matching transaction reference & amount as locked Internal Transfer', () {
      final rawOutflow = RawSmsData(
        sender: '127',
        body: 'you have transferred ETB 300.00 to 251972665987 on 12/04/2026 10:00:00. your current balance is ETB 4,700.00. transaction number is CC99887766.',
        date: DateTime.now().subtract(const Duration(minutes: 5)),
        simSlot: 0,
      );

      final rawInflow = RawSmsData(
        sender: '127',
        body: 'you have received ETB 300.00 from 251911223344 on 12/04/2026 10:00:00. your current balance is ETB 2,300.00. transaction number is CC99887766.',
        date: DateTime.now().subtract(const Duration(minutes: 5)),
        simSlot: 1,
      );

      final result = SmsBatchParser.parseSync(
        BatchParseParams(
          rawMessages: [rawOutflow, rawInflow],
          pausedBanks: [],
          customSenders: [],
          autoReasonRules: [
            AutoReasonRule(id: 42, name: 'Internal Transfer', sender: ''),
          ],
          initialBankBalances: {},
        ),
      );

      expect(result.transactions.length, 2);
      final txOut = result.transactions.firstWhere((t) => t.type == 'expense');
      final txIn = result.transactions.firstWhere((t) => t.type == 'income');

      expect(txOut.reason, 'Internal Transfer');
      expect(txOut.reasonId, 42);
      expect(txOut.linkedTransactionId, txIn.id);
      expect(txOut.isReasonLocked, isTrue);

      expect(txIn.reason, 'Internal Transfer');
      expect(txIn.reasonId, 42);
      expect(txIn.linkedTransactionId, txOut.id);
      expect(txIn.isReasonLocked, isTrue);
    });
  });
}
