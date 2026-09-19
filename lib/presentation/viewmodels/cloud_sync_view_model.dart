import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/device_security_service.dart';
import '../../services/bank_senders.dart';

/// CloudSyncViewModel — encapsulates cloud backup state, progress metrics,
/// bank synchronization filters, and multi-device management.
///
/// Follows strict Clean Architecture and MVVM patterns with zero direct UI logic.
class CloudSyncViewModel extends ChangeNotifier {
  final CloudSyncService _cloudSyncService;
  final AuthService _authService;
  final DeviceSecurityService _deviceSecurityService;

  CloudSyncViewModel({
    CloudSyncService? cloudSyncService,
    AuthService? authService,
    DeviceSecurityService? deviceSecurityService,
  })  : _cloudSyncService = cloudSyncService ?? CloudSyncService.instance,
        _authService = authService ?? AuthService.instance,
        _deviceSecurityService = deviceSecurityService ?? DeviceSecurityService.instance {
    _init();
  }

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isSyncEnabled = false;
  bool _isLoadingDetails = false;
  bool _isRetryingBatch = false;
  bool _showAdvancedSettings = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _cloudDevices = [];
  List<Map<String, dynamic>> _cloudBanks = [];
  Set<String> _disabledSyncBanks = {};
  CloudSyncProgress _progress = const CloudSyncProgress();
  CloudSyncStatus _status = CloudSyncStatus.idle;
  DateTime? _lastSynced;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isSyncEnabled => _isSyncEnabled;
  bool get isLoadingDetails => _isLoadingDetails;
  bool get isRetryingBatch => _isRetryingBatch;
  bool get showAdvancedSettings => _showAdvancedSettings;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get cloudDevices => List.unmodifiable(_cloudDevices);
  List<Map<String, dynamic>> get cloudBanks => List.unmodifiable(_cloudBanks);
  Set<String> get disabledSyncBanks => Set.unmodifiable(_disabledSyncBanks);
  CloudSyncProgress get progress => _progress;
  CloudSyncStatus get status => _status;
  DateTime? get lastSynced => _lastSynced;

  bool get isAuthenticated => _authService.isAuthenticated;
  String? get userEmail => _authService.currentUser?.email;
  String? get currentDeviceFingerprint => _deviceSecurityService.deviceFingerprint;
  String get currentDeviceModel => _deviceSecurityService.deviceModel;

  // ── Initialization & Listeners ────────────────────────────────────────────
  void _init() {
    _progress = _cloudSyncService.progressNotifier.value;
    _status = _cloudSyncService.statusNotifier.value;
    _lastSynced = _cloudSyncService.lastSyncedNotifier.value;

    _cloudSyncService.progressNotifier.addListener(_onProgressChanged);
    _cloudSyncService.statusNotifier.addListener(_onStatusChanged);
    _cloudSyncService.lastSyncedNotifier.addListener(_onLastSyncedChanged);
    _cloudSyncService.errorNotifier.addListener(_onErrorChanged);
  }

  void _onProgressChanged() {
    _progress = _cloudSyncService.progressNotifier.value;
    notifyListeners();
  }

  void _onStatusChanged() {
    _status = _cloudSyncService.statusNotifier.value;
    notifyListeners();
  }

  void _onLastSyncedChanged() {
    _lastSynced = _cloudSyncService.lastSyncedNotifier.value;
    notifyListeners();
  }

  void _onErrorChanged() {
    _errorMessage = _cloudSyncService.errorNotifier.value;
    notifyListeners();
  }

  @override
  void dispose() {
    _cloudSyncService.progressNotifier.removeListener(_onProgressChanged);
    _cloudSyncService.statusNotifier.removeListener(_onStatusChanged);
    _cloudSyncService.lastSyncedNotifier.removeListener(_onLastSyncedChanged);
    _cloudSyncService.errorNotifier.removeListener(_onErrorChanged);
    super.dispose();
  }

  // ── Public Actions ────────────────────────────────────────────────────────
  Future<void> refreshState() async {
    _isSyncEnabled = await _cloudSyncService.isSyncEnabled();
    _disabledSyncBanks = await _cloudSyncService.getDisabledSyncBanks();
    _progress = await _cloudSyncService.refreshProgressMetrics();
    notifyListeners();

    if (_isSyncEnabled && isAuthenticated) {
      await loadDetails();
    }
  }

  Future<void> loadDetails() async {
    _isLoadingDetails = true;
    notifyListeners();

    try {
      final devices = await _cloudSyncService.getCloudContributingDevices();
      final banks = await _cloudSyncService.getCloudBankSummary();
      _cloudDevices = devices;
      _cloudBanks = banks;
    } catch (e) {
      debugPrint('CloudSyncViewModel loadDetails error: $e');
    } finally {
      _isLoadingDetails = false;
      notifyListeners();
    }
  }

  void toggleAdvancedSettings() {
    _showAdvancedSettings = !_showAdvancedSettings;
    notifyListeners();
  }

  Future<void> toggleCloudSync(bool enabled) async {
    _isSyncEnabled = enabled;
    notifyListeners();

    await _cloudSyncService.setSyncEnabled(enabled);
    if (enabled) {
      await _cloudSyncService.syncAll();
      await loadDetails();
    }
    await refreshState();
  }

  Future<void> syncNow() async {
    await _cloudSyncService.syncAll();
    await loadDetails();
    await refreshState();
  }

  Future<bool> retryFailedBatches() async {
    _isRetryingBatch = true;
    notifyListeners();

    try {
      final success = await _cloudSyncService.retryFailedUploads();
      await loadDetails();
      await refreshState();
      return success;
    } finally {
      _isRetryingBatch = false;
      notifyListeners();
    }
  }

  Future<void> setBankSyncEnabled(String bankName, bool enabled) async {
    await _cloudSyncService.setBankSyncEnabled(bankName, enabled);
    _disabledSyncBanks = await _cloudSyncService.getDisabledSyncBanks();
    await refreshState();
  }

  Future<void> toggleBankSync(String bankName) async {
    final currentlyDisabled = _disabledSyncBanks.any(
      (b) => BankSenders.isSameBank(b, bankName),
    );
    await setBankSyncEnabled(bankName, currentlyDisabled);
  }

  Future<bool> purgeDevice(String deviceFingerprint) async {
    final success = await _cloudSyncService.deleteCloudTransactionsByDevice(deviceFingerprint);
    await loadDetails();
    await refreshState();
    return success;
  }

  Future<bool> purgeBank(String bankName) async {
    final success = await _cloudSyncService.deleteCloudTransactionsByBank(bankName);
    await loadDetails();
    await refreshState();
    return success;
  }
}
