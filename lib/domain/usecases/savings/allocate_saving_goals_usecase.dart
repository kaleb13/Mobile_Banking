import '../../../models/saving_goal.dart';

class AllocateSavingGoalsUseCase {
  const AllocateSavingGoalsUseCase();

  /// Calculates total allocation percentages grouped per bank/account across all goals
  /// to detect over-allocation conflicts (> 100%).
  Map<String, double> calculateAccountAllocationTotals(List<SavingGoal> goals) {
    final Map<String, double> accountTotals = {};

    for (final goal in goals) {
      if (goal.status != 'active') continue;

      goal.accountAllocations.forEach((account, pct) {
        final key = account.toUpperCase();
        accountTotals[key] = (accountTotals[key] ?? 0.0) + pct;
      });
    }

    return accountTotals;
  }

  /// Calculates total saved amount across all goals
  double calculateTotalSaved(List<SavingGoal> goals) {
    return goals.fold(0.0, (sum, g) => sum + g.savedAmount);
  }

  /// Calculates total target amount across all goals
  double calculateTotalTarget(List<SavingGoal> goals) {
    return goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  }
}
