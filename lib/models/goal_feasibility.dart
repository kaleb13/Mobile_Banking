/// Computed feasibility result for a single saving goal.
class GoalFeasibility {
  /// Total money currently "earmarked" for this goal based on its allocation
  /// settings and current live account balances.
  final double availableAmount;

  /// How much is still needed: targetAmount - savedAmount (clamped to 0).
  final double remainingAmount;

  /// True when availableAmount >= remainingAmount.
  final bool canAffordNow;

  /// Non-empty when the goal's allocations exceed 100% of a shared account.
  final String conflictWarning;

  /// The fraction 0..1 of the remaining that the available covers.
  double get coverageRatio =>
      remainingAmount <= 0 ? 1.0 : (availableAmount / remainingAmount).clamp(0.0, 1.0);

  const GoalFeasibility({
    required this.availableAmount,
    required this.remainingAmount,
    required this.canAffordNow,
    this.conflictWarning = '',
  });

  bool get hasConflict => conflictWarning.isNotEmpty;
}
