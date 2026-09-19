import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/account_device_session.dart';

void main() {
  group('AccountDeviceSession Domain Model Tests', () {
    test('identifies current device as online with Active now formatted string', () {
      final session = AccountDeviceSession(
        deviceFingerprint: 'fp_current_123',
        userId: 'user_test',
        deviceModel: 'Samsung Galaxy S22',
        platform: 'Android',
        isActive: true,
        isCurrentDevice: true,
        lastUsedAt: DateTime.now().toUtc(),
      );

      expect(session.isCurrentDevice, isTrue);
      expect(session.isOnline, isTrue);
      expect(session.isInactive, isFalse);
      expect(session.formattedLastSeen, 'Active now');
    });

    test('classifies recent session as online and not inactive', () {
      final session = AccountDeviceSession(
        deviceFingerprint: 'fp_remote_456',
        userId: 'user_test',
        deviceModel: 'Google Pixel 7 Pro',
        platform: 'Android',
        isActive: true,
        isCurrentDevice: false,
        lastUsedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
      );

      expect(session.isCurrentDevice, isFalse);
      expect(session.isOnline, isTrue);
      expect(session.isInactive, isFalse);
      expect(session.formattedLastSeen, 'Active just now');
    });

    test('classifies session older than 30 days as inactive', () {
      final session = AccountDeviceSession(
        deviceFingerprint: 'fp_old_789',
        userId: 'user_test',
        deviceModel: 'iPad Pro',
        platform: 'iOS',
        isActive: true,
        isCurrentDevice: false,
        lastUsedAt: DateTime.now().toUtc().subtract(const Duration(days: 45)),
      );

      expect(session.isCurrentDevice, isFalse);
      expect(session.isOnline, isFalse);
      expect(session.isInactive, isTrue);
    });

    test('classifies session with isActive = false as inactive', () {
      final session = AccountDeviceSession(
        deviceFingerprint: 'fp_inactive_999',
        userId: 'user_test',
        deviceModel: 'Desktop / Windows',
        platform: 'Desktop',
        isActive: false,
        isCurrentDevice: false,
        lastUsedAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
      );

      expect(session.isInactive, isTrue);
      expect(session.formattedLastSeen, '3h ago');
    });

    test('fromMap parses fields accurately and detects current device fingerprint', () {
      final map = {
        'device_fingerprint': 'fp_match_111',
        'user_id': 'user_abc',
        'device_model': 'Xiaomi 13 Ultra',
        'platform': 'Android',
        'is_active': true,
        'last_used_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().subtract(const Duration(days: 10)).toIso8601String(),
      };

      final session = AccountDeviceSession.fromMap(
        map,
        currentFingerprint: 'fp_match_111',
      );

      expect(session.isCurrentDevice, isTrue);
      expect(session.deviceModel, 'Xiaomi 13 Ultra');
      expect(session.platform, 'Android');
      expect(session.userId, 'user_abc');
    });
  });
}
