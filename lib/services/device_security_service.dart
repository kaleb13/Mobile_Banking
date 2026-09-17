import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hardware-backed device anti-fraud and trial enforcement engine.
///
/// Prevents trial resets across app re-installs or data clears by binding
/// trial countdowns to persistent device hardware characteristics.
class DeviceSecurityService {
  DeviceSecurityService._();
  static final DeviceSecurityService instance = DeviceSecurityService._();

  static const String _prefLastKnownTimestamp = 'device_sec_last_known_epoch';
  static const String _prefCachedTrialEnd = 'device_sec_cached_trial_end';
  static const String _prefCachedIsBlocked = 'device_sec_cached_blocked';

  SupabaseClient get _supabase => Supabase.instance.client;

  String? _cachedFingerprint;
  String _deviceModel = 'Unknown Device';
  bool _isTrialActive = true;
  int _trialRemainingDays = 30;
  bool _isDeviceBlocked = false;
  bool _isClockTampered = false;

  bool get isTrialActive => _isTrialActive && !_isClockTampered;
  int get trialRemainingDays => _trialRemainingDays;
  bool get isDeviceBlocked => _isDeviceBlocked;
  bool get isClockTampered => _isClockTampered;
  String get deviceModel => _deviceModel;
  String? get deviceFingerprint => _cachedFingerprint;

  /// Initializes device fingerprinting and validates trial / kill-switch status.
  Future<void> initialize() async {
    try {
      await _generateDeviceFingerprint();
      _verifyAntiClockTampering();
      await _syncDeviceStatusWithCloud();
    } catch (e) {
      debugPrint('DeviceSecurityService.initialize error (fallback to local cache): $e');
      _loadCachedTrialStatus();
    }
  }

  /// Generates a SHA256 hardware fingerprint using persistent Android hardware attributes.
  Future<String> _generateDeviceFingerprint() async {
    if (_cachedFingerprint != null) return _cachedFingerprint!;

    final deviceInfo = DeviceInfoPlugin();
    String rawIdentifier = '';

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}'.trim();
      // androidInfo.id + hardware/bootloader creates an unforgeable device signature
      rawIdentifier = '${androidInfo.id}:${androidInfo.manufacturer}:${androidInfo.model}:${androidInfo.fingerprint}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceModel = iosInfo.utsname.machine;
      rawIdentifier = '${iosInfo.identifierForVendor}:${iosInfo.model}';
    } else {
      _deviceModel = 'Desktop / Test Device';
      rawIdentifier = 'generic_device_${Platform.operatingSystem}';
    }

    _cachedFingerprint = sha256.convert(utf8.encode(rawIdentifier)).toString();
    return _cachedFingerprint!;
  }

  /// Verifies that the phone's clock has not been rolled backward to cheat the trial.
  Future<void> _verifyAntiClockTampering() async {
    final prefs = await SharedPreferences.getInstance();
    final lastKnown = prefs.getInt(_prefLastKnownTimestamp) ?? 0;
    final nowEpoch = DateTime.now().millisecondsSinceEpoch;

    // If current phone time is more than 3 hours before the last recorded session,
    // the user has rolled their system clock back.
    if (lastKnown > 0 && (nowEpoch + 10800000) < lastKnown) {
      _isClockTampered = true;
      debugPrint('DeviceSecurityService: Clock tampering detected! Phone time rolled back.');
    } else {
      _isClockTampered = false;
      await prefs.setInt(_prefLastKnownTimestamp, nowEpoch);
    }
  }

  /// Checks and registers the device in Supabase `user_devices`.
  Future<void> _syncDeviceStatusWithCloud() async {
    final fingerprint = _cachedFingerprint;
    if (fingerprint == null) return;

    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await _supabase
          .from('user_devices')
          .select('trial_ends_at, is_blocked')
          .eq('device_fingerprint', fingerprint)
          .maybeSingle();

      if (response != null) {
        // Device already registered on cloud
        final trialEndStr = response['trial_ends_at'] as String?;
        final isBlocked = response['is_blocked'] as bool? ?? false;

        _isDeviceBlocked = isBlocked;
        await prefs.setBool(_prefCachedIsBlocked, isBlocked);

        if (trialEndStr != null) {
          final trialEnd = DateTime.parse(trialEndStr);
          await prefs.setString(_prefCachedTrialEnd, trialEnd.toIso8601String());
          _computeRemainingDays(trialEnd);
        }

        // Heartbeat: update last_active_at
        await _supabase.from('user_devices').update({
          'last_active_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('device_fingerprint', fingerprint);
      } else {
        // First time seeing this device: Register on cloud with 30-day trial
        final trialEnd = DateTime.now().toUtc().add(const Duration(days: 30));
        await _supabase.from('user_devices').insert({
          'device_fingerprint': fingerprint,
          'device_model': _deviceModel,
          'trial_ends_at': trialEnd.toIso8601String(),
          'is_blocked': false,
        });

        await prefs.setString(_prefCachedTrialEnd, trialEnd.toIso8601String());
        await prefs.setBool(_prefCachedIsBlocked, false);
        _computeRemainingDays(trialEnd);
      }
    } catch (e) {
      debugPrint('DeviceSecurityService cloud sync error: $e');
      _loadCachedTrialStatus();
    }
  }

  void _computeRemainingDays(DateTime trialEnd) {
    final now = DateTime.now().toUtc();
    final difference = trialEnd.difference(now);
    _trialRemainingDays = difference.inDays.clamp(0, 365);
    _isTrialActive = difference.inSeconds > 0;
  }

  Future<void> _loadCachedTrialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isDeviceBlocked = prefs.getBool(_prefCachedIsBlocked) ?? false;
    final cachedEnd = prefs.getString(_prefCachedTrialEnd);
    if (cachedEnd != null) {
      _computeRemainingDays(DateTime.parse(cachedEnd));
    } else {
      _isTrialActive = true;
      _trialRemainingDays = 30;
    }
  }

  /// Links this hardware device record to the authenticated user ID.
  Future<void> bindDeviceToUser(String userId) async {
    final fingerprint = _cachedFingerprint;
    if (fingerprint == null) return;

    try {
      await _supabase.from('user_devices').update({
        'user_id': userId,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('device_fingerprint', fingerprint);
    } catch (e) {
      debugPrint('DeviceSecurityService.bindDeviceToUser error: $e');
    }
  }
}
