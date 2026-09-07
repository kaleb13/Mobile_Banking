import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/domain/usecases/transactions/filter_transactions_usecase.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/services/ahadu_parser.dart';

void main() {
  const exactUserSms = '''Dear KALEB ,
A Deposit of ETB ETB 30,867.00 to your account number XXXXXXXXX0101 on 02-09-2026 . Your current Balance is ETB  31073.9 .
Ahadu Bank.''';

  test('Exact duplicate SMS parsing produces identical deterministic hash and fields', () {
    final fallback = DateTime(2026, 9, 2, 10, 30, 0);
    final tx1 = AhaduParser.parse(exactUserSms, fallback);
    final tx2 = AhaduParser.parse(exactUserSms, fallback);

    expect(tx1, isNotNull);
    expect(tx2, isNotNull);

    expect(tx1!.amount, equals(30867.0));
    expect(tx2!.amount, equals(30867.0));
    expect(tx1.type, equals('income'));
    expect(tx2.type, equals('income'));
    expect(tx1.totalBalance, equals(31073.9));
    expect(tx2.totalBalance, equals(31073.9));

    // Notice: neither has an explicit ref ID in the text, so both use SHA-256 hash of normalized text
    expect(tx1.id, isNotEmpty);
    expect(tx1.id, startsWith('AHADU-'));
    expect(tx1.id, equals(tx2.id), reason: 'Deterministic SHA-256 must yield identical transaction ID');
  });

  test('Domain model creation and SQLite primary key deduplication prevents double counting', () {
    final fallback = DateTime(2026, 9, 2, 10, 30, 0);
    final p1 = AhaduParser.parse(exactUserSms, fallback)!;
    final p2 = AhaduParser.parse(exactUserSms, fallback)!;

    final tx1 = AppTransaction.fromParsedResult(p1, accountIdentifier: '0101');
    final tx2 = AppTransaction.fromParsedResult(p2, accountIdentifier: '0101');

    expect(tx1.id, equals(tx2.id));

    // Simulate SQLite table storage keyed by PRIMARY KEY (id):
    final Map<String, AppTransaction> sqliteTransactionsTable = {};
    for (final tx in [tx1, tx2]) {
      // ON CONFLICT(id) DO UPDATE
      sqliteTransactionsTable[tx.id!] = tx;
    }

    // Exactly 1 record is persisted in SQLite
    expect(sqliteTransactionsTable.length, equals(1));
    final persistedTransactions = sqliteTransactionsTable.values.toList();

    // 1. Transaction Listing View (Filtered transactions)
    final listingResult = const FilterTransactionsUseCase().execute(
      transactions: persistedTransactions,
      params: const FilterTransactionsParams(),
    );
    expect(listingResult.length, equals(1));
    expect(listingResult.first.amount, equals(30867.0));

    // 2. Analysis Screen Calculation
    final totalIncome = listingResult
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    expect(totalIncome, equals(30867.0), reason: 'Analysis page calculates 30,867.00 ETB, NOT 60k');
  });

  test('Ahadu transfer with Fayda update link is not ignored and parses all fields correctly', () {
    const sept2TransferSms = '''Dear KALEB,
You have made a transfer of ETB 20,000.00. Including Service charge and VAT (15%) from account number 008XXXXXX0101 to Telebirr of 972665987 with reference number w2b17883520939961797 on 02-SEP-26. 
Your Available Balance is ETB 10,475.90. 
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/02-SEP-26/ 5466
For Fayda ID Update
https://verifayda.ahadubank.com/
Ahadu Bank!''';

    final fallback = DateTime(2026, 9, 2, 15, 23, 44);
    final tx = AhaduParser.parse(sept2TransferSms, fallback);

    expect(tx, isNotNull);
    expect(tx!.amount, equals(20000.0));
    expect(tx.type, equals('expense'));
    expect(tx.counterparty, equals('972665987'));
    expect(tx.totalBalance, equals(10475.90));
    expect(tx.id, equals('w2b17883520939961797'));
    expect(tx.date.year, equals(2026));
    expect(tx.date.month, equals(9));
    expect(tx.date.day, equals(2));
  });
}

