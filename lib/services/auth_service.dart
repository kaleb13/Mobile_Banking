import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/stored_account.dart';
import 'device_security_service.dart';
import 'database_service.dart';

/// Centralized authentication and multi-account service integrating Google Sign-In
/// and Supabase Auth with device binding and local data isolation.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _prefAccountsKey = 'shibre_multi_accounts_json';
  static const String _prefActiveAccountKey = 'shibre_active_account_id';

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool _initialized = false;
  List<StoredAccount> _accounts = [];
  String? _activeAccountId;
  RealtimeChannel? _subscriptionChannel;

  /// Stream controller for notifying listeners when accounts change or switch
  final ValueNotifier<List<StoredAccount>> accountsNotifier =
      ValueNotifier<List<StoredAccount>>([]);

  Future<void> _ensureGoogleInitialized() async {
    if (!_initialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
      _initialized = true;
    }
  }

  /// Initializes stored accounts, verifies active account, and configures database.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_prefAccountsKey);
      _activeAccountId = prefs.getString(_prefActiveAccountKey);

      if (accountsJson != null && accountsJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(accountsJson) as List<dynamic>;
          _accounts = decoded
              .map((item) => StoredAccount.fromMap(item as Map<String, dynamic>))
              .toList();
        } catch (e) {
          debugPrint('AuthService: Failed to parse stored accounts: $e');
        }
      }

      // Check if current Supabase session exists and is not yet in _accounts
      final currentSupabaseUser = _supabase?.auth.currentUser;
      if (currentSupabaseUser != null) {
        final existingIdx =
            _accounts.indexWhere((a) => a.userId == currentSupabaseUser.id);
        final meta = currentSupabaseUser.userMetadata ?? {};
        final name = meta['full_name'] as String? ??
            meta['name'] as String? ??
            currentSupabaseUser.email?.split('@').first ??
            'Shibre User';
        final avatar = meta['avatar_url'] as String? ?? meta['picture'] as String?;
        final currentToken = _supabase?.auth.currentSession?.refreshToken;

        if (existingIdx >= 0) {
          _accounts[existingIdx] = _accounts[existingIdx].copyWith(
            email: currentSupabaseUser.email ?? _accounts[existingIdx].email,
            displayName: name,
            avatarUrl: avatar ?? _accounts[existingIdx].avatarUrl,
            refreshToken: currentToken ?? _accounts[existingIdx].refreshToken,
            lastActiveAt: DateTime.now().toUtc(),
          );
        } else {
          _accounts.add(StoredAccount(
            userId: currentSupabaseUser.id,
            email: currentSupabaseUser.email ?? '',
            displayName: name,
            avatarUrl: avatar,
            refreshToken: currentToken,
            lastActiveAt: DateTime.now().toUtc(),
            isActive: true,
            hasConfiguredSmsMode: true,
          ));
        }
        _activeAccountId ??= currentSupabaseUser.id;
      }

      // Ensure active account consistency
      if (_activeAccountId == null && _accounts.isNotEmpty) {
        _activeAccountId = _accounts.first.userId;
      }

      // Synchronize native SMS listening preference for active account on this device
      if (_activeAccountId != null) {
        final activeAcc = activeAccount;
        if (activeAcc != null) {
          final sanitized = activeAcc.userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final deviceSmsPref = prefs.getBool('${sanitized}_is_sms_listening_enabled') ?? activeAcc.syncDeviceSms;
          await prefs.setBool('is_sms_listening_enabled', deviceSmsPref);
          await prefs.setBool('flutter.is_sms_listening_enabled', deviceSmsPref);
        }
      }

      _syncActiveFlag();
      await _persistAccounts();

      // 1. Listen and sync subscription status immediately (network independent of local DB)
      if (_activeAccountId != null) {
        _listenToSubscriptionChanges(_activeAccountId!);
        unawaited(syncSubscription(_activeAccountId));
      }

      // 2. Configure DatabaseService for the active account safely
      try {
        await DatabaseService.instance.switchUser(_activeAccountId);
      } catch (e) {
        debugPrint('AuthService: switchUser non-fatal init warning: $e');
      }
    } catch (e) {
      debugPrint('AuthService.initialize error: $e');
    }
  }

  void _syncActiveFlag() {
    _accounts = _accounts.map((a) {
      return a.copyWith(isActive: a.userId == _activeAccountId);
    }).toList();
    accountsNotifier.value = List.unmodifiable(_accounts);
  }

  Future<void> _persistAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_accounts.map((a) => a.toMap()).toList());
      await prefs.setString(_prefAccountsKey, encoded);
      if (_activeAccountId != null) {
        await prefs.setString(_prefActiveAccountKey, _activeAccountId!);
      } else {
        await prefs.remove(_prefActiveAccountKey);
      }
    } catch (e) {
      debugPrint('AuthService._persistAccounts error: $e');
    }
  }

  /// All accounts currently logged in on this device.
  List<StoredAccount> get storedAccounts => List.unmodifiable(_accounts);

  /// The currently active logged-in account.
  StoredAccount? get activeAccount {
    if (_activeAccountId == null) return null;
    try {
      return _accounts.firstWhere((a) => a.userId == _activeAccountId);
    } catch (_) {
      return _accounts.isNotEmpty ? _accounts.first : null;
    }
  }

  User? get currentUser => _supabase?.auth.currentUser;

  bool get isAuthenticated => currentUser != null || activeAccount != null;

  String? get avatarUrl => activeAccount?.avatarUrl;

  String? get displayName =>
      activeAccount?.displayName ??
      currentUser?.userMetadata?['full_name'] as String? ??
      currentUser?.email?.split('@').first;

  String? get email => activeAccount?.email ?? currentUser?.email;

  /// Active plan identity: 'free', 'pro', or 'premium'.
  String get plan => activeAccount?.plan ?? 'free';

  /// Whether the active account has an unexpired Pro or Premium plan.
  bool get isPro => activeAccount?.isPro ?? false;

  /// Expiration timestamp of the active subscription (null means lifetime if Pro).
  DateTime? get proUntil => activeAccount?.proUntil;

  Stream<AuthState> get onAuthStateChange =>
      _supabase?.auth.onAuthStateChange ?? const Stream.empty();

  /// Signs in using native Google Sign-In and authenticates with Supabase.
  /// If [isAddingNewAccount] is true, clears current Google Sign-In session first
  /// so that the user is prompted with the account picker.
  Future<User?> signInWithGoogle({bool isAddingNewAccount = false}) async {
    try {
      await _ensureGoogleInitialized();

      if (isAddingNewAccount) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {}
      }

      final googleAccount = await GoogleSignIn.instance.authenticate();
      final idToken = googleAccount.authentication.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: missing ID Token.');
      }

      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase is not initialized.');
      }

      final authResponse = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = authResponse.user;
      if (user != null) {
        final meta = user.userMetadata ?? {};
        final name = meta['full_name'] as String? ??
            meta['name'] as String? ??
            user.email?.split('@').first ??
            'Shibre User';
        final avatar = meta['avatar_url'] as String? ?? meta['picture'] as String?;
        final refreshToken = authResponse.session?.refreshToken;

        final existingIndex = _accounts.indexWhere((a) => a.userId == user.id);
        final prefs = await SharedPreferences.getInstance();
        final sanitized = user.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final bool isConfiguredOnDevice = prefs.getBool('${sanitized}_sms_mode_configured') ??
            (existingIndex >= 0 ? _accounts[existingIndex].hasConfiguredSmsMode : false);
        final bool deviceSmsPref = prefs.getBool('${sanitized}_is_sms_listening_enabled') ??
            (existingIndex >= 0 ? _accounts[existingIndex].syncDeviceSms : true);

        final newAccount = StoredAccount(
          userId: user.id,
          email: user.email ?? '',
          displayName: name,
          avatarUrl: avatar,
          refreshToken: refreshToken,
          lastActiveAt: DateTime.now().toUtc(),
          isActive: true,
          syncDeviceSms: deviceSmsPref,
          hasConfiguredSmsMode: isConfiguredOnDevice,
        );

        if (existingIndex >= 0) {
          _accounts[existingIndex] = newAccount;
        } else {
          _accounts.add(newAccount);
        }

        _activeAccountId = user.id;
        _syncActiveFlag();
        await _persistAccounts();

        // If this device has configured this account before, restore its native SMS listening state immediately
        if (isConfiguredOnDevice) {
          await prefs.setBool('${sanitized}_is_sms_listening_enabled', deviceSmsPref);
          await prefs.setBool('is_sms_listening_enabled', deviceSmsPref);
          await prefs.setBool('flutter.is_sms_listening_enabled', deviceSmsPref);
        }

        // 1. Sync profile to Supabase database
        await _syncUserProfile(user);

        // 2. Bind current physical device to the authenticated user
        await DeviceSecurityService.instance.bindDeviceToUser(user.id);
        await _syncDeviceAccount(
          user.id,
          email: user.email,
          displayName: name,
          avatarUrl: avatar,
          isActive: true,
        );

        // 3. Switch local database context to this user
        await DatabaseService.instance.switchUser(user.id);

        _listenToSubscriptionChanges(user.id);
        syncSubscription(user.id);
      }

      return user;
    } catch (e) {
      debugPrint('AuthService.signInWithGoogle error: $e');
      rethrow;
    }
  }

  /// Switches active user session to [userId] on this device.
  Future<bool> switchAccount(String userId, {bool? syncDeviceSms}) async {
    try {
      final index = _accounts.indexWhere((a) => a.userId == userId);
      if (index < 0) return false;

      var target = _accounts[index];
      if (syncDeviceSms != null) {
        target = target.copyWith(syncDeviceSms: syncDeviceSms);
        _accounts[index] = target;
      }
      final client = _supabase;

      // Restore Supabase session if refresh token exists
      if (client != null && target.refreshToken != null && target.refreshToken!.isNotEmpty) {
        try {
          final res = await client.auth.setSession(target.refreshToken!);
          if (res.session?.refreshToken != null) {
            _accounts[index] = target.copyWith(
              refreshToken: res.session!.refreshToken,
              lastActiveAt: DateTime.now().toUtc(),
            );
          }
        } catch (e) {
          debugPrint('AuthService.switchAccount setSession warning: $e');
        }
      }

      _activeAccountId = userId;
      _syncActiveFlag();
      await _persistAccounts();

      // Update native Android SharedPreferences so background SMS receiver obeys this account's preference
      try {
        final prefs = await SharedPreferences.getInstance();
        final sanitized = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final savedSmsPref = prefs.getBool('${sanitized}_is_sms_listening_enabled');
        final effectiveSyncSms = syncDeviceSms ?? savedSmsPref ?? target.syncDeviceSms;
        final bool isExplicitConfig = syncDeviceSms != null;
        target = target.copyWith(
          syncDeviceSms: effectiveSyncSms,
          hasConfiguredSmsMode: isExplicitConfig ? true : target.hasConfiguredSmsMode,
        );
        _accounts[index] = target;

        await prefs.setBool('${sanitized}_is_sms_listening_enabled', effectiveSyncSms);
        await prefs.setBool('is_sms_listening_enabled', effectiveSyncSms);
        await prefs.setBool('flutter.is_sms_listening_enabled', effectiveSyncSms);
      } catch (_) {}

      // Update active status in Supabase device_accounts
      await _syncDeviceAccount(
        target.userId,
        email: target.email,
        displayName: target.displayName,
        avatarUrl: target.avatarUrl,
        isActive: true,
      );

      // Switch local SQLite database file
      await DatabaseService.instance.switchUser(userId);

      _listenToSubscriptionChanges(userId);
      syncSubscription(userId);
      return true;
    } catch (e) {
      debugPrint('AuthService.switchAccount error: $e');
      return false;
    }
  }

  /// Updates the syncDeviceSms flag for the active account and persists it.
  Future<void> updateActiveAccountSyncDeviceSms(bool enabled) async {
    if (_activeAccountId == null) return;
    final index = _accounts.indexWhere((a) => a.userId == _activeAccountId);
    if (index >= 0) {
      _accounts[index] = _accounts[index].copyWith(
        syncDeviceSms: enabled,
        hasConfiguredSmsMode: true,
      );
      _syncActiveFlag();
      await _persistAccounts();
    }
  }

  /// Removes an account from this device.
  Future<void> removeAccount(String userId) async {
    try {
      _accounts.removeWhere((a) => a.userId == userId);

      if (_activeAccountId == userId) {
        if (_accounts.isNotEmpty) {
          await switchAccount(_accounts.first.userId);
        } else {
          _activeAccountId = null;
          await signOut();
          await DatabaseService.instance.switchUser(null);
        }
      } else {
        _syncActiveFlag();
        await _persistAccounts();
      }
    } catch (e) {
      debugPrint('AuthService.removeAccount error: $e');
    }
  }

  /// Synchronizes authenticated user metadata to the `profiles` table.
  Future<void> _syncUserProfile(User user) async {
    try {
      final client = _supabase;
      if (client == null) return;

      final meta = user.userMetadata ?? {};
      final name = meta['full_name'] as String? ??
          meta['name'] as String? ??
          user.email?.split('@').first;
      final avatar = meta['avatar_url'] as String? ?? meta['picture'] as String?;

      await client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'display_name': name,
        'avatar_url': avatar,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AuthService._syncUserProfile error (non-fatal): $e');
    }
  }

  /// Binds and updates device account association in Supabase `device_accounts`.
  Future<void> _syncDeviceAccount(
    String userId, {
    String? email,
    String? displayName,
    String? avatarUrl,
    bool isActive = true,
  }) async {
    try {
      final client = _supabase;
      final fingerprint = DeviceSecurityService.instance.deviceFingerprint;
      if (client == null || fingerprint == null) return;

      await client.from('device_accounts').upsert({
        'device_fingerprint': fingerprint,
        'user_id': userId,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_active': isActive,
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AuthService._syncDeviceAccount error (non-fatal): $e');
    }
  }

  /// Signs out of current active account or all accounts.
  Future<void> signOut({bool all = false}) async {
    if (all || _accounts.length <= 1) {
      _accounts.clear();
      _activeAccountId = null;
      _syncActiveFlag();
      await _persistAccounts();

      _subscriptionChannel?.unsubscribe();
      _subscriptionChannel = null;

      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      try {
        await _supabase?.auth.signOut();
      } catch (_) {}

      await DatabaseService.instance.switchUser(null);
    } else if (_activeAccountId != null) {
      await removeAccount(_activeAccountId!);
    }
  }

  /// Fetches and updates subscription details from the authoritative Supabase
  /// `user_subscriptions` table.
  Future<void> syncSubscription([String? targetUserId]) async {
    final client = _supabase;
    final currentUser = client?.auth.currentUser;
    final uid = targetUserId ?? _activeAccountId ?? currentUser?.id;
    if (client == null || uid == null) {
      debugPrint('[AuthService] syncSubscription skipped: client=$client, uid=$uid');
      return;
    }

    try {
      debugPrint('[AuthService] syncSubscription checking user_subscriptions for uid: $uid (email: ${currentUser?.email})');

      String plan = 'free';
      DateTime? proUntil;
      String status = 'active';

      final res = await client
          .from('user_subscriptions')
          .select('plan, status, valid_until')
          .eq('user_id', uid)
          .maybeSingle();

      debugPrint('[AuthService] Supabase user_subscriptions result for $uid: $res');

      if (res != null) {
        final rawPlan = (res['plan'] as String?)?.toLowerCase().trim() ?? 'free';
        final validUntilStr = res['valid_until'] as String?;
        proUntil =
            validUntilStr != null ? DateTime.tryParse(validUntilStr) : null;
        final rawStatus = (res['status'] as String?)?.toLowerCase().trim() ?? 'active';

        // Case-insensitive flexible matching (handles 'pro', 'Pro', 'PRO', 'premium', etc.)
        if (rawPlan.contains('pro')) {
          plan = 'pro';
        } else if (rawPlan.contains('premium')) {
          plan = 'premium';
        } else {
          plan = rawPlan;
        }

        status = rawStatus.isEmpty ? 'active' : rawStatus;
      }

      final isStatusActive = status == 'active';
      final effectivePlan = isStatusActive ? plan : 'free';

      final idx = _accounts.indexWhere((a) => a.userId == uid);
      if (idx >= 0) {
        _accounts[idx] = _accounts[idx].copyWith(
          plan: effectivePlan,
          proUntil: proUntil,
        );
      } else {
        // If account wasn't in local _accounts yet, add it so activeAccount is never null
        _accounts.add(StoredAccount(
          userId: uid,
          email: currentUser?.email ?? '',
          displayName: currentUser?.userMetadata?['full_name'] as String? ?? 'Shibre User',
          plan: effectivePlan,
          proUntil: proUntil,
          lastActiveAt: DateTime.now().toUtc(),
          isActive: true,
        ));
        _activeAccountId ??= uid;
      }
      _syncActiveFlag();
      accountsNotifier.value = List.unmodifiable(_accounts);
      await _persistAccounts();
      debugPrint('[AuthService] Subscription updated: plan=$effectivePlan, status=$status, isPro=${activeAccount?.isPro}');
    } catch (e) {
      debugPrint('AuthService.syncSubscription error: $e');
    }
  }

  /// Sets up Realtime subscription listener for active user's subscription changes
  /// on the authoritative `user_subscriptions` table.
  void _listenToSubscriptionChanges(String userId) {
    _subscriptionChannel?.unsubscribe();
    _subscriptionChannel = null;

    final client = _supabase;
    if (client == null) return;

    try {
      _subscriptionChannel = client
          .channel('public:user_subscriptions:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              syncSubscription(userId);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('AuthService._listenToSubscriptionChanges error: $e');
    }
  }
}
