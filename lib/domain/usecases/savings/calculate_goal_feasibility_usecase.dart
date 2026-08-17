import '../../../models/saving_goal.dart';
import '../../../models/goal_feasibility.dart';

class CalculateGoalFeasibilityUseCase {
  const CalculateGoalFeasibilityUseCase();

  /// Calculates dynamic feasibility for a specific goal against current live wallet balances.
  GoalFeasibility execute({
    required SavingGoal goal,
    required Map<String, double> liveBalances,
    required double totalBalance,
    Map<String, double>? allGoalAllocationsForAccount,
  }) {
    double available = 0.0;

    switch (goal.allocationMode) {
      case AllocationMode.globalPercent:
        final pct = goal.accountAllocations['*'] ?? 30.0;
        available = totalBalance * (pct / 100.0);
        break;

      case AllocationMode.accountSpecific:
      case AllocationMode.multiAccount:
        goal.accountAllocations.forEach((account, pct) {
          if (account == '*') {
            available += totalBalance * (pct / 100.0);
          } else {
            // Case-insensitive lookup in live balances
            final key = liveBalances.keys.firstWhere(
              (k) => k.toUpperCase() == account.toUpperCase(),
              orElse: () => '',
            );
            if (key.isNotEmpty) {
              final bal = liveBalances[key] ?? 0.0;
              available += bal * (pct / 100.0);
            }
          }
        });
        break;
    }

    final remaining = goal.remainingAmount;
    final canAfford = available >= remaining;

    // Check for conflict warnings if total allocations exceed 100% on any account
    String warning = '';
    if (allGoalAllocationsForAccount != null) {
      for (final entry in allGoalAllocationsForAccount.entries) {
        if (entry.value > 100.0) {
          warning = '${entry.key} is over-allocated (${entry.value.toStringAsFixed(0)}%)';
          break;
        }
      }
    }

    return GoalFeasibility(
      availableAmount: available,
      remainingAmount: remaining,
      canAffordNow: canAfford,
      conflictWarning: warning,
    );
  }
}
