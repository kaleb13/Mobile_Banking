import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_banking_app/presentation/viewmodels/cloud_sync_view_model.dart';
import 'package:mobile_banking_app/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CloudSyncViewModel Tests', () {
    test('Initial state reflects service defaults', () {
      final vm = CloudSyncViewModel();
      expect(vm.isSyncEnabled, isFalse);
      expect(vm.isLoadingDetails, isFalse);
      expect(vm.isRetryingBatch, isFalse);
      expect(vm.showAdvancedSettings, isFalse);
      expect(vm.progress.cloudCount, 0);
      expect(vm.progress.deviceTotal, 0);
      expect(vm.progress.pendingCount, 0);
    });

    test('toggleAdvancedSettings toggles visibility flag', () {
      final vm = CloudSyncViewModel();
      expect(vm.showAdvancedSettings, isFalse);
      vm.toggleAdvancedSettings();
      expect(vm.showAdvancedSettings, isTrue);
      vm.toggleAdvancedSettings();
      expect(vm.showAdvancedSettings, isFalse);
    });

    test('ViewModel listens to CloudSyncService status and progress notifiers', () {
      final vm = CloudSyncViewModel();
      var notificationCount = 0;
      vm.addListener(() => notificationCount++);

      // Simulate status change on service
      CloudSyncService.instance.statusNotifier.value = CloudSyncStatus.syncing;
      expect(vm.status, CloudSyncStatus.syncing);

      // Simulate progress change on service
      CloudSyncService.instance.progressNotifier.value = const CloudSyncProgress(
        deviceTotal: 500,
        cloudCount: 300,
        pendingCount: 200,
      );
      expect(vm.progress.deviceTotal, 500);
      expect(vm.progress.cloudCount, 300);
      expect(vm.progress.pendingCount, 200);
      expect(vm.progress.percentInCloud, 60.0);

      expect(notificationCount, greaterThanOrEqualTo(2));

      // Reset service notifiers
      CloudSyncService.instance.statusNotifier.value = CloudSyncStatus.idle;
      CloudSyncService.instance.progressNotifier.value = const CloudSyncProgress();
      vm.dispose();
    });
  });
}
