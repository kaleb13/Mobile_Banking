import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test hidden banks lifecycle: hide -> restart -> unhide -> restart', () async {
    SharedPreferences.setMockInitialValues({});
    final repo1 = SettingsRepositoryImpl();
    final vm1 = SettingsViewModel(repository: repo1);
    await vm1.init();

    expect(vm1.isBankBalanceHidden('CBE'), isFalse);

    // 1. Hide CBE
    await vm1.toggleBankBalanceVisibility('CBE');
    expect(vm1.isBankBalanceHidden('CBE'), isTrue);

    // 2. Restart app (re-create repo & VM)
    final repo2 = SettingsRepositoryImpl();
    final vm2 = SettingsViewModel(repository: repo2);
    await vm2.init();
    expect(vm2.isBankBalanceHidden('CBE'), isTrue, reason: 'After restart, CBE should still be hidden');

    // 3. Re-open CBE (unhide)
    await vm2.toggleBankBalanceVisibility('CBE');
    expect(vm2.isBankBalanceHidden('CBE'), isFalse, reason: 'CBE should be visible after toggle');

    // 4. Restart app again
    final repo3 = SettingsRepositoryImpl();
    final vm3 = SettingsViewModel(repository: repo3);
    await vm3.init();
    expect(vm3.isBankBalanceHidden('CBE'), isFalse, reason: 'After 2nd restart, CBE should still be visible!');
  });
}
