import '../../../models/sender.dart';
import '../../../models/transaction.dart';
import '../../../models/cash_transaction.dart';

class WalletBalancesResult {
  final double totalBalance;
  final double cashBalance;
  final Map<String, double> latestBalancesMap;

  const WalletBalancesResult({
    required this.totalBalance,
    required this.cashBalance,
    required this.latestBalancesMap,
  });
}

class GetWalletBalancesUseCase {
  const GetWalletBalancesUseCase();

  /// Calculates exact latest balance for every registered bank and cash wallet,
  /// accounting for paused banks and cash inflows/outflows.
  WalletBalancesResult execute({
    required List<AppSender> senders,
    required List<AppTransaction> transactions,
    required List<CashTransaction> cashTransactions,
    required Set<String> pausedBanks,
  }) {
    final pausedUpper = pausedBanks.map((b) => b.toUpperCase()).toSet();
    final Map<String, double> latestBalancesMap = {};
    double totalBalance = 0.0;

    // 1. Bank Accounts: Match latest transaction balance by bank name (tx.name)
    for (final sender in senders) {
      if (pausedUpper.contains(sender.senderName.toUpperCase())) {
        continue;
      }

      final sNameUp = sender.senderName.trim().toUpperCase();
      final senderTxs = transactions.where((t) {
        final tNameUp = t.name.trim().toUpperCase();
        final tSenderUp = t.sender.trim().toUpperCase();
        if (sNameUp == 'BOA' || sNameUp.contains('ABYSSINIA')) {
          return tNameUp == 'BOA' ||
              tSenderUp == 'BOA' ||
              tNameUp.contains('ABYSSINIA') ||
              tSenderUp.contains('ABYSSINIA');
        }
        return tNameUp == sNameUp || tSenderUp == sNameUp;
      });

      final withBal = senderTxs.where((t) => t.totalBalance > 0);
      final double bal = withBal.isNotEmpty ? withBal.first.totalBalance : 0.0;

      if (bal > 0) {
        latestBalancesMap[sender.senderName] = bal;
        totalBalance += bal;
      }
    }

    // 2. Cash Transactions: calculate net cash balance
    double cashInflows = 0;
    double cashOutflows = 0;
    for (final ctx in cashTransactions) {
      if (ctx.type == 'addition') {
        cashInflows += ctx.amount;
      } else if (ctx.type == 'expense') {
        cashOutflows += ctx.amount;
      }
    }

    final cashBalance = cashInflows - cashOutflows;
    if (cashBalance > 0 && !pausedUpper.contains('CASH WALLET')) {
      latestBalancesMap['Cash Wallet'] = cashBalance;
      totalBalance += cashBalance;
    }

    return WalletBalancesResult(
      totalBalance: totalBalance,
      cashBalance: cashBalance,
      latestBalancesMap: latestBalancesMap,
    );
  }
}
