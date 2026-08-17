import '../lib/models/sender.dart';
import '../lib/models/transaction.dart';

void main() {
  print('=== Testing Total Balance Calculation ===\n');

  // Let's create transactions matching the user's setup:
  // Wallets:
  // 1. Telebirr: 576
  // 2. CBE: 382
  // 3. CBE Birr: 0
  // 4. Ahadu Bank: 463
  // 5. BOA: 21818
  // 6. Dashen Bank: 31119
  // 7. Cash: 600

  final senders = [
    AppSender(id: '1', senderName: 'Telebirr'),
    AppSender(id: '2', senderName: 'CBE'),
    AppSender(id: '3', senderName: 'CBE Birr'),
    AppSender(id: '4', senderName: 'Ahadu Bank'),
    AppSender(id: '5', senderName: 'BOA'),
    AppSender(id: '6', senderName: 'Dashen Bank'),
  ];

  final txs = [
    // Telebirr transactions with different counterparty names (tx.sender)
    AppTransaction(name: 'Telebirr', sender: 'Nahom', amount: 100, type: 'income', date: DateTime(2026, 8, 17, 10), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 576.0),
    AppTransaction(name: 'Telebirr', sender: 'Abreham', amount: 50, type: 'expense', date: DateTime(2026, 8, 16), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 476.0),
    
    // CBE transactions
    AppTransaction(name: 'CBE', sender: 'Yonas', amount: 200, type: 'income', date: DateTime(2026, 8, 17, 9), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 382.0),
    AppTransaction(name: 'CBE', sender: 'Salary', amount: 1000, type: 'income', date: DateTime(2026, 8, 1), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 182.0),

    // CBE Birr (0 balance)
    AppTransaction(name: 'CBE Birr', sender: 'Airtime', amount: 50, type: 'expense', date: DateTime(2026, 8, 15), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 0.0),

    // Ahadu Bank
    AppTransaction(name: 'Ahadu Bank', sender: 'Transfer', amount: 100, type: 'income', date: DateTime(2026, 8, 17, 8), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 463.0),

    // BOA
    AppTransaction(name: 'BOA', sender: 'Merchant', amount: 500, type: 'expense', date: DateTime(2026, 8, 17, 7), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 21818.0),

    // Dashen Bank with multiple counterparty names (newest 2026 first)
    AppTransaction(name: 'Dashen Bank', sender: 'ATM / Cash Withdrawal', amount: 5000, type: 'expense', date: DateTime(2026, 8, 13), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 31119.0),
    AppTransaction(name: 'Dashen Bank', sender: 'ABREHAHSILASSIEHIRUY', amount: 8000, type: 'income', date: DateTime(2024, 1, 29), category: 'Auto', rawMessage: '', isAutoDetected: true, totalBalance: 368464.98),
  ];

  // CALCULATION (exact sum of all unpaused wallet cards grouped by tx.name):
  double newTotal = 0;
  Map<String, double> newLatestBalances = {};
  for (var sender in senders) {
    // latest transaction for this bank sender
    final senderTxs = txs.where((t) => t.name.toLowerCase() == sender.senderName.toLowerCase()).toList();
    final withBal = senderTxs.where((t) => t.totalBalance > 0);
    double bal = withBal.isNotEmpty ? withBal.first.totalBalance : 0.0;
    if (bal > 0) {
      newLatestBalances[sender.senderName] = bal;
      newTotal += bal;
    }
  }
  newTotal += 600.0; // Cash
  newLatestBalances['Cash Wallet'] = 600.0;

  print('CALCULATION (exact sum of all unpaused wallet cards):');
  print('Entries: $newLatestBalances');
  print('Total: $newTotal');

  const expectedTotal = 576.0 + 382.0 + 0.0 + 463.0 + 21818.0 + 31119.0 + 600.0;
  print('Expected Sum: $expectedTotal');

  if ((newTotal - expectedTotal).abs() < 0.01) {
    print('\n[SUCCESS] Calculation matches expected wallet sum perfectly! 🎉');
  } else {
    throw Exception('Mismatch: $newTotal vs $expectedTotal');
  }
}
