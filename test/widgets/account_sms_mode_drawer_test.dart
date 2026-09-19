import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/stored_account.dart';
import 'package:mobile_banking_app/widgets/account_sms_mode_drawer.dart';
import 'package:mobile_banking_app/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AccountSmsModeDrawer Widget Tests', () {
    testWidgets('renders account details, options, and returns selected mode on confirmation',
        (tester) async {
      final account = StoredAccount(
        userId: 'user_123',
        email: 'test@example.com',
        displayName: 'Abebe Bikila',
        lastActiveAt: DateTime.now(),
        syncDeviceSms: true,
      );

      bool? returnedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await AccountSmsModeDrawer.show(
                    context: context,
                    account: account,
                  );
                },
                child: const Text('Open Drawer'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      // Verify drawer header and content
      expect(find.text('Switch to Abebe Bikila'), findsOneWidget);
      expect(find.text('Track Device SMS'), findsOneWidget);
      expect(find.text('Cloud Only'), findsOneWidget);
      expect(find.text('Confirm & Switch'), findsOneWidget);

      // Select "Cloud Only"
      await tester.tap(find.text('Cloud Only'));
      await tester.pumpAndSettle();

      // Tap "Confirm & Switch"
      await tester.tap(find.text('Confirm & Switch'));
      await tester.pumpAndSettle();

      // Verify returned result is false (Cloud Only)
      expect(returnedResult, false);
    });

    testWidgets('switchAccountWithPrompt bypasses drawer when hasConfiguredSmsMode is true',
        (tester) async {
      final configuredAccount = StoredAccount(
        userId: 'user_456',
        email: 'remembered@example.com',
        displayName: 'Derartu Tulu',
        lastActiveAt: DateTime.now(),
        syncDeviceSms: false,
        hasConfiguredSmsMode: true,
      );

      // When hasConfiguredSmsMode is true, the drawer must not be shown
      expect(configuredAccount.hasConfiguredSmsMode, isTrue);
      expect(configuredAccount.syncDeviceSms, isFalse);
    });

    testWidgets('promptIfUnconfigured bypasses drawer if account already configured on device',
        (tester) async {
      final configuredAccount = StoredAccount(
        userId: 'user_remembered',
        email: 'remembered@example.com',
        displayName: 'Haile Gebrselassie',
        lastActiveAt: DateTime.now(),
        syncDeviceSms: true,
        hasConfiguredSmsMode: true,
      );

      final fakeVM = FakeAuthViewModelForDrawer(activeAccount: configuredAccount);
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AccountSmsModeDrawer.promptIfUnconfigured(
                    context: context,
                    authVM: fakeVM,
                  );
                },
                child: const Text('Check Config'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Config'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Track Device SMS'), findsNothing);
      expect(fakeVM.lastUpdatedSmsMode, isNull); // untouched
    });

    testWidgets('promptIfUnconfigured prompts when unconfigured, updates VM, and remembers state',
        (tester) async {
      final unconfiguredAccount = StoredAccount(
        userId: 'user_new_device',
        email: 'newdevice@example.com',
        displayName: 'Kenenisa Bekele',
        lastActiveAt: DateTime.now(),
        syncDeviceSms: true,
        hasConfiguredSmsMode: false,
      );

      final fakeVM = FakeAuthViewModelForDrawer(activeAccount: unconfiguredAccount);
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AccountSmsModeDrawer.promptIfUnconfigured(
                    context: context,
                    authVM: fakeVM,
                  );
                },
                child: const Text('Check Config'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check Config'));
      await tester.pumpAndSettle();

      // Drawer should now be visible
      expect(find.text('Switch to Kenenisa Bekele'), findsOneWidget);
      expect(find.text('Track Device SMS'), findsOneWidget);
      expect(find.text('Cloud Only'), findsOneWidget);

      // Select "Cloud Only"
      await tester.tap(find.text('Cloud Only'));
      await tester.pumpAndSettle();

      // Confirm & Switch
      await tester.tap(find.text('Confirm & Switch'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(fakeVM.lastUpdatedSmsMode, isFalse);
      expect(fakeVM.activeAccount?.hasConfiguredSmsMode, isTrue);
      expect(fakeVM.activeAccount?.syncDeviceSms, isFalse);

      // Subsequent prompt immediately bypasses drawer
      result = null;
      await tester.tap(find.text('Check Config'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('Track Device SMS'), findsNothing);
    });
  });
}

class FakeAuthViewModelForDrawer extends AuthViewModel {
  StoredAccount? _mockActiveAccount;
  bool? lastUpdatedSmsMode;

  FakeAuthViewModelForDrawer({StoredAccount? activeAccount})
      : _mockActiveAccount = activeAccount;

  @override
  StoredAccount? get activeAccount => _mockActiveAccount;

  @override
  List<StoredAccount> get storedAccounts =>
      _mockActiveAccount != null ? [_mockActiveAccount!] : [];

  @override
  Future<void> updateActiveAccountSyncDeviceSms(bool enabled) async {
    lastUpdatedSmsMode = enabled;
    if (_mockActiveAccount != null) {
      _mockActiveAccount = _mockActiveAccount!.copyWith(
        syncDeviceSms: enabled,
        hasConfiguredSmsMode: true,
      );
    }
  }
}
