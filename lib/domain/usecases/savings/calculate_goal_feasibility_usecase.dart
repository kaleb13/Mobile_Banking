import '../../../models/saving_goal.dart';
import '../../../models/goal_feasibility.dart';

class CalculateGoalFeasibilityUseCase {
  const CalculateGoalFeasibilityUseCase();

  /// Calculates waterfall feasibility across all goals ordered by priority.
  /// Higher priority goals claim funds first; lower priority goals can only
  /// draw from remaining unallocated balances in the accounts pool.
  Map<String, GoalFeasibility> calculateWaterfall({
    required List<SavingGoal> goals,
    required Map<String, double> liveBalances,
    required double totalBalance,
  }) {
    final results = <String, GoalFeasibility>{};

    // Make a mutable pool of balances for case-insensitive account tracking
    final Map<String, double> pool = {};
    for (final entry in liveBalances.entries) {
      pool[entry.key] = entry.value > 0 ? entry.value : 0.0;
    }

    // Sort goals: active first, then by priority ascending (1, 2, 3...)
    final sortedGoals = List<SavingGoal>.from(goals)..sort((a, b) {
      final aActive = a.status == 'active' && !a.isCompleted;
      final bActive = b.status == 'active' && !b.isCompleted;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return a.priority.compareTo(b.priority);
    });

    for (final goal in sortedGoals) {
      if (goal.isCompleted) {
        results[goal.id] = GoalFeasibility(
          availableAmount: 0.0,
          remainingAmount: 0.0,
          canAffordNow: true,
          conflictWarning: '',
        );
        continue;
      }

      if (goal.status == 'on_hold') {
        results[goal.id] = GoalFeasibility(
          availableAmount: 0.0,
          remainingAmount: goal.remainingAmount,
          canAffordNow: false,
          conflictWarning: 'Goal is on hold',
        );
        continue;
      }

      double availableForGoal = 0.0;
      final remainingNeeded = goal.remainingAmount;
      String conflictWarning = '';

      switch (goal.allocationMode) {
        case AllocationMode.globalPercent:
          final pct = (goal.accountAllocations['*'] ?? 30.0).clamp(0.0, 100.0);
          final currentGlobalPool = pool.values.fold(0.0, (sum, val) => sum + (val > 0 ? val : 0.0));
          final maxGlobalClaimable = currentGlobalPool * (pct / 100.0);
          availableForGoal = maxGlobalClaimable;

          // Deduct claimed amount proportionally from accounts in pool
          if (remainingNeeded > 0 && currentGlobalPool > 0) {
            final claimAmount = remainingNeeded < maxGlobalClaimable ? remainingNeeded : maxGlobalClaimable;
            final ratio = (claimAmount / currentGlobalPool).clamp(0.0, 1.0);
            for (final key in pool.keys.toList()) {
              pool[key] = (pool[key]! * (1.0 - ratio)).clamp(0.0, double.infinity);
            }
          }
          break;

        case AllocationMode.accountSpecific:
          if (goal.accountAllocations.isEmpty) {
            conflictWarning = 'No account selected';
            break;
          }
          final entry = goal.accountAllocations.entries.first;
          final accountName = entry.key;
          final pct = entry.value.clamp(0.0, 100.0);

          final poolKey = pool.keys.firstWhere(
            (k) => k.toUpperCase() == accountName.toUpperCase(),
            orElse: () => '',
          );

          if (poolKey.isEmpty || (pool[poolKey] ?? 0.0) <= 0) {
            availableForGoal = 0.0;
            conflictWarning = '$accountName has insufficient balance';
          } else {
            final bankPool = pool[poolKey]!;
            final maxClaimable = bankPool * (pct / 100.0);
            availableForGoal = maxClaimable;

            if (remainingNeeded > 0) {
              final claimAmount = remainingNeeded < maxClaimable ? remainingNeeded : maxClaimable;
              pool[poolKey] = (pool[poolKey]! - claimAmount).clamp(0.0, double.infinity);
            }
          }
          break;

        case AllocationMode.multiAccount:
          final Map<String, double> claimFromAccounts = {};

          goal.accountAllocations.forEach((accountName, pctRaw) {
            final pct = pctRaw.clamp(0.0, 100.0);
            if (accountName == '*') {
              final currentGlobalPool = pool.values.fold(0.0, (sum, val) => sum + (val > 0 ? val : 0.0));
              final maxGlobal = currentGlobalPool * (pct / 100.0);
              availableForGoal += maxGlobal;
            } else {
              final poolKey = pool.keys.firstWhere(
                (k) => k.toUpperCase() == accountName.toUpperCase(),
                orElse: () => '',
              );
              if (poolKey.isNotEmpty) {
                final bankPool = pool[poolKey] ?? 0.0;
                final maxClaimable = bankPool * (pct / 100.0);
                availableForGoal += maxClaimable;
                claimFromAccounts[poolKey] = maxClaimable;
              }
            }
          });

          if (remainingNeeded > 0 && availableForGoal > 0) {
            final totalClaim = remainingNeeded < availableForGoal ? remainingNeeded : availableForGoal;
            final ratio = (totalClaim / availableForGoal).clamp(0.0, 1.0);
            for (final accEntry in claimFromAccounts.entries) {
              final accClaim = accEntry.value * ratio;
              pool[accEntry.key] = ((pool[accEntry.key] ?? 0.0) - accClaim).clamp(0.0, double.infinity);
            }
          }
          break;
      }

      final canAfford = availableForGoal >= remainingNeeded && remainingNeeded > 0;

      results[goal.id] = GoalFeasibility(
        availableAmount: availableForGoal,
        remainingAmount: remainingNeeded,
        canAffordNow: canAfford,
        conflictWarning: conflictWarning,
      );
    }

    return results;
  }

  /// Calculates dynamic feasibility for a specific goal against current live wallet balances.
  GoalFeasibility execute({
    required SavingGoal goal,
    required Map<String, double> liveBalances,
    required double totalBalance,
    Map<String, double>? allGoalAllocationsForAccount,
  }) {
    final waterfall = calculateWaterfall(
      goals: [goal],
      liveBalances: liveBalances,
      totalBalance: totalBalance,
    );
    return waterfall[goal.id] ?? GoalFeasibility(
      availableAmount: 0.0,
      remainingAmount: goal.remainingAmount,
      canAffordNow: false,
      conflictWarning: '',
    );
  }
}
