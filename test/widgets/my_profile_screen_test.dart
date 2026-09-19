import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_banking_app/theme/app_theme.dart';
import 'package:mobile_banking_app/screens/dashboard/my_profile_screen.dart';
import 'package:mobile_banking_app/presentation/viewmodels/auth_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/analytics_view_model.dart';
import 'package:mobile_banking_app/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile_banking_app/data/repositories/transaction_repository.dart';
import 'package:mobile_banking_app/widgets/app_scroll_header_bar.dart';
import 'package:mobile_banking_app/widgets/app_back_button.dart';
import 'package:mobile_banking_app/models/stored_account.dart';
import 'package:mobile_banking_app/models/account_device_session.dart';

class MockTransactionRepository implements TransactionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthViewModel extends AuthViewModel {
  final bool _fakeAuth;
  final String? _fakeName;
  final String? _fakeEmail;
  final List<StoredAccount> _fakeAccounts;
  final List<AccountDeviceSession> _fakeDevices;
  final String _fakePlan;

  FakeAuthViewModel({
    bool isAuthenticated = false,
    String? displayName,
    String? email,
    List<StoredAccount> accounts = const [],
    List<AccountDeviceSession> devices = const [],
    String plan = 'free',
  })  : _fakeAuth = isAuthenticated,
        _fakeName = displayName,
        _fakeEmail = email,
        _fakeAccounts = accounts,
        _fakeDevices = devices,
        _fakePlan = plan;

  @override
  List<AccountDeviceSession> get accountDevices => _fakeDevices;

  @override
  AccountDeviceSession? get currentDeviceSession {
    try {
      return _fakeDevices.firstWhere((d) => d.isCurrentDevice);
    } catch (_) {
      return null;
    }
  }

  @override
  List<AccountDeviceSession> get otherActiveDevices =>
      _fakeDevices.where((d) => !d.isCurrentDevice && !d.isInactive).toList();

  @override
  List<AccountDeviceSession> get inactiveDevices =>
      _fakeDevices.where((d) => d.isInactive).toList();

  @override
  Future<void> loadAccountDevices() async {}

  @override
  bool get isAuthenticated => _fakeAuth;

  @override
  String? get displayName => _fakeName;

  @override
  String? get email => _fakeEmail;

  @override
  List<StoredAccount> get storedAccounts => _fakeAccounts;

  @override
  StoredAccount? get activeAccount =>
      _fakeAccounts.isNotEmpty ? _fakeAccounts.first : null;

  @override
  String get plan => _fakePlan;

  @override
  bool get isPro => _fakePlan == 'pro' || _fakePlan == 'premium';

  @override
  String get planDisplayName => isPro
      ? (_fakePlan == 'premium' ? 'Shibre Premium' : 'Shibre Pro')
      : 'Free Plan';
}

void main() {
  testWidgets('MyProfileScreen renders guest top section with sign in button and no bottom sign out', (tester) async {
    final authVM = FakeAuthViewModel(isAuthenticated: false);
    final analyticsVM = AnalyticsViewModel();
    final txVM = TransactionsViewModel(repository: MockTransactionRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authVM),
          ChangeNotifierProvider<AnalyticsViewModel>.value(value: analyticsVM),
          ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MyProfileScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify AppScrollHeaderBar exists with title 'Guest Profile' and back button
    expect(find.byType(AppScrollHeaderBar), findsOneWidget);
    expect(find.byType(AppBackButton), findsOneWidget);
    expect(find.text('Guest Profile'), findsWidgets);

    // Verify presence of offline vault badge and sign in button for unauthenticated state
    expect(find.text('OFFLINE VAULT'), findsOneWidget);
    expect(find.text('Sign In with Google'), findsOneWidget);
    expect(find.text('Offline Vault Storage'), findsOneWidget);

    // Verify SMS count badge and description
    expect(find.text('0 SMS LINKED'), findsOneWidget);
    expect(
      find.textContaining('0 banking SMS transactions are linked'),
      findsOneWidget,
    );

    // Verify there is no 'Sign Out' button at the bottom of the page
    expect(find.text('Sign Out'), findsNothing);
  });

  testWidgets('MyProfileScreen renders authenticated top section with Sign Out Account and green ACTIVE badge', (tester) async {
    final account = StoredAccount(
      userId: 'user-123',
      email: 'test@example.com',
      displayName: 'Kaleb Tester',
      lastActiveAt: DateTime.now(),
      isActive: true,
    );
    final authVM = FakeAuthViewModel(
      isAuthenticated: true,
      displayName: 'Kaleb Tester',
      email: 'test@example.com',
      accounts: [account],
    );
    final analyticsVM = AnalyticsViewModel();
    final txVM = TransactionsViewModel(repository: MockTransactionRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authVM),
          ChangeNotifierProvider<AnalyticsViewModel>.value(value: analyticsVM),
          ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MyProfileScreen(),
        ),
      ),
    );

    await tester.pump();

    // Top section user info (in scroll header bar, hero section, and connected accounts card)
    expect(find.text('Kaleb Tester'), findsWidgets);
    expect(find.text('CLOUD SYNC ACTIVE'), findsOneWidget);
    expect(find.text('Sign Out Account'), findsOneWidget);

    // Connected Accounts section with green ACTIVE badge and Add Another Account button
    expect(find.text('CONNECTED ACCOUNTS'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Add Another Account'), findsOneWidget);
  });

  testWidgets('MyProfileScreen renders SHIBRE PRO badge for pro accounts', (tester) async {
    final account = StoredAccount(
      userId: 'user-pro-123',
      email: 'pro@example.com',
      displayName: 'Pro Member',
      plan: 'pro',
      lastActiveAt: DateTime.now(),
      isActive: true,
    );
    final authVM = FakeAuthViewModel(
      isAuthenticated: true,
      displayName: 'Pro Member',
      email: 'pro@example.com',
      accounts: [account],
      plan: 'pro',
    );
    final analyticsVM = AnalyticsViewModel();
    final txVM = TransactionsViewModel(repository: MockTransactionRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authVM),
          ChangeNotifierProvider<AnalyticsViewModel>.value(value: analyticsVM),
          ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MyProfileScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify presence of SHIBRE PRO badge in hero section
    expect(find.text('SHIBRE PRO'), findsOneWidget);
    expect(find.text('CLOUD SYNC ACTIVE'), findsOneWidget);
  });

  testWidgets('MyProfileScreen renders Logged-in Devices card with current and remote sessions', (tester) async {
    final account = StoredAccount(
      userId: 'user-sessions-123',
      email: 'sessions@example.com',
      displayName: 'Active User',
      lastActiveAt: DateTime.now(),
      isActive: true,
    );

    final currentDevice = AccountDeviceSession(
      deviceFingerprint: 'current_fp_1',
      userId: 'user-sessions-123',
      deviceModel: 'Samsung Galaxy S22 Ultra',
      platform: 'Android',
      isActive: true,
      isCurrentDevice: true,
      lastUsedAt: DateTime.now().toUtc(),
    );

    final remoteActiveDevice = AccountDeviceSession(
      deviceFingerprint: 'remote_fp_2',
      userId: 'user-sessions-123',
      deviceModel: 'Pixel 8 Pro',
      platform: 'Android',
      isActive: true,
      isCurrentDevice: false,
      lastUsedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
    );

    final remoteInactiveDevice = AccountDeviceSession(
      deviceFingerprint: 'remote_fp_3',
      userId: 'user-sessions-123',
      deviceModel: 'iPad Air',
      platform: 'iOS',
      isActive: false,
      isCurrentDevice: false,
      lastUsedAt: DateTime.now().toUtc().subtract(const Duration(days: 40)),
    );

    final authVM = FakeAuthViewModel(
      isAuthenticated: true,
      displayName: 'Active User',
      email: 'sessions@example.com',
      accounts: [account],
      devices: [currentDevice, remoteActiveDevice, remoteInactiveDevice],
    );
    final analyticsVM = AnalyticsViewModel();
    final txVM = TransactionsViewModel(repository: MockTransactionRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authVM),
          ChangeNotifierProvider<AnalyticsViewModel>.value(value: analyticsVM),
          ChangeNotifierProvider<TransactionsViewModel>.value(value: txVM),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const MyProfileScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify Logged-In Devices section header
    expect(find.text('LOGGED-IN DEVICES'), findsOneWidget);
    expect(find.text('2 ACTIVE'), findsOneWidget);

    // Verify Current Device tile
    expect(find.text('Samsung Galaxy S22 Ultra'), findsOneWidget);
    expect(find.text('THIS DEVICE'), findsOneWidget);

    // Verify Other Active Sessions
    expect(find.text('OTHER ACTIVE SESSIONS'), findsOneWidget);
    expect(find.text('Pixel 8 Pro'), findsOneWidget);

    // Verify Inactive Sessions
    expect(find.text('INACTIVE SESSIONS'), findsOneWidget);
    expect(find.text('iPad Air'), findsOneWidget);
    expect(find.text('INACTIVE'), findsOneWidget);

    // Verify Terminate All Other Sessions button
    expect(find.text('Terminate All Other Sessions'), findsOneWidget);
  });
}

