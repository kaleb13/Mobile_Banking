import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/sms_batch_parser.dart';
import 'package:mobile_banking_app/services/sms_service.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:mobile_banking_app/domain/usecases/transactions/filter_transactions_usecase.dart';
import 'package:mobile_banking_app/widgets/app_date_filter.dart';

void main() {
  group('SMS Processing & Ingestion Real Benchmarks', () {
    // Generate realistic multi-bank SMS templates (CBE, BOA, Ahadu, CBE Birr)
    List<RawSmsData> generateSyntheticSmsDataset(int count) {
      final rand = Random(42);
      final now = DateTime.now();
      final List<RawSmsData> dataset = [];

      final templates = [
        // CBE credit
        (
          sender: 'CBE',
          bodyGen: (int i, double amt) =>
              'Dear Kaleb, your Account 1*********2757 has been Credited with ETB ${amt.toStringAsFixed(2)} from Kaleab Afesha, on 24/04/2026 at 13:44:16 with Ref No FT26114Y$i Your Current Balance is ETB 556.87. Thank you for Banking with CBE!',
        ),
        // Telebirr transfer
        (
          sender: 'Telebirr',
          bodyGen: (int i, double amt) =>
              'You have transferred ETB ${amt.toStringAsFixed(2)} to User_$i on 24/04/2026 14:00:00. Your current balance is ETB 850.00. transaction number is TXN$i.',
        ),
        // CBE Birr credit
        (
          sender: 'CBEBirr',
          bodyGen: (int i, double amt) =>
              'Your CBE Birr account has been credited with ${amt.toStringAsFixed(2)}Br. from Sender on 24/04/26 15:00, txn id CB$i. Account Balance is 1500.00Br.',
        ),
        // BOA credit
        (
          sender: 'BOA',
          bodyGen: (int i, double amt) =>
              'Dear Yohannes, your account 2*****36 was credited with ETB ${amt.toStringAsFixed(2)} by Yohannes Bizuneh . Available Balance: ETB 31,824.04.\nReceipt: https://cs.bankofabyssinia.com/slip/?trx=FT26215HWFDW$i\nFeedback: https://cs.bankofabyssinia.com/cs/?trx=CFT26215HWFDW',
        ),
        // Ahadu credit
        (
          sender: 'Ahadu Bank',
          bodyGen: (int i, double amt) =>
              'Dear Customer, your account 1001*** has been Credited with ETB ${amt.toStringAsFixed(2)} on 20/04/2026. Current Balance ETB 5,000.00. Ref: AH$i.',
        ),
      ];

      for (int i = 0; i < count; i++) {
        final t = templates[i % templates.length];
        final amt = ((rand.nextInt(1000) + 10) * 10).toDouble();
        dataset.add(RawSmsData(
          sender: t.sender,
          body: t.bodyGen(i, amt),
          date: now.subtract(Duration(minutes: i * 5)),
        ));
      }
      return dataset;
    }

    test('Benchmark: 1,000 SMS Isolate Parsing & Extraction', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final dataset = generateSyntheticSmsDataset(1000);
      print('DEBUG: First SMS sender=${dataset.first.sender}, body=${dataset.first.body}');
      final singleTx = CbeParser.parse(dataset.first.body, dataset.first.date);
      print('DEBUG: Single CbeParser.parse result = $singleTx');
      final matchedBank = BankSenders.match(dataset.first.sender);
      print('DEBUG: BankSenders.match result = $matchedBank');

      final stopwatch = Stopwatch()..start();

      final result = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: dataset,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      ));

      stopwatch.stop();
      print('DEBUG: parsed result count = ${result.transactions.length}, unrecognized = ${result.unrecognizedNotifications.length}');
      expect(result.transactions.isNotEmpty, true);
      expect(result.transactions.length, 1000);

      print('----------------------------------------------------');
      print('📊 BENCHMARK (1,000 SMS):');
      print('   Time: ${stopwatch.elapsedMilliseconds} ms');
      print('   Throughput: ${(1000 / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(0)} SMS/sec');
      print('   Parsed Transactions: ${result.transactions.length}');
      print('----------------------------------------------------');
    });

    test('Benchmark: 5,000 SMS Isolate Parsing & Extraction', () async {
      final dataset = generateSyntheticSmsDataset(5000);
      final stopwatch = Stopwatch()..start();

      final result = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: dataset,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      ));

      stopwatch.stop();
      expect(result.transactions.length, 5000);

      print('----------------------------------------------------');
      print('📊 BENCHMARK (5,000 SMS):');
      print('   Time: ${stopwatch.elapsedMilliseconds} ms');
      print('   Throughput: ${(5000 / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(0)} SMS/sec');
      print('   Parsed Transactions: ${result.transactions.length}');
      print('----------------------------------------------------');
    });

    test('Benchmark: 10,000 SMS Isolate Parsing & Extraction', () async {
      final dataset = generateSyntheticSmsDataset(10000);
      final stopwatch = Stopwatch()..start();

      final result = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: dataset,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      ));

      stopwatch.stop();
      expect(result.transactions.length, 10000);

      print('----------------------------------------------------');
      print('📊 BENCHMARK (10,000 SMS):');
      print('   Time: ${stopwatch.elapsedMilliseconds} ms');
      print('   Throughput: ${(10000 / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(0)} SMS/sec');
      print('   Parsed Transactions: ${result.transactions.length}');
      print('----------------------------------------------------');
    });

    test('Benchmark: 25,000 SMS Isolate Parsing & Extraction', () async {
      final dataset = generateSyntheticSmsDataset(25000);
      final stopwatch = Stopwatch()..start();

      final result = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: dataset,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      ));

      stopwatch.stop();
      expect(result.transactions.length, 25000);

      print('----------------------------------------------------');
      print('📊 BENCHMARK (25,000 SMS):');
      print('   Time: ${stopwatch.elapsedMilliseconds} ms');
      print('   Throughput: ${(25000 / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(0)} SMS/sec');
      print('   Parsed Transactions: ${result.transactions.length}');
      print('----------------------------------------------------');
    });

    test('Benchmark: 50,000 SMS Isolate Parsing & Extraction', () async {
      final dataset = generateSyntheticSmsDataset(50000);
      final stopwatch = Stopwatch()..start();

      final result = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: dataset,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      ));

      stopwatch.stop();
      expect(result.transactions.length, 50000);

      print('----------------------------------------------------');
      print('📊 BENCHMARK (50,000 SMS):');
      print('   Time: ${stopwatch.elapsedMilliseconds} ms');
      print('   Throughput: ${(50000 / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(0)} SMS/sec');
      print('   Parsed Transactions: ${result.transactions.length}');
      print('----------------------------------------------------');
    });

    test('Benchmark: Deduplication Idempotency on 10,000 SMS Scan', () async {
      final dataset = generateSyntheticSmsDataset(5000);
      final duplicatedDataset = [...dataset, ...dataset];

      final stopwatch = Stopwatch()..start();
      final result = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: duplicatedDataset,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      ));
      stopwatch.stop();

      expect(result.transactions.length, 5000);
      print('----------------------------------------------------');
      print('📊 BENCHMARK Deduplication (10,000 Raw -> 5,000 Unique):');
      print('   Time: ${stopwatch.elapsedMilliseconds} ms');
      print('   Exact Unique Count: ${result.transactions.length} (Duplicates eliminated)');
      print('----------------------------------------------------');
    });

    test('Benchmark: FilterTransactionsUseCase Execution on 50,000 Items', () async {
      final dataset = generateSyntheticSmsDataset(50000);
      final parseResult = await SmsBatchParser.parseInIsolate(BatchParseParams(
        rawMessages: dataset,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      ));

      const useCase = FilterTransactionsUseCase();
      final stopwatch = Stopwatch()..start();

      final filtered30Days = useCase.execute(
        transactions: parseResult.transactions,
        params: const FilterTransactionsParams(
          dateFilter: AppDateFilterValue.last30Days(),
          sortBy: 'Date: Newest',
        ),
      );
      stopwatch.stop();

      print('----------------------------------------------------');
      print('📊 BENCHMARK UI Domain Filter on 50,000 Transactions:');
      print('   Time to filter & sort: ${stopwatch.elapsedMilliseconds} ms');
      print('   Results in 30-day window: ${filtered30Days.length}');
      print('----------------------------------------------------');
    });
  });
}
