import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'screens/shell/main_shell.dart';
import 'screens/intro/onboarding_screen.dart';
import 'screens/privacy/app_lock_screen.dart';
import 'services/pin_service.dart';
import 'screens/dashboard/quick_edit_overlay.dart';

import 'data/repositories/notification_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/loan_repository.dart';
import 'data/repositories/savings_repository.dart';
import 'data/repositories/cash_wallet_repository.dart';
import 'data/repositories/transaction_repository.dart';
import 'presentation/viewmodels/notifications_view_model.dart';
import 'presentation/viewmodels/settings_view_model.dart';
import 'presentation/viewmodels/loans_view_model.dart';
import 'presentation/viewmodels/savings_view_model.dart';
import 'presentation/viewmodels/cash_wallet_view_model.dart';
import 'presentation/viewmodels/transactions_view_model.dart';
import 'presentation/viewmodels/analytics_view_model.dart';

/// Global navigator key — allows non-widget code to push routes or show
/// modals without needing a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'appNavigatorKey');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SMS handling is now done natively by SmsBroadcastReceiver.kt —
  // no Dart-side background service startup needed.

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final notificationRepo = NotificationRepositoryImpl();
  final settingsRepo = SettingsRepositoryImpl();
  final loanRepo = LoanRepositoryImpl();
  final savingsRepo = SavingsRepositoryImpl();
  final cashWalletRepo = CashWalletRepositoryImpl();
  final transactionRepo = TransactionRepositoryImpl();

  // Pre-load onboarding & theme from SettingsRepository to prevent first-frame UI flash
  final bool initialOnboardingDone = await settingsRepo.getIsOnboardingComplete();
  final AppThemeMode initialThemeMode = await settingsRepo.getThemeMode();

  runApp(
    MultiProvider(
      providers: [
        Provider<NotificationRepository>.value(value: notificationRepo),
        Provider<SettingsRepository>.value(value: settingsRepo),
        Provider<LoanRepository>.value(value: loanRepo),
        Provider<SavingsRepository>.value(value: savingsRepo),
        Provider<CashWalletRepository>.value(value: cashWalletRepo),
        Provider<TransactionRepository>.value(value: transactionRepo),
        ChangeNotifierProvider(
          create: (_) => NotificationsViewModel(repository: notificationRepo)
            ..loadNotifications(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsViewModel(
            repository: settingsRepo,
            initialOnboardingComplete: initialOnboardingDone,
            initialThemeMode: initialThemeMode,
          )..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => SavingsViewModel(repository: savingsRepo)
            ..fetchSavingGoals(),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final txVM = TransactionsViewModel(repository: transactionRepo)
              ..loadAll()
              ..initEventListener();
            return txVM;
          },
        ),
        ChangeNotifierProxyProvider<TransactionsViewModel, CashWalletViewModel>(
          create: (_) => CashWalletViewModel(repository: cashWalletRepo)
            ..loadCashData(),
          update: (context, txVM, cashVM) {
            final vm = cashVM ?? CashWalletViewModel(repository: cashWalletRepo);
            vm.getTransactions = () => txVM.allTransactionsUnfiltered;
            vm.recalcBalance(notify: false);
            return vm;
          },
        ),
        ChangeNotifierProxyProvider2<TransactionsViewModel, NotificationsViewModel, LoansViewModel>(
          create: (_) => LoansViewModel(
            repository: loanRepo,
          )..loadLoans(),
          update: (context, txVM, notifsVM, loansVM) {
            final vm = loansVM ?? LoansViewModel(repository: loanRepo);
            vm.getTransactions = () => txVM.allTransactionsUnfiltered;
            vm.getSenders = () => txVM.senders;
            vm.getReasons = () => txVM.reasons;
            vm.updateTransactionReason = (
              String txId, {
              int? reasonId,
              String? customReasonText,
            }) => txVM.updateTransactionReason(
              txId,
              reasonId: reasonId,
              customReasonText: customReasonText,
            );
            vm.addNotification = ({
              required String sender,
              required String body,
              required DateTime date,
            }) => notifsVM.addUnrecognizedNotification(
              sender: sender,
              body: body,
              date: date,
            );
            vm.removeLoanNotification = (candidateName, trackedName, txId) async {
              await notifsVM.removeNotificationsWhere((n) {
                final isLoanSender = n.sender.contains('Loan') || n.sender.contains('System');
                final hasMatch = (candidateName.isNotEmpty && n.body.contains(candidateName)) ||
                    (trackedName.isNotEmpty && n.body.contains(trackedName)) ||
                    n.body.contains('Loan Match');
                return isLoanSender && hasMatch;
              });
            };
            // Wire SMS event callback to also reload notifications
            txVM.onSmsEventReceived = () => notifsVM.loadNotifications();
            // Wire notification reconciliation callbacks
            notifsVM.getTransactions = () => txVM.allTransactionsUnfiltered;
            notifsVM.getReasons = () => txVM.reasons;
            notifsVM.updateTransactionReason = (txId, reason, reasonId) async {
              await txVM.updateTransactionReason(txId, reason: reason, reasonId: reasonId);
            };
            // Wire notification batch insert through the notification repo
            txVM.insertNotificationsBatch = (notifications) async {
              await notificationRepo.insertNotificationsBatch(notifications);
              await notifsVM.loadNotifications();
            };
            return vm;
          },
        ),
        ChangeNotifierProxyProvider3<TransactionsViewModel, CashWalletViewModel, LoansViewModel, AnalyticsViewModel>(
          create: (_) => AnalyticsViewModel(),
          update: (context, txVM, cashVM, loansVM, analyticsVM) {
            final vm = analyticsVM ?? AnalyticsViewModel();
            vm.getTransactions = () => txVM.transactions;
            vm.getCashTransactions = () => cashVM.cashTransactions;
            vm.getSenders = () => txVM.senders;
            vm.getTotalBalance = () => txVM.totalBalance;
            vm.getTotalBorrowedLiability = () => loansVM.totalBorrowedLiability;
            // Recalculate wallet balances, levels, and expense highlights
            vm.recalculate(
              pausedBanks: txVM.pausedBanks,
              getTopLevelCategory: txVM.getTopLevelCategoryForTransaction,
              isDateInMonthOf: (d, ref) => d.year == ref.year && d.month == ref.month,
            );
            return vm;
          },
        ),
      ],
      child: const MobileBankingApp(),
    ),
  );
}

class MobileBankingApp extends StatefulWidget {
  const MobileBankingApp({super.key});

  @override
  State<MobileBankingApp> createState() => _MobileBankingAppState();
}

class _MobileBankingAppState extends State<MobileBankingApp>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _checkedOnStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        context.read<TransactionsViewModel>().reconcileOnResume();
        context.read<NotificationsViewModel>().loadNotifications();
      } catch (_) {}
    }
  }

  Future<void> _checkInitialLock() async {
    final locked = await PinService.instance.isLockEnabled();
    if (mounted) {
      setState(() {
        _isLocked = locked;
        _checkedOnStart = true;
      });
    }
  }

  void _unlock() {
    setState(() => _isLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsViewModel, ({AppThemeMode themeMode, bool isOnboardingComplete})>(
      selector: (_, vm) => (themeMode: vm.currentThemeMode, isOnboardingComplete: vm.isOnboardingComplete),
      builder: (context, data, child) {
        return MaterialApp(
          title: 'Shibre',
          theme: AppTheme.themeFor(data.themeMode),
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          home: !_checkedOnStart
              ? Scaffold(backgroundColor: AppColors.background)
              : _isLocked
                  ? AppLockScreen(onUnlocked: _unlock)
                  : !data.isOnboardingComplete
                      ? const OnboardingScreen()
                      : const MainShell(),
        );
      },
    );
  }
}

// ─── Quick Edit Overlay Entry Point ──────────────────────────────────────────
// Separate Dart entry point for TransactionQuickEditActivity.
// Must live in main.dart so the AOT compiler includes it in the release snapshot.
// The @pragma prevents tree-shaking since nothing in main() calls this.

@pragma('vm:entry-point')
void quickEditMain() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const QuickEditOverlay(),
    ),
  );
}

