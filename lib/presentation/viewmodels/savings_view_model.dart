import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../data/repositories/savings_repository.dart';
import '../../models/saving_goal.dart';
import '../../models/goal_feasibility.dart';
import '../../domain/usecases/savings/calculate_goal_feasibility_usecase.dart';

/// SavingsViewModel — owns all saving goal state, priority ranking, and actions.
///
/// Zero DatabaseService calls — all data access goes through SavingsRepository.
class SavingsViewModel extends ChangeNotifier {
  final SavingsRepository _repository;
  final CalculateGoalFeasibilityUseCase _feasibilityUseCase;

  SavingsViewModel({
    required SavingsRepository repository,
    CalculateGoalFeasibilityUseCase feasibilityUseCase =
        const CalculateGoalFeasibilityUseCase(),
  })  : _repository = repository,
        _feasibilityUseCase = feasibilityUseCase;

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
      final loaded = await _repository.getSavingGoals();
      _savingGoals = _sortGoalsByPriority(loaded);
    } catch (e) {
      debugPrint('Error fetching saving goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD & Priority Management ─────────────────────────────────────────────

  Future<void> addSavingGoal(SavingGoal goal) async {
    // If goal priority is already occupied or specified, insert in place and normalize priorities
    final goals = List<SavingGoal>.from(_savingGoals);
    final targetPriority = goal.priority.clamp(1, goals.length + 1);
    
    // Insert at index (targetPriority - 1)
    final insertIdx = (targetPriority - 1).clamp(0, goals.length);
    goals.insert(insertIdx, goal);

    // Normalize priorities 1..N
    final updatedList = <SavingGoal>[];
    for (int i = 0; i < goals.length; i++) {
      updatedList.add(goals[i].copyWith(priority: i + 1));
    }

    _savingGoals = updatedList;
    notifyListeners();

    await _repository.insertSavingGoal(goal.copyWith(priority: targetPriority));
    await _repository.updateGoalsPriority(updatedList);
    await fetchSavingGoals();
  }

  Future<void> updateSavingGoal(SavingGoal goal) async {
    final idx = _savingGoals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      final oldGoal = _savingGoals[idx];
      if (oldGoal.priority != goal.priority) {
        // Priority changed in edit dialog
        final goals = List<SavingGoal>.from(_savingGoals)..removeAt(idx);
        final targetPriority = goal.priority.clamp(1, goals.length + 1);
        final insertIdx = (targetPriority - 1).clamp(0, goals.length);
        goals.insert(insertIdx, goal);

        final updatedList = <SavingGoal>[];
        for (int i = 0; i < goals.length; i++) {
          updatedList.add(goals[i].copyWith(priority: i + 1));
        }
        _savingGoals = updatedList;
        notifyListeners();

        await _repository.updateSavingGoal(goal);
        await _repository.updateGoalsPriority(updatedList);
        await fetchSavingGoals();
        return;
      }
    }

    await _repository.updateSavingGoal(goal);
    await fetchSavingGoals();
  }

  Future<void> reorderGoals(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _savingGoals.length) return;

    final goals = List<SavingGoal>.from(_savingGoals);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= goals.length) newIndex = goals.length - 1;

    final movedGoal = goals.removeAt(oldIndex);
    goals.insert(newIndex, movedGoal);

    // Re-index priorities 1..N
    final updatedList = <SavingGoal>[];
    for (int i = 0; i < goals.length; i++) {
      updatedList.add(goals[i].copyWith(priority: i + 1));
    }

    _savingGoals = updatedList;
    notifyListeners();

    try {
      await _repository.updateGoalsPriority(updatedList);
    } catch (e) {
      debugPrint('Error updating goals priority: $e');
    }
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

  // ── Feasibility Calculation with Priority Waterfall ──────────────────────

  GoalFeasibility goalFeasibility(
    SavingGoal goal, {
    Map<String, double> liveBalances = const {},
    double totalBalance = 0.0,
  }) {
    final waterfall = _feasibilityUseCase.calculateWaterfall(
      goals: _savingGoals.isNotEmpty ? _savingGoals : [goal],
      liveBalances: liveBalances,
      totalBalance: totalBalance,
    );

    return waterfall[goal.id] ??
        GoalFeasibility(
          availableAmount: 0.0,
          remainingAmount: goal.remainingAmount,
          canAffordNow: false,
          conflictWarning: '',
        );
  }

  List<SavingGoal> _sortGoalsByPriority(List<SavingGoal> goals) {
    return List<SavingGoal>.from(goals)
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }
}
