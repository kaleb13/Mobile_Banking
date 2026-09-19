import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/stored_account.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/device_security_service.dart';
import '../../services/app_session_coordinator.dart';
import '../../models/account_device_session.dart';

/// ViewModel managing user authentication state, multi-account switching,
/// Google profile details, and device trial enforcement.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final DeviceSecurityService _securityService = DeviceSecurityService.instance;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  /// Hook fired whenever active account switches or an account is added/removed,
  /// so UI viewmodels (transactions, wallets, loans, etc.) can reload.
  FutureOr<void> Function()? onAccountSwitched;

  AuthViewModel() {
    _init();
  }

  void _init() {
    _authSubscription = _authService.onAuthStateChange.listen((data) {
      notifyListeners();
    });
    _authService.accountsNotifier.addListener(_onAccountsChanged);
  }

  void _onAccountsChanged() {
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _authService.isAuthenticated;
  User? get user => _authService.currentUser;
  User? get currentUser => _authService.currentUser;
  String? get avatarUrl => _authService.avatarUrl;
  String? get displayName => _authService.displayName;
  String? get email => _authService.email;

  List<StoredAccount> get storedAccounts => _authService.storedAccounts;
  StoredAccount? get activeAccount => _authService.activeAccount;
  bool get hasMultipleAccounts => _authService.storedAccounts.length > 1;

  String get plan => _authService.plan;
  bool get isPro => _authService.isPro;
  DateTime? get proUntil => _authService.proUntil;
  String get planDisplayName => isPro
      ? (plan == 'premium' ? 'Shibre Premium' : 'Shibre Pro')
      : 'Free Plan';

  bool get isTrialActive => _securityService.isTrialActive;
  int get trialRemainingDays => _securityService.trialRemainingDays;
  bool get isDeviceBlocked => _securityService.isDeviceBlocked;
  bool get isClockTampered => _securityService.isClockTampered;
  String get deviceModel => _securityService.deviceModel;

  List<AccountDeviceSession> _accountDevices = [];
  bool _isLoadingDevices = false;

  List<AccountDeviceSession> get accountDevices =>
      List.unmodifiable(_accountDevices);
  bool get isLoadingDevices => _isLoadingDevices;

  AccountDeviceSession? get currentDeviceSession {
    try {
      return _accountDevices.firstWhere((d) => d.isCurrentDevice);
    } catch (_) {
      return null;
    }
  }

  List<AccountDeviceSession> get otherActiveDevices =>
      _accountDevices.where((d) => !d.isCurrentDevice && !d.isInactive).toList();

  List<AccountDeviceSession> get inactiveDevices =>
      _accountDevices.where((d) => d.isInactive).toList();

  /// Loads logged-in device sessions for the active account from Supabase.
  Future<void> loadAccountDevices() async {
    final uid = activeAccount?.userId ?? currentUser?.id;
    if (uid == null) {
      _accountDevices = [];
      notifyListeners();
      return;
    }

    _isLoadingDevices = true;
    notifyListeners();

    try {
      _accountDevices = await _securityService.fetchAccountDevices(uid);
    } catch (e) {
      debugPrint('AuthViewModel.loadAccountDevices error: $e');
    } finally {
      _isLoadingDevices = false;
      notifyListeners();
    }
  }

  /// Terminates a specific remote device session for the active account.
  Future<bool> terminateDeviceSession(String targetFingerprint) async {
    final uid = activeAccount?.userId ?? currentUser?.id;
    if (uid == null) return false;

    final success =
        await _securityService.terminateDeviceSession(uid, targetFingerprint);
    if (success) {
      _accountDevices.removeWhere(
          (d) => d.deviceFingerprint == targetFingerprint);
      notifyListeners();
    }
    return success;
  }

  /// Terminates all other device sessions for the active account.
  Future<bool> terminateAllOtherSessions() async {
    final uid = activeAccount?.userId ?? currentUser?.id;
    if (uid == null) return false;

    final success = await _securityService.terminateAllOtherSessions(uid);
    if (success) {
      _accountDevices.removeWhere((d) => !d.isCurrentDevice);
      notifyListeners();
    }
    return success;
  }

  /// Sets loading state manually if needed.
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Refreshes device trial countdown and hardware security status.
  Future<void> refreshSecurityStatus() async {
    await _securityService.initialize();
    notifyListeners();
  }

  /// Refreshes server-authoritative subscription status from Supabase.
  Future<void> syncSubscription() async {
    await _authService.syncSubscription();
    notifyListeners();
  }

  /// Triggers native Google Sign-In and authenticates with Supabase.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        if (onAccountSwitched != null) {
          await onAccountSwitched!();
        }
        unawaited(CloudSyncService.instance.syncAll());
        unawaited(loadAccountDevices());
      }
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Adds an additional account on this device using Google Sign-In account chooser.
  Future<bool> addAccount() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle(isAddingNewAccount: true);
      if (user != null) {
        if (onAccountSwitched != null) {
          await onAccountSwitched!();
        }
        unawaited(CloudSyncService.instance.syncAll());
        unawaited(loadAccountDevices());
      }
      _isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('AuthViewModel.addAccount error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Switches active account to [userId], isolates SQLite DB, and reconnects sync.
  Future<bool> switchAccount(String userId, {bool? syncDeviceSms}) async {
    if (activeAccount?.userId == userId) return true;

    _isLoading = true;
    notifyListeners();

    try {
      final success = await AppSessionCoordinator.instance.switchAccount(
        userId,
        syncDeviceSms: syncDeviceSms,
      );
      if (success && onAccountSwitched != null) {
        await onAccountSwitched!();
      }
      unawaited(loadAccountDevices());
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      debugPrint('AuthViewModel.switchAccount error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Updates the device SMS sync mode for the active account and persists it.
  Future<void> updateActiveAccountSyncDeviceSms(bool enabled) async {
    await _authService.updateActiveAccountSyncDeviceSms(enabled);
    notifyListeners();
  }

  /// Removes an account from this device.
  Future<void> removeAccount(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.removeAccount(userId);
      if (onAccountSwitched != null) {
        await onAccountSwitched!();
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('AuthViewModel.removeAccount error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs out of the current active session or all accounts.
  Future<void> signOut({bool all = false}) async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut(all: all);
    if (onAccountSwitched != null) {
      await onAccountSwitched!();
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authService.accountsNotifier.removeListener(_onAccountsChanged);
    super.dispose();
  }
}
