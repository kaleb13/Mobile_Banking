import '../../models/transaction.dart';
import '../../models/app_notification.dart';
import '../../models/reason.dart';
import '../../services/database_service.dart';

abstract class TransactionRepository {
  Future<List<AppTransaction>> getTransactions();
  Future<int> insertTransaction(AppTransaction transaction);
  Future<int> updateTransaction(AppTransaction transaction);
  Future<int> deleteTransaction(String id);
  Future<void> deleteAllTransactions();

  Future<List<AppNotification>> getNotifications();
  Future<void> insertNotification(AppNotification notification);
  Future<void> deleteAllNotifications();

  Future<List<AppReasonLink>> getReasonLinks();
}

class TransactionRepositoryImpl implements TransactionRepository {
  final DatabaseService _dbService;

  TransactionRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<List<AppTransaction>> getTransactions() => _dbService.getTransactions();

  @override
  Future<int> insertTransaction(AppTransaction transaction) =>
      _dbService.insertTransaction(transaction);

  @override
  Future<int> updateTransaction(AppTransaction transaction) =>
      _dbService.updateTransaction(transaction);

  @override
  Future<int> deleteTransaction(String id) => _dbService.deleteTransaction(id);

  @override
  Future<void> deleteAllTransactions() => _dbService.deleteAllTransactions();

  @override
  Future<List<AppNotification>> getNotifications() => _dbService.getNotifications();

  @override
  Future<void> insertNotification(AppNotification notification) =>
      _dbService.insertNotification(notification);

  @override
  Future<void> deleteAllNotifications() => _dbService.deleteAllNotifications();

  @override
  Future<List<AppReasonLink>> getReasonLinks() => _dbService.getReasonLinks();
}
