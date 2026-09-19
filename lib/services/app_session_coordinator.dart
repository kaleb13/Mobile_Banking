import 'dart:async';
import 'package:flutter/foundation.dart';
import '../presentation/viewmodels/transactions_view_model.dart';
import '../presentation/viewmodels/cash_wallet_view_model.dart';
import '../presentation/viewmodels/loans_view_model.dart';
import '../presentation/viewmodels/savings_view_model.dart';
import '../presentation/viewmodels/notifications_view_model.dart';
import '../presentation/viewmodels/settings_view_model.dart';
import '../presentation/viewmodels/analytics_view_model.dart';
import '../presentation/viewmodels/cloud_sync_view_model.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';

/// AppSessionCoordinator — orchestrates account transitions, full ViewModel
/// state reloads, and cloud sync re-connections across the entire app lifecycle.
class AppSessionCoordinator {
  static final AppSessionCoordinator instance = AppSessionCoordinator._internal();
  AppSessionCoordinator._internal();

  TransactionsViewModel? _txVM;
  CashWalletViewModel? _cashVM;
  LoansViewModel? _loansVM;
  SavingsViewModel? _savingsVM;
  NotificationsViewModel? _notifsVM;
  SettingsViewModel? _settingsVM;
  AnalyticsViewModel? _analyticsVM;
  CloudSyncViewModel? _cloudSyncVM;

  /// Attaches references to all application ViewModels.
  void attachViewModels({
    required TransactionsViewModel txVM,
    required CashWalletViewModel cashVM,
    required LoansViewModel loansVM,
    required SavingsViewModel savingsVM,
    required NotificationsViewModel notifsVM,
    required SettingsViewModel settingsVM,
    required AnalyticsViewModel analyticsVM,
    CloudSyncViewModel? cloudSyncVM,
  }) {
    _txVM = txVM;
    _cashVM = cashVM;
    _loansVM = loansVM;
    _savingsVM = savingsVM;
    _notifsVM = notifsVM;
    _settingsVM = settingsVM;
    _analyticsVM = analyticsVM;
    _cloudSyncVM = cloudSyncVM;
  }

  /// Reloads all application ViewModels concurrently and recalculates analytics.
  Future<void> reloadAllData() async {
    final txVM = _txVM;
    final cashVM = _cashVM;
    final loansVM = _loansVM;
    final savingsVM = _savingsVM;
    final notifsVM = _notifsVM;
    final settingsVM = _settingsVM;
    final analyticsVM = _analyticsVM;
    final cloudSyncVM = _cloudSyncVM;

    await Future.wait([
      if (txVM != null) txVM.loadAll(),
      if (cashVM != null) cashVM.loadCashData(),
      if (loansVM != null) loansVM.loadLoans(),
      if (savingsVM != null) savingsVM.fetchSavingGoals(),
      if (notifsVM != null) notifsVM.loadNotifications(),
      if (settingsVM != null) settingsVM.reloadSettings(),
      if (cloudSyncVM != null) cloudSyncVM.refreshState(),
    ]);

    if (analyticsVM != null && txVM != null) {
      analyticsVM.recalculate(
        pausedBanks: txVM.pausedBanks,
        getTopLevelCategory: txVM.getTopLevelCategoryForTransaction,
        isDateInMonthOf: (d, ref) => d.year == ref.year && d.month == ref.month,
      );
    }
  }

  /// Coordinates a clean, atomic account transition across the app:
  /// 1. Unsubscribes from active Realtime channels.
  /// 2. Switches SQLite database & native SharedPreferences via AuthService.
  /// 3. Concurrently reloads all 6 ViewModels with the target user's isolated data.
  /// 4. Reconnects CloudSync Realtime for the new user.
  Future<bool> switchAccount(String userId, {bool? syncDeviceSms}) async {
    try {
      // 1. Pause existing Realtime listeners
      CloudSyncService.instance.unsubscribeFromRealtime();

      // 2. Perform underlying account & SQLite database switch
      final success = await AuthService.instance.switchAccount(
        userId,
        syncDeviceSms: syncDeviceSms,
      );
      if (!success) return false;

      // 3. Reload all ViewModels with newly isolated data and scoped settings
      await reloadAllData();

      // 4. Connect Cloud Sync with the new session
      unawaited(CloudSyncService.instance.switchAccount(userId));

      return true;
    } catch (e) {
      debugPrint('AppSessionCoordinator.switchAccount error: $e');
      return false;
    }
  }
}
