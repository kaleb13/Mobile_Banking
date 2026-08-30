import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../models/app_currency.dart';
import '../../models/scan_window_option.dart';
import '../../services/database_service.dart';

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

  Future<bool> getIsBalanceVisible();
  Future<void> setIsBalanceVisible(bool value);

  Future<Set<String>> getHiddenBalanceBanks();
  Future<void> setHiddenBalanceBanks(Set<String> banks);
}

class SettingsRepositoryImpl implements SettingsRepository {
  final DatabaseService _dbService;

  SettingsRepositoryImpl({DatabaseService? dbService})
      : _dbService = dbService ?? DatabaseService.instance;

  @override
  Future<Set<String>> getHiddenBalanceBanks() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('hidden_balance_banks') ?? [];
    return list.toSet();
  }

  @override
  Future<void> setHiddenBalanceBanks(Set<String> banks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hidden_balance_banks', banks.toList());
  }

  @override
  Future<bool> getIsBalanceVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_balance_visible') ?? true;
  }

  @override
  Future<void> setIsBalanceVisible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_balance_visible', value);
  }

  @override
  Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme_mode');
    if (saved == 'light') return AppThemeMode.light;
    if (saved == 'dark') return AppThemeMode.dark;
    return AppThemeMode.hybrid;
  }

  @override
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', mode.name);
  }

  @override
  Future<AppCurrency> getCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('selected_currency_code') ??
        await _dbService.getSetting('selected_currency_code') ??
        'ETB';
    return AppCurrency.fromCode(code);
  }

  @override
  Future<void> setCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_currency_code', code);
    await _dbService.setSetting('selected_currency_code', code);
  }

  @override
  Future<bool> getSmsListeningEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_sms_listening_enabled') ?? true;
  }

  @override
  Future<void> setSmsListeningEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_sms_listening_enabled', value);
  }

  @override
  Future<bool> getPushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_push_notifications_enabled') ?? false;
  }

  @override
  Future<void> setPushNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_push_notifications_enabled', value);
  }

  @override
  Future<bool> getReportDailyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('report_daily_enabled') ?? true;
  }

  @override
  Future<void> setReportDailyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('report_daily_enabled', value);
  }

  @override
  Future<bool> getReportWeeklyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('report_weekly_enabled') ?? true;
  }

  @override
  Future<void> setReportWeeklyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('report_weekly_enabled', value);
  }

  @override
  Future<bool> getReportMonthlyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('report_monthly_enabled') ?? true;
  }

  @override
  Future<void> setReportMonthlyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('report_monthly_enabled', value);
  }

  @override
  Future<String> getNotifQuickButton1() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notif_quick_button_1') ?? 'Food';
  }

  @override
  Future<void> setNotifQuickButton1(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_quick_button_1', value);
  }

  @override
  Future<String> getNotifQuickButton2() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('notif_quick_button_2') ?? 'Goods';
  }

  @override
  Future<void> setNotifQuickButton2(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notif_quick_button_2', value);
  }

  @override
  Future<DateTime?> getCustomMonthAnchorDate() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('custom_month_anchor_date');
    return str != null ? DateTime.tryParse(str) : null;
  }

  @override
  Future<void> setCustomMonthAnchorDate(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove('custom_month_anchor_date');
    } else {
      await prefs.setString('custom_month_anchor_date', date.toIso8601String());
    }
  }

  @override
  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name_v1');
  }

  @override
  Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name_v1', name);
  }

  @override
  Future<bool> getIsOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_onboarding_complete_v1') ?? false;
  }

  @override
  Future<void> setOnboardingComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_onboarding_complete_v1', complete);
  }

  @override
  Future<ScanWindowOption> getScanWindow() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('scan_window_option_index');
    if (idx != null && idx >= 0 && idx < ScanWindowOption.values.length) {
      return ScanWindowOption.values[idx];
    }
    return ScanWindowOption.thirtyDays;
  }

  @override
  Future<void> setScanWindow(ScanWindowOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scan_window_option_index', option.index);
  }
}
