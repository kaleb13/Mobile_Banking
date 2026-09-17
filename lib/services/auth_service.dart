import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'device_security_service.dart';

/// Centralized authentication service integrating Google Sign-In and Supabase Auth.
/// 
/// Supports optional guest access and seamless account link/unlink.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _supabase => Supabase.instance.client;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleWebClientId,
      );
      _initialized = true;
    }
  }

  User? get currentUser => _supabase.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  String? get avatarUrl {
    final meta = currentUser?.userMetadata;
    return meta?['avatar_url'] as String? ?? meta?['picture'] as String?;
  }

  String? get displayName {
    final meta = currentUser?.userMetadata;
    return meta?['full_name'] as String? ?? meta?['name'] as String? ?? currentUser?.email?.split('@').first;
  }

  String? get email => currentUser?.email;

  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  /// Signs in using native Google Sign-In and authenticates with Supabase.
  Future<User?> signInWithGoogle() async {
    try {
      await _ensureInitialized();
      final googleAccount = await GoogleSignIn.instance.authenticate();
      final idToken = googleAccount.authentication.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-In failed: missing ID Token.');
      }

      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = authResponse.user;
      if (user != null) {
        // 1. Sync profile to Supabase database
        await _syncUserProfile(user);

        // 2. Bind current physical device to the authenticated user
        await DeviceSecurityService.instance.bindDeviceToUser(user.id);
      }

      return user;
    } catch (e) {
      debugPrint('AuthService.signInWithGoogle error: $e');
      rethrow;
    }
  }

  /// Synchronizes authenticated user metadata to the `profiles` table.
  Future<void> _syncUserProfile(User user) async {
    try {
      final meta = user.userMetadata ?? {};
      final name = meta['full_name'] as String? ?? meta['name'] as String? ?? user.email?.split('@').first;
      final avatar = meta['avatar_url'] as String? ?? meta['picture'] as String?;

      await _supabase.from('profiles').upsert({
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

  /// Signs out of both Google and Supabase.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    try {
      await _supabase.auth.signOut();
    } catch (_) {}
  }
}
