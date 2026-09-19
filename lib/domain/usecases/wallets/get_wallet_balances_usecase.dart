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

    // Fast O(1) Sets for paused banks and bank:slot accounts
    final wholePausedBanks = <String>{};
    final pausedBankSlots = <String>{};
    for (final b in pausedBanks) {
      if (b.contains(':')) {
        final parts = b.split(':');
        final c = BankSenders.match(parts[0]) ?? parts[0].trim();
        pausedBankSlots.add('${c.toUpperCase()}:${parts[1]}');
      } else {
        final c = BankSenders.match(b) ?? b.trim();
        wholePausedBanks.add(c.toUpperCase());
      }
    }

    // Single O(N) pass across all transactions to aggregate latest balances and cash movements
    final bankSlotBalances = <String, Map<int, double>>{};
    double cashInflows = 0;
    double cashOutflows = 0;
    bool hasUnifiedCash = false;

    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];

      // Cash tracking
      if (tx.bankName.toLowerCase() == 'cash wallet') {
        hasUnifiedCash = true;
        if (tx.isIncome) {
          cashInflows += tx.amount.abs();
        } else {
          cashOutflows += tx.amount.abs();
        }
      } else {
        final reason = (tx.resolvedReason ?? tx.reason ?? tx.customReasonText ?? '')
            .toLowerCase()
            .trim();
        if (reason == 'cash' || reason == 'cash withdrawal' || reason == 'atm') {
          if (tx.type == 'expense') {
            // Bank withdrawal: physical cash IN to wallet (+)
            cashInflows += tx.amount.abs();
          } else if (tx.type == 'income') {
            // Bank deposit: physical cash OUT to bank (-)
            cashOutflows += tx.amount.abs();
          }
        }
      }

      // Bank balances: capture latest totalBalance per bank & simSlot (first occurrence = newest)
      if (tx.totalBalance > 0) {
        final canonicalBank = BankSenders.match(tx.bankName) ?? tx.bankName.trim();
        final bankKey = canonicalBank.toUpperCase();
        final slotMap = bankSlotBalances.putIfAbsent(bankKey, () => <int, double>{});
        slotMap.putIfAbsent(tx.simSlot, () => tx.totalBalance);
      }
    }

    // 1. Bank Accounts: Match latest transaction balance by registered sender
    for (final sender in senders) {
      final canonicalSender = BankSenders.match(sender.senderName) ?? sender.senderName.trim();
      final senderKey = canonicalSender.toUpperCase();

      if (wholePausedBanks.contains(senderKey)) {
        continue;
      }

      final slotMap = bankSlotBalances[senderKey];
      if (slotMap == null || slotMap.isEmpty) continue;

      double bankTotal = 0.0;
      slotMap.forEach((slot, bal) {
        if (!pausedBankSlots.contains('$senderKey:$slot')) {
          bankTotal += bal;
        }
      });

      if (bankTotal > 0) {
        latestBalancesMap[sender.senderName] = bankTotal;
        totalBalance += bankTotal;
      }
    }

    // 2b. Legacy cash transactions (fallback only if unified transactions haven't taken over)
    if (!hasUnifiedCash) {
      for (final ctx in cashTransactions) {
        if (ctx.isIncome) {
          cashInflows += ctx.amount;
        } else if (ctx.isExpense) {
          cashOutflows += ctx.amount;
        }
      }
    }

    final double rawCashBalance = cashInflows - cashOutflows;
    final double cashBalance = rawCashBalance > 0 ? rawCashBalance : 0.0;
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
