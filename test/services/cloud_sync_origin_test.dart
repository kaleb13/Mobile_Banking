import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';
import 'package:mobile_banking_app/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Sync & Device Origin Provenance Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AppTransaction stores and serializes origin device metadata', () {
      final tx = AppTransaction(
        id: 'cbe_tx_12345',
        bankName: 'CBE',
        amount: 2500.0,
        type: 'income',
        date: DateTime.utc(2026, 9, 19, 10, 30),
        rawMessage: 'You have received 2,500 ETB from Abebe Bikila',
        isAutoDetected: true,
        originDeviceId: 'galaxy_fp_9876',
        originDeviceModel: 'SRT Galaxy',
        isRemoteSync: true,
      );

      expect(tx.originDeviceId, 'galaxy_fp_9876');
      expect(tx.originDeviceModel, 'SRT Galaxy');
      expect(tx.isRemoteSync, isTrue);
      expect(tx.isDownloadedReplica, isTrue);

      final map = tx.toMap();
      expect(map['originDeviceId'], 'galaxy_fp_9876');
      expect(map['originDeviceModel'], 'SRT Galaxy');
      expect(map['isRemoteSync'], 1);

      final restored = AppTransaction.fromMap(map);
      expect(restored.originDeviceId, 'galaxy_fp_9876');
      expect(restored.originDeviceModel, 'SRT Galaxy');
      expect(restored.isRemoteSync, isTrue);
    });

    test('AppTransaction.fromParsedResult stamps origin device if provided', () {
      final parsed = ParsedSmsResult(
        id: 'ahadu_ref_99',
        bankName: 'Ahadu Bank',
        amount: 150.0,
        type: 'expense',
        date: DateTime.utc(2026, 9, 19, 11, 0),
        counterparty: 'Ethio Telecom',
        totalBalance: 4500.0,
        rawMessage: 'Payment of 150 ETB to Ethio Telecom successful.',
      );

      final tx = AppTransaction.fromParsedResult(
        parsed,
        originDeviceId: 'tecno_fp_111',
        originDeviceModel: 'Tecno Camon 20',
        isRemoteSync: false,
      );

      expect(tx.originDeviceId, 'tecno_fp_111');
      expect(tx.originDeviceModel, 'Tecno Camon 20');
      expect(tx.isRemoteSync, isFalse);
      expect(tx.isDownloadedReplica, isFalse);
    });

    test('Purged device fingerprints persist in SharedPreferences', () async {
      final syncService = CloudSyncService.instance;

      var purged = await syncService.getPurgedDeviceFingerprints();
      expect(purged, isEmpty);

      // Simulate purging a device
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cloud_purged_device_fingerprints', ['galaxy_fp_9876']);

      purged = await syncService.getPurgedDeviceFingerprints();
      expect(purged.contains('galaxy_fp_9876'), isTrue);
    });
  });
}
