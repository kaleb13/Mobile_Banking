import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudSyncProgress Model Tests', () {
    test('Calculates percent and fraction in cloud accurately', () {
      const progressZero = CloudSyncProgress(
        deviceTotal: 0,
        cloudCount: 0,
        pendingCount: 0,
      );
      expect(progressZero.percentInCloud, 100.0);
      expect(progressZero.fractionInCloud, 1.0);

      const progress80 = CloudSyncProgress(
        deviceTotal: 1000,
        cloudCount: 800,
        pendingCount: 200,
        failedCount: 0,
      );
      expect(progress80.percentInCloud, 80.0);
      expect(progress80.fractionInCloud, 0.8);
      expect(progress80.pendingCount, 200);

      const progress50 = CloudSyncProgress(
        deviceTotal: 200,
        cloudCount: 100,
        pendingCount: 100,
        failedCount: 50,
        failureMessage: 'Network connection dropped',
      );
      expect(progress50.percentInCloud, 50.0);
      expect(progress50.fractionInCloud, 0.5);
      expect(progress50.failedCount, 50);
      expect(progress50.failureMessage, 'Network connection dropped');
    });

    test('copyWith updates specified fields and preserves others', () {
      const initial = CloudSyncProgress(
        deviceTotal: 500,
        cloudCount: 300,
        pendingCount: 200,
        failedCount: 0,
      );

      final updated = initial.copyWith(
        cloudCount: 450,
        pendingCount: 50,
        failedCount: 10,
        disabledBankCount: 120,
        failureMessage: 'Timeout',
      );

      expect(updated.deviceTotal, 500);
      expect(updated.cloudCount, 450);
      expect(updated.pendingCount, 50);
      expect(updated.failedCount, 10);
      expect(updated.disabledBankCount, 120);
      expect(updated.failureMessage, 'Timeout');
    });
  });

  group('CloudSyncService Batch Error & Retry Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial progress notifier defaults to clean progress state', () {
      final service = CloudSyncService.instance;
      expect(service.progressNotifier.value.deviceTotal, 0);
      expect(service.progressNotifier.value.cloudCount, 0);
      expect(service.progressNotifier.value.pendingCount, 0);
      expect(service.failedUploadCount, 0);
      expect(service.failedUploadBatch, isEmpty);
    });

    test('retryFailedUploads returns false cleanly if no failed batch exists', () async {
      final service = CloudSyncService.instance;
      final result = await service.retryFailedUploads();
      expect(result, isFalse);
    });
  });
}
