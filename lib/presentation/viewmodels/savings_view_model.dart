import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/repositories/savings_repository.dart';
import '../../models/saving_goal.dart';
import '../../models/goal_feasibility.dart';
import '../../domain/usecases/savings/calculate_goal_feasibility_usecase.dart';

/// SavingsViewModel — owns all saving goal state and actions.
///
/// Zero DatabaseService calls — all data access goes through SavingsRepository.
class SavingsViewModel extends ChangeNotifier {
  final SavingsRepository _repository;

  SavingsViewModel({required SavingsRepository repository})
      : _repository = repository;

  // ── State ─────────────────────────────────────────────────────────────────

  List<SavingGoal> _savingGoals = [];
  UnmodifiableListView<SavingGoal> get savingGoals =>
      UnmodifiableListView(_savingGoals);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> fetchSavingGoals() async {
    _isLoading = true;
    notifyListeners();
    try {
      _savingGoals = await _repository.getSavingGoals();
    } catch (e) {
      debugPrint('Error fetching saving goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addSavingGoal(SavingGoal goal) async {
    await _repository.insertSavingGoal(goal);
    await fetchSavingGoals();
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    await _repository.updateSavingGoal(goal);
    await fetchSavingGoals();
  }

  Future<void> topUpSavingGoal(String goalId, double amount) async {
    final idx = _savingGoals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final updated = _savingGoals[idx].copyWith(
        savedAmount: _savingGoals[idx].savedAmount + amount,
      );
      await _repository.updateSavingGoal(updated);
      _savingGoals[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteSavingGoal(String goalId) async {
    await _repository.deleteSavingGoal(goalId);
    await fetchSavingGoals();
  }

  // ── Feasibility Calculation ───────────────────────────────────────────────

  GoalFeasibility goalFeasibility(
    SavingGoal goal, {
    Map<String, double> liveBalances = const {},
    double totalBalance = 0.0,
  }) {
    // Conflict detection
    final conflicts = <String, double>{};
    if (goal.allocationMode != AllocationMode.globalPercent) {
      for (final accountName in goal.accountAllocations.keys) {
        double totalPct = goal.accountAllocations[accountName] ?? 0;
        for (final other in _savingGoals) {
          if (other.id == goal.id) continue;
          if (other.status != 'active') continue;
          if (other.allocationMode == AllocationMode.globalPercent) continue;
          final otherPct = other.accountAllocations[accountName];
          if (otherPct != null) totalPct += otherPct;
        }
        conflicts[accountName] = totalPct;
      }
    }

    return const CalculateGoalFeasibilityUseCase().execute(
      goal: goal,
      liveBalances: liveBalances,
      totalBalance: totalBalance,
      allGoalAllocationsForAccount: conflicts,
    );
  }
}
