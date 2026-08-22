import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_banking_app/widgets/custom_progress_bar.dart';
import 'package:mobile_banking_app/widgets/confirmation_dialog.dart';
import 'package:mobile_banking_app/widgets/app_capsule_tab_bar.dart';
import 'package:mobile_banking_app/widgets/app_back_button.dart';
import 'package:mobile_banking_app/widgets/app_menu_button.dart';
import 'package:mobile_banking_app/widgets/app_money_text.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';
import 'package:mobile_banking_app/models/app_currency.dart';
import 'package:mobile_banking_app/models/scan_window_option.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';

void main() {
  group('AppSwitch Widget Tests', () {
    testWidgets('renders active state and responds to tap', (WidgetTester tester) async {
      bool value = true;
      bool toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppSwitch(
                  value: value,
                  onChanged: (val) {
                    toggled = true;
                    value = val;
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify widget exists
      expect(find.byType(AppSwitch), findsOneWidget);

      // Tap widget
      await tester.tap(find.byType(AppSwitch));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
      expect(value, isFalse);
    });
  });

  group('CustomProgressBar Widget Tests', () {
    testWidgets('renders progress bar with label correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomProgressBar(
              progress: 0.75,
              backgroundColor: Colors.grey,
              progressColor: Colors.blue,
              centerLabel: '75%',
            ),
          ),
        ),
      );

      expect(find.byType(CustomProgressBar), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('clamps progress values below 0 and above 1', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomProgressBar(
              progress: 1.5,
              backgroundColor: Colors.grey,
              centerLabel: '150%',
            ),
          ),
        ),
      );

      expect(find.text('150%'), findsOneWidget);
    });
  });

  group('ConfirmationDialog Widget Tests', () {
    testWidgets('renders amount, message, and choice buttons', (WidgetTester tester) async {
      String? selectedChoice;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedChoice = await showDialog<String>(
                      context: context,
                      builder: (_) => const ConfirmationDialog(
                        amount: '500.00',
                        message: 'Received 500 ETB',
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify content
      expect(find.text('Detected Transaction'), findsOneWidget);
      expect(find.text('500.00'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Ignore'), findsOneWidget);

      // Tap 'Income' choice
      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(selectedChoice, equals('income'));
    });
  });

  group('AppPrimaryTabBar Tests', () {
    testWidgets('renders tabs in index mode and triggers onTabChanged', (WidgetTester tester) async {
      int selectedIdx = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppPrimaryTabBar(
                  tabs: const ['Expense', 'Income'],
                  selectedIndex: selectedIdx,
                  onTabChanged: (idx) {
                    setState(() => selectedIdx = idx);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      expect(selectedIdx, equals(1));
    });

    testWidgets('renders tabs in TabController mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 3,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return AppPrimaryTabBar(
                    tabs: const ['Lent Out', 'Borrowed', 'Settled'],
                    controller: DefaultTabController.of(context),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Lent Out'), findsOneWidget);
      expect(find.text('Borrowed'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
    });
  });

  group('AppSecondaryTabBar Tests', () {
    testWidgets('renders scrollable pill tabs and responds to selection', (WidgetTester tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppSecondaryTabBar(
                  tabs: const ['Jan', 'Feb', 'Mar', 'Apr'],
                  selectedIndex: activeIndex,
                  onTabChanged: (idx) {
                    setState(() => activeIndex = idx);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);

      await tester.tap(find.text('Mar'));
      await tester.pumpAndSettle();

      expect(activeIndex, equals(2));
    });
  });

  group('AppTertiaryTabBar Tests', () {
    testWidgets('renders compact chart timeframe tabs and triggers onTabChanged', (WidgetTester tester) async {
      String selectedTimeframe = '30D';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppTertiaryTabBar(
                  tabs: const ['1D', '7D', '30D', '180D', '360D'],
                  selectedTab: selectedTimeframe,
                  onTabChanged: (val) {
                    setState(() => selectedTimeframe = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('1D'), findsOneWidget);
      expect(find.text('7D'), findsOneWidget);
      expect(find.text('30D'), findsOneWidget);
      expect(find.text('180D'), findsOneWidget);
      expect(find.text('360D'), findsOneWidget);

      await tester.tap(find.text('7D'));
      await tester.pumpAndSettle();

      expect(selectedTimeframe, equals('7D'));
    });
  });

  group('AppBackButton Tests', () {
    testWidgets('renders dark variant and triggers onPressed', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBackButton.dark(
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(AppBackButton), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });

    testWidgets('renders light variant and handles custom dimensions', (WidgetTester tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppBackButton.light(
              size: 40.0,
              iconSize: 18.0,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.byType(AppBackButton), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppBackButton),
          matching: find.byType(Container),
        ),
      );

      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.shape, equals(BoxShape.circle));
      expect(container.constraints?.minWidth ?? container.constraints?.maxWidth, isNotNull);

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(pressed, isTrue);
    });
  });

  group('AppMenuButton Tests', () {
    testWidgets('renders dark variant and opens popup menu with white item text', (WidgetTester tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppMenuButton<String>.dark(
              items: const [
                AppMenuItem<String>(value: 'edit', label: 'Edit Transaction'),
                AppMenuItem<String>(value: 'delete', label: 'Delete'),
              ],
              onSelected: (val) => selectedValue = val,
            ),
          ),
        ),
      );

      expect(find.byType(AppMenuButton<String>), findsOneWidget);

      // Tap three-dot menu trigger
      await tester.tap(find.byType(AppMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit Transaction'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Select 'Delete'
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(selectedValue, equals('delete'));
    });
  });

  group('AppMoneyText Widget Synchronized Tests', () {
    testWidgets('renders masked dots when isBalanceVisible is false and amounts when true', (WidgetTester tester) async {
      final fakeRepo = FakeSettingsRepository();
      final settingsVM = SettingsViewModel(repository: fakeRepo);
      await settingsVM.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsViewModel>.value(
          value: settingsVM,
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AppMoneyText(
                    amount: 1540.50,
                    prefix: '+',
                    decimalDigits: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Default is visible -> +1,540.50
      expect(find.text('+1,540.50'), findsOneWidget);
      expect(find.text('+••••••'), findsNothing);

      // Toggle privacy off
      await settingsVM.toggleBalanceVisibility();
      await tester.pumpAndSettle();

      // Now masked synchronously across the UI
      expect(find.text('+••••••'), findsOneWidget);
      expect(find.text('+1,540.50'), findsNothing);

      // Toggle privacy back on
      await settingsVM.toggleBalanceVisibility();
      await tester.pumpAndSettle();

      expect(find.text('+1,540.50'), findsOneWidget);
    });
  });
}

class FakeSettingsRepository implements SettingsRepository {
  bool isBalanceVisible = true;

  @override
  Future<bool> getIsBalanceVisible() async => isBalanceVisible;

  @override
  Future<void> setIsBalanceVisible(bool value) async => isBalanceVisible = value;

  @override
  Future<AppThemeMode> getThemeMode() async => AppThemeMode.dark;

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {}

  @override
  Future<AppCurrency> getCurrency() async => const AppCurrency(
        code: 'birr',
        symbol: 'Br',
        shortLabel: 'Birr',
        name: 'Ethiopian Birr',
      );

  @override
  Future<void> setCurrency(String code) async {}

  @override
  Future<bool> getSmsListeningEnabled() async => true;

  @override
  Future<void> setSmsListeningEnabled(bool value) async {}

  @override
  Future<bool> getPushNotificationsEnabled() async => false;

  @override
  Future<void> setPushNotificationsEnabled(bool value) async {}

  @override
  Future<bool> getReportDailyEnabled() async => false;

  @override
  Future<void> setReportDailyEnabled(bool value) async {}

  @override
  Future<bool> getReportWeeklyEnabled() async => false;

  @override
  Future<void> setReportWeeklyEnabled(bool value) async {}

  @override
  Future<bool> getReportMonthlyEnabled() async => false;

  @override
  Future<void> setReportMonthlyEnabled(bool value) async {}

  @override
  Future<String> getNotifQuickButton1() async => '';

  @override
  Future<void> setNotifQuickButton1(String value) async {}

  @override
  Future<String> getNotifQuickButton2() async => '';

  @override
  Future<void> setNotifQuickButton2(String value) async {}

  @override
  Future<DateTime?> getCustomMonthAnchorDate() async => null;

  @override
  Future<void> setCustomMonthAnchorDate(DateTime? date) async {}

  @override
  Future<String?> getUserName() async => null;

  @override
  Future<void> setUserName(String name) async {}

  @override
  Future<bool> getIsOnboardingComplete() async => true;

  @override
  Future<void> setOnboardingComplete(bool complete) async {}

  @override
  Future<ScanWindowOption> getScanWindow() async => ScanWindowOption.thirtyDays;

  @override
  Future<void> setScanWindow(ScanWindowOption option) async {}
}


