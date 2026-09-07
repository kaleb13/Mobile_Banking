import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_banking_app/models/reason.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/cash_transaction.dart';
import 'package:mobile_banking_app/models/sender.dart';
import 'package:mobile_banking_app/models/app_currency.dart';
import 'package:mobile_banking_app/models/scan_window_option.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';
import 'package:mobile_banking_app/presentation/viewmodels/settings_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/cash_wallet_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/analytics_view_model.dart';
import 'package:mobile_banking_app/data/repositories/settings_repository.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/data/repositories/cash_wallet_repository.dart';
import 'package:mobile_banking_app/screens/dashboard/analysis_screen.dart';
import 'package:mobile_banking_app/screens/dashboard/category_detail_screen.dart';
import 'package:mobile_banking_app/screens/dashboard/reason_transactions_screen.dart';
import 'package:mobile_banking_app/models/transaction_split.dart';
import 'package:mobile_banking_app/models/expense_definition.dart';
import 'package:mobile_banking_app/screens/dashboard/all_transactions_screen.dart';
import 'package:mobile_banking_app/screens/dashboard/date_transactions_screen.dart';
import 'package:mobile_banking_app/widgets/counterparty_insight_sheet.dart';
import 'package:mobile_banking_app/widgets/daily_net_heatmap_widget.dart';
import 'package:mobile_banking_app/widgets/animated_reasons_icon.dart';
import 'package:mobile_banking_app/utils/counterparty_matcher.dart';

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

  DateTime? scanWindowStartDate;

  @override
  Future<DateTime?> getScanWindowStartDate() async => scanWindowStartDate;

  @override
  Future<void> setScanWindowStartDate(DateTime? date) async {
    scanWindowStartDate = date;
  }

  @override
  Future<DateTime?> getEffectiveScanWindowAnchorDate() async => scanWindowStartDate;

  Set<String> hiddenBanks = {};

  @override
  Future<Set<String>> getHiddenBalanceBanks() async => hiddenBanks;

  @override
  Future<void> setHiddenBalanceBanks(Set<String> banks) async {
    hiddenBanks = banks;
  }

  int lastCelebratedLevel = 1;
  @override
  Future<int> getLastCelebratedLevel() async => lastCelebratedLevel;
  @override
  Future<void> setLastCelebratedLevel(int level) async {
    lastCelebratedLevel = level;
  }

  bool isNotifGuideDismissed = false;
  @override
  Future<bool> getIsNotifGuideDismissed() async => isNotifGuideDismissed;
  @override
  Future<void> setIsNotifGuideDismissed(bool dismissed) async {
    isNotifGuideDismissed = dismissed;
  }
}

class FakeTransactionRepository implements TransactionRepository {
  List<AppTransaction> transactions = [];
  List<AppReason> reasons = [];
  List<AppSender> senders = [];
  List<AppReasonLink> reasonLinks = [];
  List<TransactionSplit> splits = [];
  Set<String> pausedBanks = {};

  @override
  Future<List<AppTransaction>> getTransactions({int? limit, int? offset}) async => transactions;

  @override
  Future<List<AppReason>> getReasons() async => reasons;

  @override
  Future<List<AppSender>> getSenders() async => senders;

  @override
  Future<List<AppReasonLink>> getReasonLinks() async => reasonLinks;

  @override
  Future<Set<String>> getPausedBanks() async => pausedBanks;

  @override
  Future<List<TransactionSplit>> getAllTransactionSplits() async => splits;

  @override
  Future<List<TransactionSplit>> getSplitsForTransaction(String transactionId) async =>
      splits.where((s) => s.transactionId == transactionId).toList();

  @override
  Future<void> saveTransactionSplits(String transactionId, List<TransactionSplit> newSplits) async {
    splits.removeWhere((s) => s.transactionId == transactionId);
    splits.addAll(newSplits);
  }

  @override
  Future<int> deleteTransactionSplits(String transactionId) async {
    final count = splits.where((s) => s.transactionId == transactionId).length;
    splits.removeWhere((s) => s.transactionId == transactionId);
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCashWalletRepository implements CashWalletRepository {
  List<CashTransaction> cashTransactions = [];

  @override
  Future<List<CashTransaction>> getCashTransactions() async => cashTransactions;

  @override
  Future<List<ExpenseDefinition>> getExpenseDefinitions() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PeriodFilter Enum Tests', () {
    test('contains all expected periods including allTime and customRange', () {
      expect(PeriodFilter.values, contains(PeriodFilter.allTime));
      expect(PeriodFilter.values, contains(PeriodFilter.customRange));
      expect(PeriodFilter.values.length, 7);
    });
  });

  group('CategoryDetailScreen Subcategory Pill Filter Tests', () {
    late SettingsViewModel settingsVM;

    setUp(() async {
      final fakeSettings = FakeSettingsRepository();
      settingsVM = SettingsViewModel(repository: fakeSettings);
      await settingsVM.init();
    });

    testWidgets('renders active subcategories and excludes 0-count subcategories', (tester) async {
      final tx1 = AppTransaction(
        id: 'tx1',
        name: 'Telebirr',
        amount: 150.0,
        type: 'expense',
        date: DateTime.now(),
        sender: 'Restaurant A',
        category: 'Food',
        rawMessage: 'msg1',
        isAutoDetected: true,
        reason: 'Lunch',
      );
      final tx2 = AppTransaction(
        id: 'tx2',
        name: 'Telebirr',
        amount: 250.0,
        type: 'expense',
        date: DateTime.now(),
        sender: 'Restaurant B',
        category: 'Food',
        rawMessage: 'msg2',
        isAutoDetected: true,
        reason: 'Dinner',
      );

      final subcategories = [
        SubcategoryAnalysisItem(
          name: 'Lunch',
          totalAmount: 150.0,
          bankTransactions: [tx1],
          cashTransactions: [],
        ),
        SubcategoryAnalysisItem(
          name: 'Dinner',
          totalAmount: 250.0,
          bankTransactions: [tx2],
          cashTransactions: [],
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
          ],
          child: MaterialApp(
            home: CategoryDetailScreen(
              categoryName: 'Food',
              categoryColor: Colors.orange,
              totalAmount: 400.0,
              periodLabel: 'All Time',
              directBankTransactions: const [],
              directCashTransactions: const [],
              allBankTransactions: [tx1, tx2],
              allCashTransactions: const [],
              subcategories: subcategories,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify subcategory chips are rendered in the horizontal bar
      expect(find.text('All Subcategories'), findsOneWidget);
      final lunchPill = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Lunch' && w.style?.fontSize == 12,
      );
      final dinnerPill = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Dinner' && w.style?.fontSize == 12,
      );
      expect(lunchPill, findsOneWidget);
      expect(dinnerPill, findsOneWidget);

      // Verify Bakery (which has 0 count and wasn't in subcategories) is not present
      expect(find.text('Bakery'), findsNothing);

      // Tap on 'Lunch' pill
      await tester.tap(lunchPill);
      await tester.pumpAndSettle();

      // Verify Lunch tx is visible and Dinner tx is filtered out
      expect(find.text('Restaurant A'), findsOneWidget);
      expect(find.text('Restaurant B'), findsNothing);
    });
  });

  group('ReasonTransactionsScreen Dynamic Subcategory Pill Filter Tests', () {
    late SettingsViewModel settingsVM;
    late TransactionsViewModel txVM;
    late CashWalletViewModel cashVM;
    late FakeTransactionRepository txRepo;
    late FakeCashWalletRepository cashRepo;

    final foodCategory = AppReason(id: 1, name: 'Food');
    final lunchSub = AppReason(id: 101, name: 'Lunch', parentId: 1);
    final dinnerSub = AppReason(id: 102, name: 'Dinner', parentId: 1);
    final bakerySub = AppReason(id: 103, name: 'Bakery', parentId: 1);

    final tx1 = AppTransaction(
      id: 'tx1',
      name: 'Telebirr',
      amount: 120.0,
      type: 'expense',
      date: DateTime.now(),
      sender: 'Cafe 1',
      category: 'Food',
      rawMessage: 'msg1',
      isAutoDetected: true,
      subcategoryId: 101,
      reason: 'Lunch',
    );
    final tx2 = AppTransaction(
      id: 'tx2',
      name: 'Telebirr',
      amount: 300.0,
      type: 'expense',
      date: DateTime.now(),
      sender: 'Bistro 2',
      category: 'Food',
      rawMessage: 'msg2',
      isAutoDetected: true,
      subcategoryId: 102,
      reason: 'Dinner',
    );

    setUp(() async {
      final fakeSettings = FakeSettingsRepository();
      settingsVM = SettingsViewModel(repository: fakeSettings);
      await settingsVM.init();

      txRepo = FakeTransactionRepository();
      txRepo.transactions = [tx1, tx2];
      txRepo.reasons = [foodCategory, lunchSub, dinnerSub, bakerySub];

      cashRepo = FakeCashWalletRepository();

      txVM = TransactionsViewModel(repository: txRepo);
      await txVM.loadAll();

      cashVM = CashWalletViewModel(repository: cashRepo);
    });

    testWidgets('renders active subcategories for category and filters on selection', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
            ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
            ChangeNotifierProvider<CashWalletViewModel>.value(value: cashVM),
          ],
          child: MaterialApp(
            home: ReasonTransactionsScreen(
              reason: foodCategory,
              transactions: [tx1, tx2],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify active subcategories appear in pill bar
      expect(find.text('All Subcategories'), findsOneWidget);
      final lunchPill = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Lunch' && w.style?.fontSize == 12,
      );
      final dinnerPill = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'Dinner' && w.style?.fontSize == 12,
      );
      expect(lunchPill, findsOneWidget);
      expect(dinnerPill, findsOneWidget);

      // Verify Bakery (0 transactions) is NOT rendered
      expect(find.text('Bakery'), findsNothing);

      // Tap on Lunch pill
      await tester.tap(lunchPill);
      await tester.pumpAndSettle();

      // Verify Cafe 1 is displayed, Bistro 2 is filtered
      expect(find.text('Cafe 1'), findsOneWidget);
      expect(find.text('Bistro 2'), findsNothing);
    });
  });

  group('CounterpartyInsightSheet & AllTransactionsScreen Tests', () {
    late SettingsViewModel settingsVM;
    late TransactionsViewModel txVM;
    late FakeTransactionRepository txRepo;

    final tx1 = AppTransaction(
      id: 'tx1',
      name: 'Telebirr',
      amount: 100.0,
      type: 'expense',
      date: DateTime.now().subtract(const Duration(days: 40)), // 40 days ago
      sender: 'Abebe Bikila',
      category: 'Transfer',
      rawMessage: 'msg1',
      isAutoDetected: true,
    );
    final tx2 = AppTransaction(
      id: 'tx2',
      name: 'CBE',
      amount: 500.0,
      type: 'income',
      date: DateTime.now().subtract(const Duration(days: 20)),
      sender: 'Abebe Bikila',
      category: 'Transfer',
      rawMessage: 'msg2',
      isAutoDetected: true,
    );
    final tx3 = AppTransaction(
      id: 'tx3',
      name: 'Telebirr',
      amount: 200.0,
      type: 'expense',
      date: DateTime.now().subtract(const Duration(days: 5)),
      sender: 'Abebe Bikila',
      category: 'Transfer',
      rawMessage: 'msg3',
      isAutoDetected: true,
    );
    final tx4 = AppTransaction(
      id: 'tx4',
      name: 'BOA',
      amount: 50.0,
      type: 'expense',
      date: DateTime.now(),
      sender: 'Abebe Bikila',
      category: 'Transfer',
      rawMessage: 'msg4',
      isAutoDetected: true,
    );

    setUp(() async {
      final fakeSettings = FakeSettingsRepository();
      settingsVM = SettingsViewModel(repository: fakeSettings);
      await settingsVM.init();

      txRepo = FakeTransactionRepository();
      txRepo.transactions = [tx1, tx2, tx3, tx4];
      txRepo.senders = [
        AppSender(id: '1', senderName: 'Telebirr'),
        AppSender(id: '2', senderName: 'CBE'),
        AppSender(id: '3', senderName: 'BOA'),
      ];

      txVM = TransactionsViewModel(repository: txRepo);
      await txVM.loadAll();
    });

    testWidgets('CounterpartyInsightSheet renders metrics, channels, and supports Show All toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
            ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CounterpartyInsightSheet(personName: 'Abebe Bikila'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Net Standing (+250 ETB: received 500, sent 350)
      expect(find.text('Net Standing'), findsOneWidget);
      expect(find.text('Total To'), findsOneWidget);
      expect(find.text('Total From'), findsOneWidget);

      // Channels
      expect(find.textContaining('Channels:'), findsOneWidget);

      // View All button shows all 4 transactions across all time
      expect(find.text('View All 4 Transactions'), findsOneWidget);

      // Inline "Show All (4)" toggle is present
      expect(find.text('Show All (4)'), findsOneWidget);
      await tester.tap(find.text('Show All (4)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Show Recent'), findsOneWidget);
      expect(find.text('All Interactions (4)'), findsOneWidget);
    });

    testWidgets('AllTransactionsScreen defaults date filter to All Time and renders counterparty Net Flow card', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsViewModel>.value(value: settingsVM),
            ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
          ],
          child: const MaterialApp(
            home: AllTransactionsScreen(
              initialSenderFilter: 'Abebe Bikila',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // All 4 transactions (including tx1 from 40 days ago) should be visible
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('Abebe Bikila'), findsWidgets);
      expect(find.text('4 transactions with this counterparty'), findsOneWidget);
      expect(find.textContaining('Net Standing'), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);
    });

    test('CounterpartyMatcher cross-bank name normalization and matching', () {
      expect(
        CounterpartyMatcher.matches(
          'Nathnael Tesfaye T/mariam',
          'Nathnael Tesfaye',
        ),
        isTrue,
      );
      expect(
        CounterpartyMatcher.matches(
          'account 1****4239 (Nathnael Tesfaye)',
          'Nathnael Tesfaye',
        ),
        isTrue,
      );
      expect(
        CounterpartyMatcher.matches(
          'to Nathnael Tesfaye on 12/03/2026',
          'NATHNAEL TESFAYE',
        ),
        isTrue,
      );
      expect(
        CounterpartyMatcher.normalize('account 1****4239 (Nathnael Tesfaye)'),
        'Nathnael Tesfaye',
      );
    });

    test('CounterpartyMatcher accurately filters all 13 CBE transactions with varying name formats', () {
      final List<AppTransaction> cbeTxs = [];
      for (int i = 0; i < 13; i++) {
        String senderVariant;
        if (i % 4 == 0) {
          senderVariant = 'Nathnael Tesfaye T/mariam';
        } else if (i % 4 == 1) {
          senderVariant = 'account 1****4239 (Nathnael Tesfaye)';
        } else if (i % 4 == 2) {
          senderVariant = 'to Nathnael Tesfaye on 02/08/2026';
        } else {
          senderVariant = 'Nathnael Tesfaye';
        }

        cbeTxs.add(
          AppTransaction(
            id: 'cbe_$i',
            name: 'CBE',
            amount: 100.0,
            type: i.isEven ? 'expense' : 'income',
            date: DateTime.now().subtract(Duration(days: i)),
            sender: senderVariant,
            category: 'Transfer',
            rawMessage: 'cbe msg $i',
            isAutoDetected: true,
          ),
        );
      }

      final matched = CounterpartyMatcher.filterForCounterparty(
        cbeTxs,
        'Nathnael Tesfaye T/mariam',
      );
      expect(matched.length, 13);
    });

    testWidgets('DailyNetHeatmapWidget reacts properly to analysisType Expenses, Income, and All', (tester) async {
      final testDate = DateTime(2026, 8, 15);
      final List<AppTransaction> txList = [
        AppTransaction(
          id: 'tx_exp',
          name: 'CBE',
          amount: 500.0,
          type: 'expense',
          date: DateTime(2026, 8, 10),
          sender: 'Abebe',
          category: 'General',
          rawMessage: 'msg',
          isAutoDetected: true,
        ),
        AppTransaction(
          id: 'tx_inc',
          name: 'CBE',
          amount: 1000.0,
          type: 'income',
          date: DateTime(2026, 8, 12),
          sender: 'CBE',
          category: 'General',
          rawMessage: 'msg',
          isAutoDetected: true,
        ),
      ];

      // 1. Expenses Mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyNetHeatmapWidget(
              bankTransactions: txList,
              cashTransactions: const [],
              selectedDate: testDate,
              analysisType: 'Expenses',
              isBalanceVisible: true,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Daily Expense'), findsOneWidget);
      expect(find.text('-500'), findsOneWidget);
      expect(find.text('+1.0K'), findsNothing);

      // 2. Income Mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyNetHeatmapWidget(
              bankTransactions: txList,
              cashTransactions: const [],
              selectedDate: testDate,
              analysisType: 'Income',
              isBalanceVisible: true,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Daily Income'), findsOneWidget);
      expect(find.text('+1.0K'), findsOneWidget);
      expect(find.text('-500'), findsNothing);

      // 3. All / Net Mode
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyNetHeatmapWidget(
              bankTransactions: txList,
              cashTransactions: const [],
              selectedDate: testDate,
              analysisType: 'All',
              isBalanceVisible: true,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Daily Net'), findsOneWidget);
      expect(find.text('-500'), findsOneWidget);
      expect(find.text('+1.0K'), findsOneWidget);

      // 4. Custom Date Range Mode
      final customRange = DateTimeRange(
        start: DateTime(2026, 3, 10),
        end: DateTime(2026, 3, 20),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyNetHeatmapWidget(
              bankTransactions: txList,
              cashTransactions: const [],
              selectedDate: testDate,
              analysisType: 'All',
              periodType: HeatmapPeriodType.customRange,
              highlightedWeekRange: customRange,
              isBalanceVisible: true,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Daily Net · Mar 10 - Mar 20'), findsOneWidget);

      // 5. Inactive Day Grayed Contrast Mode (When a day is selected)
      final contrastTxs = [
        AppTransaction(
          id: 'tx_subtle',
          name: 'Telebirr',
          amount: 500.0,
          type: 'expense',
          date: DateTime(2026, 8, 2),
          sender: 'Store',
          category: 'General',
          rawMessage: 'msg',
          isAutoDetected: true,
        ),
        AppTransaction(
          id: 'tx_heavy',
          name: 'CBE',
          amount: 25000.0,
          type: 'income',
          date: DateTime(2026, 8, 3),
          sender: 'Work',
          category: 'General',
          rawMessage: 'msg',
          isAutoDetected: true,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyNetHeatmapWidget(
              bankTransactions: contrastTxs,
              cashTransactions: const [],
              selectedDate: testDate,
              analysisType: 'All',
              selectedDay: DateTime(2026, 3, 1),
              isBalanceVisible: true,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final animatedContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final tileColors = animatedContainers
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toSet();
      expect(tileColors, contains(AppColors.heatmapNeutral));
      expect(tileColors, contains(AppColors.heatmapInactiveSubtle));
      expect(tileColors, contains(AppColors.heatmapInactiveHeavy));
    });
  });

  group('DateTransactionsScreen Tests', () {
    late FakeTransactionRepository txRepo;
    late FakeCashWalletRepository cashRepo;
    late TransactionsViewModel txVM;
    late CashWalletViewModel cashVM;

    final targetDate = DateTime(2026, 3, 10, 14, 30);
    final otherDate = DateTime(2026, 3, 11, 10, 0);

    final txDay1 = AppTransaction(
      id: 'dtx1',
      name: 'Telebirr',
      amount: 450.0,
      type: 'expense',
      date: targetDate,
      sender: 'Supermarket',
      category: 'Food',
      rawMessage: 'msg1',
      isAutoDetected: true,
    );

    final txDay2 = AppTransaction(
      id: 'dtx2',
      name: 'Commercial Bank of Ethiopia',
      amount: 1200.0,
      type: 'income',
      date: targetDate,
      sender: 'Employer Inc',
      category: 'Salary',
      rawMessage: 'msg2',
      isAutoDetected: true,
    );

    final txOther = AppTransaction(
      id: 'dtx3',
      name: 'Telebirr',
      amount: 100.0,
      type: 'expense',
      date: otherDate,
      sender: 'Coffee Shop',
      category: 'Food',
      rawMessage: 'msg3',
      isAutoDetected: true,
    );

    final cashDay = CashTransaction(
      id: 101,
      amount: 150.0,
      type: 'expense',
      date: targetDate,
      description: 'Taxi Fare',
      reasonName: 'Transport',
    );

    setUp(() async {
      txRepo = FakeTransactionRepository();
      txRepo.transactions = [txDay1, txDay2, txOther];
      cashRepo = FakeCashWalletRepository();
      cashRepo.cashTransactions = [cashDay];

      txVM = TransactionsViewModel(repository: txRepo);
      await txVM.loadAll();
      cashVM = CashWalletViewModel(repository: cashRepo);
      await cashVM.loadCashData();
    });

    testWidgets('renders top summary, net flow, and filtered transactions for date', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
            ChangeNotifierProvider<CashWalletViewModel>.value(value: cashVM),
          ],
          child: MaterialApp(
            home: DateTransactionsScreen(
              date: targetDate,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Summary Banner
      expect(find.text('Net Daily Flow'), findsOneWidget);
      // Inflow: 1200, Outflow: 450 + 150 = 600, Net = +600
      expect(find.text('+600.00 ETB'), findsOneWidget);
      expect(find.text('600.00 ETB'), findsOneWidget); // Expense total
      expect(find.text('1,200.00 ETB'), findsOneWidget); // Income total
      expect(find.text('3 Total Transactions'), findsOneWidget);

      // Verify Transactions are rendered
      expect(find.text('Supermarket'), findsOneWidget);
      expect(find.text('Employer Inc'), findsOneWidget);
      expect(find.text('Taxi Fare'), findsOneWidget);
      expect(find.text('Coffee Shop'), findsNothing); // Different date

      // Verify Search Bar and Filtering
      await tester.tap(find.byIcon(Icons.search_rounded).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Supermarket');
      await tester.pumpAndSettle();

      // One in the search input, one in the filtered list item
      expect(find.text('Supermarket'), findsNWidgets(2));
      expect(find.text('Employer Inc'), findsNothing);
      expect(find.text('Taxi Fare'), findsNothing);
    });
  });

  group('Category Analysis Badge & AnimatedReasonsIcon Tests', () {
    testWidgets('AnimatedReasonsIcon paints and updates on tick', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedReasonsIcon(size: 20),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedReasonsIcon), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify animation ticks smoothly without throwing
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnalysisScreen renders Category Analysis badge with #2A2D34 and animated reasons icon', (tester) async {
      final fakeSettings = FakeSettingsRepository();
      final fakeTxRepo = FakeTransactionRepository();
      final fakeCashRepo = FakeCashWalletRepository();

      final settingsVM = SettingsViewModel(repository: fakeSettings);
      final txVM = TransactionsViewModel(repository: fakeTxRepo);
      final cashVM = CashWalletViewModel(repository: fakeCashRepo);
      final analyticsVM = AnalyticsViewModel();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settingsVM),
            ChangeNotifierProvider.value(value: txVM),
            ChangeNotifierProvider.value(value: cashVM),
            ChangeNotifierProvider.value(value: analyticsVM),
          ],
          child: const MaterialApp(
            home: AnalysisScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Category Analysis badge is present
      expect(find.text('CATEGORY ANALYSIS'), findsOneWidget);
      // Verify AnimatedReasonsIcon is present on the badge
      expect(find.byType(AnimatedReasonsIcon), findsOneWidget);
      // Verify the removed rightmost circular icon is NOT present
      expect(find.byIcon(Icons.pie_chart_outline_rounded), findsNothing);

      // Verify the badge container has AppColors.categoryBadgeBg (0xFF2A2D34)
      final badgeContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('CATEGORY ANALYSIS'),
          matching: find.byType(Container),
        ).first,
      );
      final badgeDecoration = badgeContainer.decoration as BoxDecoration;
      expect(badgeDecoration.color, equals(AppColors.categoryBadgeBg));
      expect(badgeDecoration.color, equals(const Color(0xFF2A2D34)));
      // Verify Category Analysis badge has NO drop shadow
      expect(badgeDecoration.boxShadow, isNull);
    });
  });
}

