import '../../models/sender.dart';
import '../../models/cash_transaction.dart';
import '../../models/saving_goal.dart';
import '../../services/database_service.dart';

abstract class WalletRepository {
  Future<List<AppSender>> getSenders();
  Future<int> insertSender(AppSender sender);
  Future<int> updateSender(AppSender sender);
  Future<int> deleteSender(String id);

  Future<List<CashTransaction>> getCashTransactions();
  Future<int> insertCashTransaction(CashTransaction transaction);
  Future<int> updateCashTransaction(CashTransaction transaction);
  Future<int> deleteCashTransaction(int id);

  Future<List<SavingGoal>> getSavingGoals();
}

class WalletRepositoryImpl implements WalletRepository {
  final DatabaseService _dbService;

  WalletRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<AppSender>> getSenders() => _dbService.getSenders();

  @override
  Future<int> insertSender(AppSender sender) => _dbService.insertSender(sender);

  @override
  Future<int> updateSender(AppSender sender) => _dbService.updateSender(sender);

  @override
  Future<int> deleteSender(String id) => _dbService.deleteSender(id);

  @override
  Future<List<CashTransaction>> getCashTransactions() =>
      _dbService.getCashTransactions();

  @override
  Future<int> insertCashTransaction(CashTransaction transaction) =>
      _dbService.insertCashTransaction(transaction);

  @override
  Future<int> updateCashTransaction(CashTransaction transaction) =>
      _dbService.updateCashTransaction(transaction);

  @override
  Future<int> deleteCashTransaction(int id) =>
      _dbService.deleteCashTransaction(id);

  @override
  Future<List<SavingGoal>> getSavingGoals() => _dbService.getSavingGoals();
}
