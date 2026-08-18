import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/models/app_notification.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Batch Ignore Notifications Hashing & Filter Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('hashes notification body and verifies blocklist filtering', () async {
      final prefs = await SharedPreferences.getInstance();

      final notif1 = AppNotification(
        id: 'n1',
        sender: 'Telebirr',
        body: 'You have successfully activated telebirr Saving Service. \nThank you for using telebirr\nEthio telecom',
        date: DateTime.now(),
      );

      final notif2 = AppNotification(
        id: 'n2',
        sender: 'CBE',
        body: 'Your CBE daily transaction limit was increased.',
        date: DateTime.now(),
      );

      final ignored = <String>[];

      // Simulate batch ignore
      for (final n in [notif1, notif2]) {
        ignored.add(n.id);
        final bodyNormalised = n.body.replaceAll(RegExp(r'\s+'), ' ').trim();
        final bodyHash =
            sha256.convert(utf8.encode(bodyNormalised)).toString();
        ignored.add(bodyHash);
      }

      await prefs.setStringList('ignored_notification_ids', ignored);

      final storedIgnored = prefs.getStringList('ignored_notification_ids') ?? [];

      // Test that incoming new SMS with identical normalized body is recognized as blocked
      const incomingRawSms =
          'You have successfully activated telebirr Saving Service.   \nThank you for using telebirr \nEthio telecom';
      final incomingNorm =
          incomingRawSms.replaceAll(RegExp(r'\s+'), ' ').trim();
      final incomingHash =
          sha256.convert(utf8.encode(incomingNorm)).toString();

      expect(storedIgnored.contains(incomingHash), isTrue);
    });
  });
}
