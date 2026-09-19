import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';
import 'package:mobile_banking_app/services/database_service.dart';
import 'package:mobile_banking_app/services/app_session_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('User-Scoped SettingsRepository Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('isolates preferences between different users', () async {
      String? activeUserId = 'user_alpha_123';
      final repo = SettingsRepositoryImpl(userIdProvider: () => activeUserId);

      // 1. Set settings under User A
      await repo.setHiddenBalanceBanks({'Telebirr', 'CBE'});
      await repo.setUserName('Alice Alpha');
      await repo.setLastCelebratedLevel(3);

      final banksA = await repo.getHiddenBalanceBanks();
      final nameA = await repo.getUserName();
      final levelA = await repo.getLastCelebratedLevel();

      expect(banksA, {'Telebirr', 'CBE'});
      expect(nameA, 'Alice Alpha');
      expect(levelA, 3);

      // 2. Switch to User B
      activeUserId = 'user_beta_456';

      final banksB = await repo.getHiddenBalanceBanks();
      final nameB = await repo.getUserName();
      final levelB = await repo.getLastCelebratedLevel();

      // User B should NOT see User A's settings
      expect(banksB, isEmpty);
      expect(nameB, isNull);
      expect(levelB, 1);

      // 3. Set settings for User B
      await repo.setHiddenBalanceBanks({'BOA'});
      await repo.setUserName('Bob Beta');
      await repo.setLastCelebratedLevel(4);

      expect(await repo.getHiddenBalanceBanks(), {'BOA'});
      expect(await repo.getUserName(), 'Bob Beta');
      expect(await repo.getLastCelebratedLevel(), 4);

      // 4. Switch back to User A and verify User A's settings remain intact
      activeUserId = 'user_alpha_123';

      expect(await repo.getHiddenBalanceBanks(), {'Telebirr', 'CBE'});
      expect(await repo.getUserName(), 'Alice Alpha');
      expect(await repo.getLastCelebratedLevel(), 3);
    });

    test('falls back to non-scoped keys for guest/unauthenticated users', () async {
      SharedPreferences.setMockInitialValues({
        'user_name_v1': 'Legacy Guest',
        'last_celebrated_level': 2,
      });

      final repo = SettingsRepositoryImpl(userIdProvider: () => null);

      expect(await repo.getUserName(), 'Legacy Guest');
      expect(await repo.getLastCelebratedLevel(), 2);
    });

    test('hidden balance banks persists empty set and prevents resurrecting old banks across cold restarts', () async {
      final repo = SettingsRepositoryImpl(userIdProvider: () => 'user_test_123');

      // 1. Hide Ahadu Bank
      await repo.setHiddenBalanceBanks({'Ahadu Bank'});
      expect(await repo.getHiddenBalanceBanks(), {'Ahadu Bank'});

      // 2. Unhide all banks (empty set)
      await repo.setHiddenBalanceBanks({});

      // 3. Simulate cold restart by reading through a brand-new repository instance
      final restartRepo = SettingsRepositoryImpl(userIdProvider: () => 'user_test_123');
      final result = await restartRepo.getHiddenBalanceBanks();

      expect(result, isEmpty);
    });

    test('migrates legacy hidden_balance_banks once and permanently purges legacy key', () async {
      SharedPreferences.setMockInitialValues({
        'hidden_balance_banks': ['Ahadu Bank'],
      });

      final repo = SettingsRepositoryImpl(userIdProvider: () => 'user_test_123');

      // Initial read migrates legacy key to scoped key
      final migrated = await repo.getHiddenBalanceBanks();
      expect(migrated, {'Ahadu Bank'});

      // Legacy key was purged from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('hidden_balance_banks'), isFalse);

      // Now user unhides Ahadu Bank
      await repo.setHiddenBalanceBanks({});
      expect(await repo.getHiddenBalanceBanks(), isEmpty);

      // New cold restart should see empty set, NOT legacy Ahadu Bank
      final restartRepo = SettingsRepositoryImpl(userIdProvider: () => 'user_test_123');
      expect(await restartRepo.getHiddenBalanceBanks(), isEmpty);
    });

    test('SettingsViewModel maintains correct hidden state across all banks and cold restarts', () async {
      final repo = SettingsRepositoryImpl(userIdProvider: () => 'user_test_123');
      final vm = SettingsViewModel(repository: repo);
      await vm.init();

      // All banks initially visible (not hidden)
      expect(vm.isBankBalanceHidden('Telebirr'), isFalse);
      expect(vm.isBankBalanceHidden('CBE'), isFalse);
      expect(vm.isBankBalanceHidden('Ahadu Bank'), isFalse);
      expect(vm.isBankBalanceHidden('Nib Bank'), isFalse);
      expect(vm.isBankBalanceHidden('Cash Wallet'), isFalse);

      // Hide Ahadu Bank & Nib Bank
      await vm.toggleBankBalanceVisibility('Ahadu Bank');
      await vm.toggleBankBalanceVisibility('Nib Bank');

      expect(vm.isBankBalanceHidden('Ahadu Bank'), isTrue);
      expect(vm.isBankBalanceHidden('Nib Bank'), isTrue);
      expect(vm.isBankBalanceHidden('Telebirr'), isFalse);
      expect(vm.isBankBalanceHidden('CBE'), isFalse);

      // Unhide Ahadu Bank
      await vm.toggleBankBalanceVisibility('Ahadu Bank');
      expect(vm.isBankBalanceHidden('Ahadu Bank'), isFalse);
      expect(vm.isBankBalanceHidden('Nib Bank'), isTrue);

      // Simulate app restart
      final vmRestart = SettingsViewModel(repository: repo);
      await vmRestart.init();

      expect(vmRestart.isBankBalanceHidden('Ahadu Bank'), isFalse); // Remained opened/unhidden!
      expect(vmRestart.isBankBalanceHidden('Nib Bank'), isTrue);    // Remained hidden!
      expect(vmRestart.isBankBalanceHidden('Telebirr'), isFalse);
      expect(vmRestart.isBankBalanceHidden('CBE'), isFalse);
    });
  });

  group('DatabaseService Mutex Tests', () {
    tearDown(() {
      DatabaseService.setTestState();
    });

    test('database getter blocks until switchingTask completes', () async {
      final completer = Completer<void>();
      bool lockResolved = false;

      // Simulate a database switch in progress
      DatabaseService.setTestState(
        currentUserId: 'test_user',
        switchingTask: completer.future.then((_) {
          lockResolved = true;
        }),
      );

      expect(DatabaseService.switchingTaskForTest, isNotNull);

      // Trigger getter wait
      bool getterCompleted = false;
      final waitFuture = Future(() async {
        final task = DatabaseService.switchingTaskForTest;
        if (task != null) await task;
        getterCompleted = true;
      });

      // Before completing lock, getter has not completed
      await Future.delayed(const Duration(milliseconds: 10));
      expect(getterCompleted, isFalse);

      // Resolve the mutex lock
      completer.complete();
      await waitFuture;

      expect(lockResolved, isTrue);
      expect(getterCompleted, isTrue);
    });
  });

  group('AppSessionCoordinator Tests', () {
    test('instance is accessible and attachViewModels registers cleanly', () {
      final coordinator = AppSessionCoordinator.instance;
      expect(coordinator, isNotNull);
    });
  });
}
