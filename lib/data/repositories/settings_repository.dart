import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../models/app_currency.dart';
import '../../models/scan_window_option.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

abstract class SettingsRepository {
  Future<AppThemeMode> getThemeMode();
  Future<void> setThemeMode(AppThemeMode mode);

  Future<AppCurrency> getCurrency();
  Future<void> setCurrency(String code);

  Future<bool> getSmsListeningEnabled();
  Future<void> setSmsListeningEnabled(bool value);

  Future<bool> getPushNotificationsEnabled();
  Future<void> setPushNotificationsEnabled(bool value);

  Future<bool> getReportDailyEnabled();
  Future<void> setReportDailyEnabled(bool value);

  Future<bool> getReportWeeklyEnabled();
  Future<void> setReportWeeklyEnabled(bool value);

  Future<bool> getReportMonthlyEnabled();
  Future<void> setReportMonthlyEnabled(bool value);

  Future<String> getNotifQuickButton1();
  Future<void> setNotifQuickButton1(String value);

  Future<String> getNotifQuickButton2();
  Future<void> setNotifQuickButton2(String value);

  Future<DateTime?> getCustomMonthAnchorDate();
  Future<void> setCustomMonthAnchorDate(DateTime? date);

  Future<String?> getUserName();
  Future<void> setUserName(String name);

  Future<bool> getIsOnboardingComplete();
  Future<void> setOnboardingComplete(bool complete);

  Future<ScanWindowOption> getScanWindow();
  Future<void> setScanWindow(ScanWindowOption option);

  Future<DateTime?> getScanWindowStartDate();
  Future<void> setScanWindowStartDate(DateTime? date);
  Future<DateTime?> getEffectiveScanWindowAnchorDate();

  Future<bool> getIsBalanceVisible();
  Future<void> setIsBalanceVisible(bool value);

  Future<Set<String>> getHiddenBalanceBanks();
  Future<void> setHiddenBalanceBanks(Set<String> banks);

  Future<int> getLastCelebratedLevel();
  Future<void> setLastCelebratedLevel(int level);

  Future<bool> getIsNotifGuideDismissed();
  Future<void> setIsNotifGuideDismissed(bool dismissed);
}

class SettingsRepositoryImpl implements SettingsRepository {
  final DatabaseService _dbService;
  final String? Function()? _userIdProvider;

  SettingsRepositoryImpl({
    DatabaseService? dbService,
    String? Function()? userIdProvider,
  })  : _dbService = dbService ?? DatabaseService.instance,
        _userIdProvider = userIdProvider;

  String _scopedKey(String baseKey) {
    final userId = _userIdProvider != null
        ? _userIdProvider!()
        : _dbService.currentUserId;
    if (userId != null && userId.isNotEmpty) {
      final sanitized = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      return '${sanitized}_$baseKey';
    }
    return baseKey;
  }

  @override
  Future<int> getLastCelebratedLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scopedKey('last_celebrated_level')) ??
        prefs.getInt('last_celebrated_level') ??
        1;
  }

  @override
  Future<void> setLastCelebratedLevel(int level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scopedKey('last_celebrated_level'), level);
  }

  @override
  Future<Set<String>> getHiddenBalanceBanks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final scopedKey = _scopedKey('hidden_balance_banks');

    // 1. Authoritative: if scoped key exists (even as empty list []), trust it directly
    if (prefs.containsKey(scopedKey)) {
      final list = prefs.getStringList(scopedKey) ?? [];
      return list.toSet();
    }

    // 2. Migration from legacy un-scoped key if scoped key was never initialized
    if (prefs.containsKey('hidden_balance_banks')) {
      final legacyList = prefs.getStringList('hidden_balance_banks') ?? [];
      await prefs.setStringList(scopedKey, legacyList);
      if (scopedKey != 'hidden_balance_banks') {
        await prefs.remove('hidden_balance_banks');
      }
      return legacyList.toSet();
    }

    return {};
  }

  @override
  Future<void> setHiddenBalanceBanks(Set<String> banks) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _scopedKey('hidden_balance_banks');
    // Always persist as a list so containsKey remains true and empty [] is never null
    await prefs.setStringList(scopedKey, banks.toList());
    // Permanently purge legacy un-scoped key so it never resurrects stale hidden banks
    if (scopedKey != 'hidden_balance_banks') {
      await prefs.remove('hidden_balance_banks');
    }
  }

  @override
  Future<bool> getIsBalanceVisible() async {
    return false; // Cold start / fresh launch always starts hidden
  }

  @override
  Future<void> setIsBalanceVisible(bool value) async {
    // Session-only visibility: not persisted across cold restarts
  }

  @override
  Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_scopedKey('app_theme_mode')) ??
        prefs.getString('app_theme_mode');
    if (saved == 'light') return AppThemeMode.light;
    if (saved == 'dark') return AppThemeMode.dark;
    return AppThemeMode.hybrid;
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey('app_theme_mode'), mode.name);
  }

  @override
  Future<AppCurrency> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_scopedKey('selected_currency_code')) ??
        prefs.getString('selected_currency_code') ??
        await _dbService.getSetting('selected_currency_code') ??
        'ETB';
    return AppCurrency.fromCode(code);
  }

  @override
  Future<void> setCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey('selected_currency_code'), code);
    await _dbService.setSetting('selected_currency_code', code);
  }

  @override
  Future<bool> getSmsListeningEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey('is_sms_listening_enabled')) ??
        prefs.getBool('is_sms_listening_enabled') ??
        true;
  }

  @override
  Future<void> setSmsListeningEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey('is_sms_listening_enabled'), value);
    await prefs.setBool('is_sms_listening_enabled', value);
    await prefs.setBool('flutter.is_sms_listening_enabled', value);
    try {
      await AuthService.instance.updateActiveAccountSyncDeviceSms(value);
    } catch (_) {}
  }

  @override
  Future<bool> getPushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey('is_push_notifications_enabled')) ??
        prefs.getBool('is_push_notifications_enabled') ??
        false;
  }

  @override
  Future<void> setPushNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey('is_push_notifications_enabled'), value);
  }

  @override
  Future<bool> getReportDailyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey('report_daily_enabled')) ??
        prefs.getBool('report_daily_enabled') ??
        true;
  }

  @override
  Future<void> setReportDailyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey('report_daily_enabled'), value);
  }

  @override
  Future<bool> getReportWeeklyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey('report_weekly_enabled')) ??
        prefs.getBool('report_weekly_enabled') ??
        true;
  }

  @override
  Future<void> setReportWeeklyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey('report_weekly_enabled'), value);
  }

  @override
  Future<bool> getReportMonthlyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey('report_monthly_enabled')) ??
        prefs.getBool('report_monthly_enabled') ??
        true;
  }

  @override
  Future<void> setReportMonthlyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey('report_monthly_enabled'), value);
  }

  @override
  Future<String> getNotifQuickButton1() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey('notif_quick_button_1')) ??
        prefs.getString('notif_quick_button_1') ??
        'Food';
  }

  @override
  Future<void> setNotifQuickButton1(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey('notif_quick_button_1'), value);
  }

  @override
  Future<String> getNotifQuickButton2() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey('notif_quick_button_2')) ??
        prefs.getString('notif_quick_button_2') ??
        'Goods';
  }

  @override
  Future<void> setNotifQuickButton2(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey('notif_quick_button_2'), value);
  }

  @override
  Future<DateTime?> getCustomMonthAnchorDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_scopedKey('custom_month_anchor_date')) ??
        prefs.getString('custom_month_anchor_date');
    return str != null ? DateTime.tryParse(str) : null;
  }

  @override
  Future<void> setCustomMonthAnchorDate(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey('custom_month_anchor_date');
    if (date == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, date.toIso8601String());
    }
  }

  @override
  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey('user_name_v1')) ??
        prefs.getString('user_name_v1');
  }

  @override
  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey('user_name_v1'), name);
  }

  @override
  Future<bool> getIsOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey('is_onboarding_complete_v1')) ??
        prefs.getBool('is_onboarding_complete_v1') ??
        false;
  }

  @override
  Future<void> setOnboardingComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey('is_onboarding_complete_v1'), complete);
  }

  @override
  Future<ScanWindowOption> getScanWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_scopedKey('scan_window_option_index')) ??
        prefs.getInt('scan_window_option_index');
    if (idx != null && idx >= 0 && idx < ScanWindowOption.values.length) {
      return ScanWindowOption.values[idx];
    }
    return ScanWindowOption.thirtyDays;
  }

  @override
  Future<void> setScanWindow(ScanWindowOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scopedKey('scan_window_option_index'), option.index);
    final startKey = _scopedKey('scan_window_start_date_ms');
    if (option == ScanWindowOption.allTime) {
      await prefs.remove(startKey);
    } else {
      final now = DateTime.now();
      DateTime startDate;
      switch (option) {
        case ScanWindowOption.todayOnly:
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case ScanWindowOption.sevenDays:
          startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
          break;
        case ScanWindowOption.thirtyDays:
          startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
          break;
        case ScanWindowOption.ninetyDays:
          startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
          break;
        case ScanWindowOption.allTime:
          startDate = DateTime(2000, 1, 1);
          break;
      }
      await prefs.setInt(startKey, startDate.millisecondsSinceEpoch);
    }
  }

  @override
  Future<DateTime?> getScanWindowStartDate() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_scopedKey('scan_window_start_date_ms')) ??
        prefs.getInt('scan_window_start_date_ms');
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  Future<void> setScanWindowStartDate(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scopedKey('scan_window_start_date_ms');
    if (date != null) {
      await prefs.setInt(key, date.millisecondsSinceEpoch);
    } else {
      await prefs.remove(key);
    }
  }

  @override
  Future<DateTime?> getEffectiveScanWindowAnchorDate() async {
    final option = await getScanWindow();
    if (option == ScanWindowOption.allTime) return null;
    final savedStart = await getScanWindowStartDate();
    if (savedStart != null) return savedStart;
    final fallback = option.anchorDate;
    await setScanWindowStartDate(fallback);
    return fallback;
  }

  @override
  Future<bool> getIsNotifGuideDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey('is_notif_guide_dismissed_v1')) ??
        prefs.getBool('is_notif_guide_dismissed_v1') ??
        false;
  }

  @override
  Future<void> setIsNotifGuideDismissed(bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey('is_notif_guide_dismissed_v1'), dismissed);
  }
}
