import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/device_security_service.dart';

/// ViewModel managing user authentication state, Google profile details,
/// and device trial enforcement.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final DeviceSecurityService _securityService = DeviceSecurityService.instance;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isLoading = false;
  String? _errorMessage;

  AuthViewModel() {
    _init();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _authService.isAuthenticated;
  User? get user => _authService.currentUser;
  String? get avatarUrl => _authService.avatarUrl;
  String? get displayName => _authService.displayName;
  String? get email => _authService.email;

  bool get isTrialActive => _securityService.isTrialActive;
  int get trialRemainingDays => _securityService.trialRemainingDays;
  bool get isDeviceBlocked => _securityService.isDeviceBlocked;
  bool get isClockTampered => _securityService.isClockTampered;
  String get deviceModel => _securityService.deviceModel;

  void _init() {
    _authSubscription = _authService.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }

  /// Refreshes device trial countdown and hardware security status.
  Future<void> refreshSecurityStatus() async {
    await _securityService.initialize();
    notifyListeners();
  }

  /// Triggers native Google Sign-In and authenticates with Supabase.
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
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

  /// Signs out of the current Google / Supabase session.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    await _authService.signOut();
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
