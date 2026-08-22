import '../../models/saving_goal.dart';
import '../../services/database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Abstract Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SavingsRepository {
  Future<List<SavingGoal>> getSavingGoals();
  Future<void> insertSavingGoal(SavingGoal goal);
  Future<void> updateSavingGoal(SavingGoal goal);
  Future<void> deleteSavingGoal(String goalId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete SQLite Implementation
// ─────────────────────────────────────────────────────────────────────────────

class SavingsRepositoryImpl implements SavingsRepository {
  final DatabaseService _db;

  SavingsRepositoryImpl({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  @override
  Future<List<SavingGoal>> getSavingGoals() => _db.getSavingGoals();

  @override
  Future<void> insertSavingGoal(SavingGoal goal) =>
      _db.insertSavingGoal(goal);

  @override
  Future<void> updateSavingGoal(SavingGoal goal) =>
      _db.updateSavingGoal(goal);

  @override
  Future<void> deleteSavingGoal(String goalId) =>
      _db.deleteSavingGoal(goalId);
}
