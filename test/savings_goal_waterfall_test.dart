import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/saving_goal.dart';
import 'package:mobile_banking_app/domain/usecases/savings/calculate_goal_feasibility_usecase.dart';

void main() {
  const useCase = CalculateGoalFeasibilityUseCase();

  group('CalculateGoalFeasibilityUseCase - Priority Waterfall Tests', () {
    test('40,000 balance against 80,000 target gives expected coverage with Global & Custom modes', () {
      final liveBalances = {'CBE': 30000.0, 'Ahadu Bank': 10000.0};
      final totalBalance = 40000.0;

      // 1. 100% Global Allocation
      final goal100Global = const SavingGoal(
        id: 'g_100_global',
        title: 'Car',
        targetAmount: 80000.0,
        savedAmount: 0.0,
        allocationMode: AllocationMode.globalPercent,
        accountAllocations: {'*': 100.0},
      );

      final res100 = useCase.execute(
        goal: goal100Global,
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );
      expect(res100.availableAmount, 40000.0);
      expect(res100.availableAmount / goal100Global.targetAmount, 0.50); // 50% covered

      // 2. 50% Global Allocation
      final goal50Global = const SavingGoal(
        id: 'g_50_global',
        title: 'Car',
        targetAmount: 80000.0,
        savedAmount: 0.0,
        allocationMode: AllocationMode.globalPercent,
        accountAllocations: {'*': 50.0},
      );

      final res50 = useCase.execute(
        goal: goal50Global,
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );
      expect(res50.availableAmount, 20000.0);
      expect(res50.availableAmount / goal50Global.targetAmount, 0.25); // 25% covered

      // 3. Custom % with Ahadu Bank only at 100%
      final goalAhadu100 = const SavingGoal(
        id: 'g_ahadu_100',
        title: 'Car',
        targetAmount: 80000.0,
        savedAmount: 0.0,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'Ahadu Bank': 100.0},
      );

      final resAhadu100 = useCase.execute(
        goal: goalAhadu100,
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );
      expect(resAhadu100.availableAmount, 10000.0);
      expect(resAhadu100.availableAmount / goalAhadu100.targetAmount, 0.125); // 12.5% covered

      // 4. Custom % with Ahadu Bank only at 40%
      final goalAhadu40 = const SavingGoal(
        id: 'g_ahadu_40',
        title: 'Car',
        targetAmount: 80000.0,
        savedAmount: 0.0,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'Ahadu Bank': 40.0},
      );

      final resAhadu40 = useCase.execute(
        goal: goalAhadu40,
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );
      expect(resAhadu40.availableAmount, 4000.0);
      expect(resAhadu40.availableAmount / goalAhadu40.targetAmount, 0.05); // 5% covered
    });

    test('Priority #1 exhausts specific bank, leaving Priority #2 with 0 available', () {
      final liveBalances = {'CBE': 10000.0, 'Telebirr': 5000.0};
      final totalBalance = 15000.0;

      final goal1 = const SavingGoal(
        id: 'g1',
        title: 'Goal 1',
        targetAmount: 10000.0,
        savedAmount: 0.0,
        priority: 1,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'CBE': 100.0},
      );

      final goal2 = const SavingGoal(
        id: 'g2',
        title: 'Goal 2',
        targetAmount: 5000.0,
        savedAmount: 0.0,
        priority: 2,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'CBE': 50.0},
      );

      final results = useCase.calculateWaterfall(
        goals: [goal1, goal2],
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );

      // Goal 1 (Priority 1) should have 10,000 available and can afford now
      expect(results['g1']!.availableAmount, 10000.0);
      expect(results['g1']!.canAffordNow, true);

      // Goal 2 (Priority 2) sees 0 remaining in CBE because Goal 1 took 100% of 10,000
      expect(results['g2']!.availableAmount, 0.0);
      expect(results['g2']!.canAffordNow, false);
    });

    test('Reversing priority gives Priority #1 first claim on bank funds', () {
      final liveBalances = {'CBE': 10000.0, 'Telebirr': 5000.0};
      final totalBalance = 15000.0;

      // Goal 2 is now Priority 1 (50% of CBE = 5,000 max claim)
      final goal2 = const SavingGoal(
        id: 'g2',
        title: 'Goal 2',
        targetAmount: 5000.0,
        savedAmount: 0.0,
        priority: 1,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'CBE': 50.0},
      );

      // Goal 1 is now Priority 2 (100% of remaining CBE = 5,000 available)
      final goal1 = const SavingGoal(
        id: 'g1',
        title: 'Goal 1',
        targetAmount: 10000.0,
        savedAmount: 0.0,
        priority: 2,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'CBE': 100.0},
      );

      final results = useCase.calculateWaterfall(
        goals: [goal2, goal1],
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );

      // Goal 2 gets 5,000 and can afford
      expect(results['g2']!.availableAmount, 5000.0);
      expect(results['g2']!.canAffordNow, true);

      // Goal 1 gets remaining 5,000 from CBE (10,000 - 5,000)
      expect(results['g1']!.availableAmount, 5000.0);
      expect(results['g1']!.canAffordNow, false); // needs 10,000
    });

    test('Global % waterfall deducts proportionally across accounts', () {
      final liveBalances = {'CBE': 10000.0, 'Telebirr': 10000.0};
      final totalBalance = 20000.0;

      // Goal 1: Priority 1, Needs 6,000, 50% global (10,000 available, claims 6,000)
      final goal1 = const SavingGoal(
        id: 'g1',
        title: 'Goal 1',
        targetAmount: 6000.0,
        savedAmount: 0.0,
        priority: 1,
        allocationMode: AllocationMode.globalPercent,
        accountAllocations: {'*': 50.0},
      );

      // Goal 2: Priority 2, Needs 5,000, 50% global (50% of remaining 14,000 = 7,000 available)
      final goal2 = const SavingGoal(
        id: 'g2',
        title: 'Goal 2',
        targetAmount: 5000.0,
        savedAmount: 0.0,
        priority: 2,
        allocationMode: AllocationMode.globalPercent,
        accountAllocations: {'*': 50.0},
      );

      final results = useCase.calculateWaterfall(
        goals: [goal1, goal2],
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );

      expect(results['g1']!.availableAmount, 10000.0);
      expect(results['g1']!.canAffordNow, true);

      expect(results['g2']!.availableAmount, 7000.0);
      expect(results['g2']!.canAffordNow, true);
    });

    test('On-hold and completed goals do not consume pool balance', () {
      final liveBalances = {'CBE': 10000.0};
      final totalBalance = 10000.0;

      final completedGoal = const SavingGoal(
        id: 'g_completed',
        title: 'Completed',
        targetAmount: 5000.0,
        savedAmount: 5000.0,
        priority: 1,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'CBE': 100.0},
      );

      final onHoldGoal = const SavingGoal(
        id: 'g_on_hold',
        title: 'On Hold',
        targetAmount: 5000.0,
        savedAmount: 0.0,
        status: 'on_hold',
        priority: 2,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'CBE': 100.0},
      );

      final activeGoal = const SavingGoal(
        id: 'g_active',
        title: 'Active Goal',
        targetAmount: 10000.0,
        savedAmount: 0.0,
        priority: 3,
        allocationMode: AllocationMode.multiAccount,
        accountAllocations: {'CBE': 100.0},
      );

      final results = useCase.calculateWaterfall(
        goals: [completedGoal, onHoldGoal, activeGoal],
        liveBalances: liveBalances,
        totalBalance: totalBalance,
      );

      // Active goal gets full 10,000 balance
      expect(results['g_active']!.availableAmount, 10000.0);
      expect(results['g_active']!.canAffordNow, true);
    });
  });
}
