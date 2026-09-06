import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/loan_record.dart';
import 'package:mobile_banking_app/models/transaction.dart';

/// Standalone test for the scoring logic used by SelectTransactionSheet.
double calculateProximityScore({
  required AppTransaction tx,
  required double targetAmount,
  required DateTime targetDate,
  required double principalAmount,
}) {
  final amountDiff = (tx.amount - targetAmount).abs();
  final relAmount = targetAmount > 0 ? (amountDiff / targetAmount) : amountDiff;

  final isExactRemaining = amountDiff < 0.01;
  final isExactPrincipal = (tx.amount - principalAmount).abs() < 0.01;

  final exactBonus = isExactRemaining
      ? -200.0
      : (isExactPrincipal ? -100.0 : 0.0);

  final dayDiff = (tx.date.difference(targetDate).inSeconds / 86400.0).abs();
  final isBeforeLoan = tx.date.isBefore(targetDate);
  final beforePenalty = isBeforeLoan ? 2.5 : 0.0;

  return exactBonus + (relAmount * 3.5) + (dayDiff / 15.0) + beforePenalty;
}

void main() {
  group('SelectTransactionSheet - Scoring and Filtering Logic', () {
    final loan = LoanRecord(
      id: 1,
      loanType: 'borrowed',
      personName: 'Daniel',
      principalAmount: 1000.0,
      paidAmount: 200.0, // remaining is 800.0
      loanDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 30),
    );

    test('exact match with closer date ranks higher than exact match with distant date', () {
      final txCloseExact = AppTransaction(
        id: 'tx_close_exact',
        sender: 'Daniel',
        name: 'Telebirr',
        amount: 800.0, // exact remaining
        type: 'expense',
        category: 'Transfer',
        date: DateTime(2026, 9, 3), // 2 days after loan
        rawMessage: 'test',
        isAutoDetected: false,
      );

      final txFarExact = AppTransaction(
        id: 'tx_far_exact',
        sender: 'Daniel',
        name: 'Telebirr',
        amount: 800.0, // exact remaining
        type: 'expense',
        category: 'Transfer',
        date: DateTime(2026, 9, 25), // 24 days after loan
        rawMessage: 'test',
        isAutoDetected: false,
      );

      final scoreClose = calculateProximityScore(
        tx: txCloseExact,
        targetAmount: loan.remainingAmount,
        targetDate: loan.loanDate,
        principalAmount: loan.principalAmount,
      );

      final scoreFar = calculateProximityScore(
        tx: txFarExact,
        targetAmount: loan.remainingAmount,
        targetDate: loan.loanDate,
        principalAmount: loan.principalAmount,
      );

      expect(scoreClose < scoreFar, isTrue,
          reason: 'Exact match closer to loan date must have lower (better) score');
    });

    test('exact match ranks higher than non-exact even if non-exact is on the exact loan day', () {
      final txExact = AppTransaction(
        id: 'tx_exact',
        sender: 'Daniel',
        name: 'Telebirr',
        amount: 800.0,
        type: 'expense',
        category: 'Transfer',
        date: DateTime(2026, 9, 5),
        rawMessage: 'test',
        isAutoDetected: false,
      );

      final txNonExactSameDay = AppTransaction(
        id: 'tx_non_exact',
        sender: 'Daniel',
        name: 'Telebirr',
        amount: 400.0, // 50% of remaining
        type: 'expense',
        category: 'Transfer',
        date: DateTime(2026, 9, 1), // exact loan day
        rawMessage: 'test',
        isAutoDetected: false,
      );

      final scoreExact = calculateProximityScore(
        tx: txExact,
        targetAmount: loan.remainingAmount,
        targetDate: loan.loanDate,
        principalAmount: loan.principalAmount,
      );

      final scoreNonExact = calculateProximityScore(
        tx: txNonExactSameDay,
        targetAmount: loan.remainingAmount,
        targetDate: loan.loanDate,
        principalAmount: loan.principalAmount,
      );

      expect(scoreExact < scoreNonExact, isTrue,
          reason: 'Exact amount match receives high priority over non-exact amounts');
    });

    test('closer amount and closer date ranks higher than distant amount and date', () {
      final txCloseAmtDate = AppTransaction(
        id: 'tx_close_both',
        sender: 'Daniel',
        name: 'Telebirr',
        amount: 780.0, // very close to 800
        type: 'expense',
        category: 'Transfer',
        date: DateTime(2026, 9, 3), // very close to Sept 1
        rawMessage: 'test',
        isAutoDetected: false,
      );

      final txFarAmtDate = AppTransaction(
        id: 'tx_far_both',
        sender: 'Store',
        name: 'CBE',
        amount: 50.0, // far from 800
        type: 'expense',
        category: 'Shopping',
        date: DateTime(2026, 11, 20), // far from Sept 1
        rawMessage: 'test',
        isAutoDetected: false,
      );

      final list = [txFarAmtDate, txCloseAmtDate];
      list.sort((a, b) {
        final sa = calculateProximityScore(
          tx: a,
          targetAmount: loan.remainingAmount,
          targetDate: loan.loanDate,
          principalAmount: loan.principalAmount,
        );
        final sb = calculateProximityScore(
          tx: b,
          targetAmount: loan.remainingAmount,
          targetDate: loan.loanDate,
          principalAmount: loan.principalAmount,
        );
        return sa.compareTo(sb);
      });

      expect(list.first.id, 'tx_close_both');
    });
  });
}
