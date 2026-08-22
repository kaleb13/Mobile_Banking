import '../../models/cash_transaction.dart';
import '../../models/expense_definition.dart';
import '../../services/database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class CashWalletRepository {
  // ── Cash Transactions ──
  Future<List<CashTransaction>> getCashTransactions();
  Future<int> insertCashTransaction(CashTransaction transaction);
  Future<void> updateCashTransaction(CashTransaction transaction);
  Future<void> deleteCashTransaction(int id);

  // ── Expense Definitions ──
  Future<List<ExpenseDefinition>> getExpenseDefinitions();
  Future<int> insertExpenseDefinition(ExpenseDefinition definition);
  Future<void> updateExpenseDefinition(ExpenseDefinition definition);
  Future<void> deleteExpenseDefinition(int id);
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete SQLite Implementation
// ─────────────────────────────────────────────────────────────────────────────

class CashWalletRepositoryImpl implements CashWalletRepository {
  final DatabaseService _db;

  CashWalletRepositoryImpl({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  // ── Cash Transactions ─────────────────────────────────────────────────────

  @override
  Future<List<CashTransaction>> getCashTransactions() =>
      _db.getCashTransactions();

  @override
  Future<int> insertCashTransaction(CashTransaction transaction) =>
      _db.insertCashTransaction(transaction);

  @override
  Future<void> updateCashTransaction(CashTransaction transaction) =>
      _db.updateCashTransaction(transaction);

  @override
  Future<void> deleteCashTransaction(int id) =>
      _db.deleteCashTransaction(id);

  // ── Expense Definitions ───────────────────────────────────────────────────

  @override
  Future<List<ExpenseDefinition>> getExpenseDefinitions() =>
      _db.getExpenseDefinitions();

  @override
  Future<int> insertExpenseDefinition(ExpenseDefinition definition) =>
      _db.insertExpenseDefinition(definition);

  @override
  Future<void> updateExpenseDefinition(ExpenseDefinition definition) =>
      _db.updateExpenseDefinition(definition);

  @override
  Future<void> deleteExpenseDefinition(int id) =>
      _db.deleteExpenseDefinition(id);
}
