import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/saving_goal.dart';
import 'package:mobile_banking_app/domain/usecases/savings/calculate_goal_feasibility_usecase.dart';
import 'package:mobile_banking_app/domain/usecases/savings/allocate_saving_goals_usecase.dart';

void main() {
  group('CalculateGoalFeasibilityUseCase', () {
    const useCase = CalculateGoalFeasibilityUseCase();

    test('calculates global percentage feasibility accurately', () {
      const goal = SavingGoal(
        id: '1',
        title: 'Emergency Fund',
        targetAmount: 10000,
        savedAmount: 4000,
        allocationMode: AllocationMode.globalPercent,
        accountAllocations: {'*': 30.0},
      );

      final feasibility = useCase.execute(
        goal: goal,
        liveBalances: {'Telebirr': 5000, 'CBE': 15000},
        totalBalance: 20000,
      );

      expect(feasibility.remainingAmount, 6000.0);
      expect(feasibility.availableAmount, 6000.0); // 30% of 20,000 = 6,000
      expect(feasibility.canAffordNow, isTrue);
    });

    test('detects account-specific allocation accurately', () {
      const goal = SavingGoal(
        id: '2',
        title: 'New Laptop',
        targetAmount: 30000,
        savedAmount: 10000,
        allocationMode: AllocationMode.accountSpecific,
        accountAllocations: {'CBE': 50.0},
      );

      final feasibility = useCase.execute(
        goal: goal,
        liveBalances: {'Telebirr': 5000, 'CBE': 20000},
        totalBalance: 25000,
      );

      expect(feasibility.remainingAmount, 20000.0);
      expect(feasibility.availableAmount, 10000.0); // 50% of 20,000 CBE = 10,000
      expect(feasibility.canAffordNow, isFalse);
    });
  });

  group('AllocateSavingGoalsUseCase', () {
    const useCase = AllocateSavingGoalsUseCase();

    test('detects over-allocation across multiple goals on the same bank', () {
      const goals = [
        SavingGoal(
          id: '1',
          title: 'Goal A',
          targetAmount: 5000,
          savedAmount: 1000,
          allocationMode: AllocationMode.accountSpecific,
          accountAllocations: {'CBE': 60.0},
        ),
        SavingGoal(
          id: '2',
          title: 'Goal B',
          targetAmount: 5000,
          savedAmount: 1000,
          allocationMode: AllocationMode.accountSpecific,
          accountAllocations: {'CBE': 50.0},
        ),
      ];

      final totals = useCase.calculateAccountAllocationTotals(goals);

      expect(totals['CBE'], 110.0); // 60 + 50 = 110% (> 100%)
    });
  });
}
