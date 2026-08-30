import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/repositories/cash_wallet_repository.dart';
import '../../models/cash_transaction.dart';
import '../../models/expense_definition.dart';
import '../../models/transaction.dart';

/// CashWalletViewModel — owns all cash wallet and expense definition state.
///
/// Zero DatabaseService calls — all data access goes through CashWalletRepository.
class CashWalletViewModel extends ChangeNotifier {
  final CashWalletRepository _repository;

  CashWalletViewModel({required CashWalletRepository repository})
      : _repository = repository;

  /// Callback supplied by TransactionsViewModel to access bank transactions.
  List<AppTransaction> Function()? getTransactions;

  // ── State ─────────────────────────────────────────────────────────────────

  List<CashTransaction> _cashTransactions = [];
  UnmodifiableListView<CashTransaction> get cashTransactions =>
      UnmodifiableListView(_cashTransactions);

  List<ExpenseDefinition> _expenseDefinitions = [];
  UnmodifiableListView<ExpenseDefinition> get expenseDefinitions =>
      UnmodifiableListView(_expenseDefinitions);

  double _cashBalance = 0.0;
  double get cashBalance => _cashBalance;
  double get balance => _cashBalance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> loadCashData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getCashTransactions(),
        _repository.getExpenseDefinitions(),
      ]);
      _cashTransactions = results[0] as List<CashTransaction>;
      _expenseDefinitions = results[1] as List<ExpenseDefinition>;
      _recalcBalance();
    } catch (e) {
      debugPrint('Error loading cash data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _recalcBalance() {
    double balance = 0;

    // 1. Bank transactions categorized as Cash (Cash Withdrawal / Cash Deposit)
    if (getTransactions != null) {
      final bankTxs = getTransactions!();
      for (final tx in bankTxs) {
        final reason = (tx.resolvedReason ?? tx.reason ?? tx.customReasonText ?? '')
            .toLowerCase()
            .trim();
        if (reason == 'cash' || reason == 'cash withdrawal' || reason == 'atm') {
          if (tx.type == 'expense') {
            // Bank withdrawal: physical cash IN to wallet (+)
            balance += tx.amount.abs();
          } else if (tx.type == 'income') {
            // Bank deposit: physical cash OUT to bank (-)
            balance -= tx.amount.abs();
          }
        }
      }
    }

    // 2. Manual cash additions and deductions
    for (final tx in _cashTransactions) {
      if (tx.type == 'addition') {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }
    _cashBalance = balance < 0.0 ? 0.0 : balance;
  }

  /// Recalculates balance and notifies listeners when bank transactions change.
  void recalcBalance() {
    _recalcBalance();
    notifyListeners();
  }

  // ── Cash Transactions ─────────────────────────────────────────────────────

  Future<void> addCashTransaction(CashTransaction transaction) async {
    if (transaction.type == 'expense') {
      if ((transaction.reasonName == null ||
              transaction.reasonName!.trim().isEmpty) &&
          transaction.reasonId == null) {
        throw ArgumentError(
            'Cash expense deductions must have an assigned reason.');
      }

      if (transaction.linkedTransactionId != null) {
        // Linked to specific bank withdrawal
        if (getTransactions != null) {
          final bankTxs = getTransactions!();
          final withdrawal = bankTxs.cast<AppTransaction?>().firstWhere(
                (t) => t?.id == transaction.linkedTransactionId,
                orElse: () => null,
              );
          if (withdrawal != null) {
            final rem = getCashWithdrawalRemainingAmount(
                withdrawal.id!, withdrawal.amount);
            if (transaction.amount > rem) {
              throw ArgumentError(
                  'Expense amount (${transaction.amount}) exceeds remaining withdrawal balance ($rem).');
            }
          }
        }
      } else if (_cashBalance <= 0 || transaction.amount > _cashBalance) {
        throw ArgumentError(
            'Expense amount (${transaction.amount}) cannot exceed available cash balance ($_cashBalance).');
      }
    }

    // Optimistically insert into memory and notify listeners instantly
    _cashTransactions.insert(0, transaction);
    _recalcBalance();
    notifyListeners();

    // Persist to database asynchronously and patch the real id back
    final id = await _repository.insertCashTransaction(transaction);
    final idx = _cashTransactions.indexOf(transaction);
    if (idx != -1) {
      _cashTransactions[idx] = CashTransaction(
        id: id,
        type: transaction.type,
        amount: transaction.amount,
        date: transaction.date,
        description: transaction.description,
        expenseDefinitionId: transaction.expenseDefinitionId,
        reasonId: transaction.reasonId,
        reasonName: transaction.reasonName,
        linkedTransactionId: transaction.linkedTransactionId,
      );
    }

    // Update the last applied date if it's an expense linked to a definition
    if (transaction.type == 'expense' &&
        transaction.expenseDefinitionId != null) {
      final defIdx = _expenseDefinitions
          .indexWhere((d) => d.id == transaction.expenseDefinitionId);
      if (defIdx != -1) {
        final def = _expenseDefinitions[defIdx];
        if (def.isRecurring) {
          final updatedDef = def.copyWith(lastAppliedDate: transaction.date);
          await updateExpenseDefinition(updatedDef);
        }
      }
    }
  }

  Future<void> deleteCashTransaction(int id) async {
    _cashTransactions.removeWhere((t) => t.id == id);
    _recalcBalance();
    notifyListeners();
    await _repository.deleteCashTransaction(id);
  }

  Future<void> updateCashTransactionAmount(int id, double newAmount) async {
    final idx = _cashTransactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final oldTx = _cashTransactions[idx];
      final newTx = oldTx.copyWith(amount: newAmount);
      _cashTransactions[idx] = newTx;
      _recalcBalance();
      notifyListeners();
      await _repository.updateCashTransaction(newTx);
    }
  }

  /// Returns spendings linked to a specific bank transaction.
  List<CashTransaction> spendingsForTransaction(String transactionId) {
    return _cashTransactions
        .where((ct) =>
            ct.type == 'expense' && ct.linkedTransactionId == transactionId)
        .toList();
  }

  /// Total cash spent out of a specific bank cash withdrawal.
  double getCashWithdrawalSpentAmount(String transactionId) {
    return spendingsForTransaction(transactionId)
        .fold(0.0, (sum, ctx) => sum + ctx.amount);
  }

  /// Remaining unspent cash for a specific bank cash withdrawal.
  double getCashWithdrawalRemainingAmount(
      String transactionId, double originalAmount) {
    final spent = getCashWithdrawalSpentAmount(transactionId);
    return (originalAmount - spent).clamp(0.0, double.infinity);
  }

  // ── Expense Definitions ───────────────────────────────────────────────────

  Future<void> addExpenseDefinition(ExpenseDefinition definition) async {
    final id = await _repository.insertExpenseDefinition(definition);
    _expenseDefinitions.add(definition.copyWith(id: id));
    _expenseDefinitions.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  Future<void> updateExpenseDefinition(ExpenseDefinition definition) async {
    await _repository.updateExpenseDefinition(definition);
    final idx = _expenseDefinitions.indexWhere((d) => d.id == definition.id);
    if (idx != -1) {
      _expenseDefinitions[idx] = definition;
      _expenseDefinitions.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    }
  }

  Future<void> deleteExpenseDefinition(int id) async {
    await _repository.deleteExpenseDefinition(id);
    _expenseDefinitions.removeWhere((d) => d.id == id);
    notifyListeners();
  }
}
