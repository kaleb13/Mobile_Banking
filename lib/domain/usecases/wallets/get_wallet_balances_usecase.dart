import '../../../models/sender.dart';
import '../../../models/transaction.dart';
import '../../../models/cash_transaction.dart';
import '../../../services/bank_senders.dart';

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
      // Check if whole bank is paused (i.e. 'CBE' without colon)
      if (pausedBanks.any((b) => !b.contains(':') && BankSenders.isSameBank(b, sender.senderName))) {
        continue;
      }

      final senderTxs = transactions.where((t) => BankSenders.isSameBank(t.name, sender.senderName));

      final slots = senderTxs.map((t) => t.simSlot).toSet().toList();
      double bankTotal = 0.0;

      if (slots.length <= 1) {
        final slot = slots.isNotEmpty ? slots.first : 0;
        final isSlotPaused = pausedBanks.any((b) {
          if (!b.contains(':')) return false;
          final parts = b.split(':');
          return BankSenders.isSameBank(parts[0], sender.senderName) && parts[1] == '$slot';
        });
        if (!isSlotPaused) {
          final withBal = senderTxs.where((t) => t.totalBalance > 0);
          bankTotal = withBal.isNotEmpty ? withBal.first.totalBalance : 0.0;
        }
      } else {
        // Multi-account / Dual-SIM bank: sum the latest balance of each separate unpaused account
        for (final slot in slots) {
          final isSlotPaused = pausedBanks.any((b) {
            if (!b.contains(':')) return false;
            final parts = b.split(':');
            return BankSenders.isSameBank(parts[0], sender.senderName) && parts[1] == '$slot';
          });
          if (!isSlotPaused) {
            final slotTxs = senderTxs.where((t) => t.simSlot == slot && t.totalBalance > 0);
            if (slotTxs.isNotEmpty) {
              bankTotal += slotTxs.first.totalBalance;
            }
          }
        }
      }

      if (bankTotal > 0) {
        latestBalancesMap[sender.senderName] = bankTotal;
        totalBalance += bankTotal;
      }
    }

    // 2. Cash Transactions: calculate net cash balance
    double cashInflows = 0;
    double cashOutflows = 0;

    // 2a. Bank transactions categorized as Cash (Withdrawals = Inflows, Deposits = Outflows)
    for (final tx in transactions) {
      final reason = (tx.resolvedReason ?? tx.reason ?? tx.customReasonText ?? '')
          .toLowerCase()
          .trim();
      if (reason == 'cash' || reason == 'cash withdrawal' || reason == 'atm') {
        if (tx.type == 'expense') {
          cashInflows += tx.amount.abs();
        } else if (tx.type == 'income') {
          cashOutflows += tx.amount.abs();
        }
      }
    }

    // 2b. Manual cash additions and deductions
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
