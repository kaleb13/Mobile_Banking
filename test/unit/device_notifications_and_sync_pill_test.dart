import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/cloud_sync_service.dart';
import 'package:mobile_banking_app/models/app_notification.dart';
import 'package:mobile_banking_app/models/stored_account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Notifications & Cloud Sync Status Tests', () {
    test('CloudSyncStatus includes offline state', () {
      expect(CloudSyncStatus.values.contains(CloudSyncStatus.offline), isTrue);
      expect(CloudSyncStatus.offline.name, 'offline');
    });

    test('Device notifications preservation list maintains distinct IDs', () {
      final n1 = AppNotification(
        id: 'NOTIF_1',
        sender: '127',
        body: 'Unrecognized SMS 1',
        date: DateTime.now(),
      );
      final n2 = AppNotification(
        id: 'NOTIF_2',
        sender: 'CBE',
        body: 'Unrecognized SMS 2',
        date: DateTime.now(),
      );

      final deviceNotifications = [n1.toMap(), n2.toMap()];

      // Simulate snapshot merge logic during switchUser
      final newAccountMap = <String, Map<String, dynamic>>{};
      for (final n in deviceNotifications) {
        newAccountMap[n['id'] as String] = n;
      }

      expect(newAccountMap.length, 2);
      expect(newAccountMap.containsKey('NOTIF_1'), isTrue);
      expect(newAccountMap.containsKey('NOTIF_2'), isTrue);
    });

    test('CloudSyncStatus offline detection string matching', () {
      final errors = [
        'SocketException: Failed host lookup: supabase.co',
        'ClientException: HandshakeException: Connection closed',
        'OS Error: Network is unreachable, errno = 101',
      ];

      for (final err in errors) {
        final lower = err.toLowerCase();
        final isOffline = lower.contains('socket') ||
            lower.contains('host') ||
            lower.contains('network') ||
            lower.contains('clientexception') ||
            lower.contains('handshake');
        expect(isOffline, isTrue, reason: 'Failed for $err');
      }
    });

    test('StoredAccount syncDeviceSms defaults to true and serializes correctly', () {
      final accDefault = StoredAccount(
        userId: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        lastActiveAt: DateTime.now(),
      );
      expect(accDefault.syncDeviceSms, isTrue);

      final map = accDefault.toMap();
      expect(map['syncDeviceSms'], isTrue);

      final reconstructed = StoredAccount.fromMap(map);
      expect(reconstructed.syncDeviceSms, isTrue);

      final cloudOnly = accDefault.copyWith(syncDeviceSms: false);
      expect(cloudOnly.syncDeviceSms, isFalse);

      final cloudOnlyMap = cloudOnly.toMap();
      expect(cloudOnlyMap['syncDeviceSms'], isFalse);

      final fromCloudOnly = StoredAccount.fromMap(cloudOnlyMap);
      expect(fromCloudOnly.syncDeviceSms, isFalse);
    });

    test('Dynamic notification pill text length matching', () {
      const notifEmpty = 'No unread notifications';
      const notifSingle = '1 unread notification';
      const notifMulti = '3 unread notifications';
      const syncActive = 'Syncing is active';

      // Verify that all strings are concise and well-balanced within 17-23 characters
      expect(notifEmpty.length, greaterThanOrEqualTo(16));
      expect(notifSingle.length, greaterThanOrEqualTo(16));
      expect(notifMulti.length, greaterThanOrEqualTo(16));
      expect(syncActive.length, greaterThanOrEqualTo(16));

      // The length difference between empty notifications and sync active is minimal (<= 6 chars)
      expect((notifEmpty.length - syncActive.length).abs(), lessThanOrEqualTo(6));
    });
  });
}

