import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/app_currency.dart';
import '../../models/scan_window_option.dart';
import '../../models/scan_progress_status.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/report_notification_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _repository;

  SettingsViewModel({
    required SettingsRepository repository,
    bool initialOnboardingComplete = false,
    AppThemeMode initialThemeMode = AppThemeMode.hybrid,
  })  : _repository = repository,
        _isOnboardingComplete = initialOnboardingComplete,
        _currentThemeMode = initialThemeMode;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AppThemeMode _currentThemeMode = AppThemeMode.hybrid;
  AppThemeMode get currentThemeMode => _currentThemeMode;

  AppCurrency _currentCurrency = AppCurrency.defaultCurrency;
  AppCurrency get currentCurrency => _currentCurrency;

  ScanWindowOption _scanWindowOption = ScanWindowOption.thirtyDays;
  ScanWindowOption get scanWindowOption => _scanWindowOption;

  Future<void> setScanWindowOption(ScanWindowOption option, {bool rescanImmediately = false}) async {
    _scanWindowOption = option;
    notifyListeners();
    await _repository.setScanWindow(option);
  }

  ScanProgressStatus _scanProgress = const ScanProgressStatus.idle();
  ScanProgressStatus get scanProgress => _scanProgress;

  void updateScanProgress(ScanProgressStatus status) {
    _scanProgress = status;
    notifyListeners();
  }

  bool _isSmsListeningEnabled = true;
  bool get isSmsListeningEnabled => _isSmsListeningEnabled;

  bool _isPushNotificationsEnabled = false;
  bool get isPushNotificationsEnabled => _isPushNotificationsEnabled;

  bool _isDailyReportEnabled = true;
  bool get isDailyReportEnabled => _isDailyReportEnabled;

  bool _isWeeklyReportEnabled = true;
  bool get isWeeklyReportEnabled => _isWeeklyReportEnabled;

  bool _isMonthlyReportEnabled = true;
  bool get isMonthlyReportEnabled => _isMonthlyReportEnabled;

  String _notifQuickButton1 = 'Food';
  String get notifQuickButton1 => _notifQuickButton1;

  String _notifQuickButton2 = 'Goods';
  String get notifQuickButton2 => _notifQuickButton2;

  DateTime? _customMonthAnchorDate;
  DateTime? get customMonthAnchorDate => _customMonthAnchorDate;

  String? _userName;
  String? get userName => _userName;

  bool _isOnboardingComplete = false;
  bool get isOnboardingComplete => _isOnboardingComplete;

  bool _isBalanceVisible = false;
  bool get isBalanceVisible => _isBalanceVisible;

  Set<String> _hiddenBalanceBanks = {};
  Set<String> get hiddenBalanceBanks => Set.unmodifiable(_hiddenBalanceBanks);

  bool isBankBalanceHidden(String bankName) {
    return _hiddenBalanceBanks
        .any((b) => b.trim().toUpperCase() == bankName.trim().toUpperCase());
  }

  Future<void> toggleBankBalanceVisibility(String bankName) async {
    final nameUp = bankName.trim().toUpperCase();
    if (isBankBalanceHidden(bankName)) {
      _hiddenBalanceBanks =
          _hiddenBalanceBanks.where((b) => b.trim().toUpperCase() != nameUp).toSet();
    } else {
      _hiddenBalanceBanks = {..._hiddenBalanceBanks, bankName.trim()};
    }
    notifyListeners();
    await _repository.setHiddenBalanceBanks(_hiddenBalanceBanks);
  }

  Future<void> setBankBalanceHidden(String bankName, bool isHidden) async {
    final nameUp = bankName.trim().toUpperCase();
    if (isHidden) {
      if (!isBankBalanceHidden(bankName)) {
        _hiddenBalanceBanks = {..._hiddenBalanceBanks, bankName.trim()};
        notifyListeners();
        await _repository.setHiddenBalanceBanks(_hiddenBalanceBanks);
      }
    } else {
      if (isBankBalanceHidden(bankName)) {
        _hiddenBalanceBanks =
            _hiddenBalanceBanks.where((b) => b.trim().toUpperCase() != nameUp).toSet();
        notifyListeners();
        await _repository.setHiddenBalanceBanks(_hiddenBalanceBanks);
      }
    }
  }

  double _pageOffset = 0.0;
  double get pageOffset => _pageOffset;

  void setPageOffset(double offset) {
    if ((_pageOffset - offset).abs() > 0.001) {
      _pageOffset = offset;
      notifyListeners();
    }
  }

  int _currentScreenIndex = 0;
  int get currentScreenIndex => _currentScreenIndex;

  void setScreenIndex(int index) {
    if (_currentScreenIndex != index) {
      _currentScreenIndex = index;
      notifyListeners();
    }
  }

  final ValueNotifier<int?> tabNavigationNotifier = ValueNotifier<int?>(null);

  void animateToTab(int index) {
    tabNavigationNotifier.value = index;
    Future.microtask(() => tabNavigationNotifier.value = null);
  }

  double _homeTopScrollOffset = 0.0;
  double get homeTopScrollOffset => _homeTopScrollOffset;

  void setHomeTopScrollOffset(double offset) {
    final clamped = offset < 0 ? 0.0 : offset;
    _homeTopScrollOffset = clamped;
  }

  bool _isMenuOpen = false;
  bool get isMenuOpen => _isMenuOpen;

  void setIsMenuOpen(bool isOpen) {
    if (_isMenuOpen != isOpen) {
      _isMenuOpen = isOpen;
      notifyListeners();
    }
  }

  Future<void> init() async {
    _currentThemeMode = await _repository.getThemeMode();
    _currentCurrency = await _repository.getCurrency();
    _isSmsListeningEnabled = await _repository.getSmsListeningEnabled();
    _isPushNotificationsEnabled = await _repository.getPushNotificationsEnabled();
    _isDailyReportEnabled = await _repository.getReportDailyEnabled();
    _isWeeklyReportEnabled = await _repository.getReportWeeklyEnabled();
    _isMonthlyReportEnabled = await _repository.getReportMonthlyEnabled();
    _notifQuickButton1 = await _repository.getNotifQuickButton1();
    _notifQuickButton2 = await _repository.getNotifQuickButton2();
    _customMonthAnchorDate = await _repository.getCustomMonthAnchorDate();
    _userName = await _repository.getUserName();
    _isOnboardingComplete = await _repository.getIsOnboardingComplete();
    _isBalanceVisible = await _repository.getIsBalanceVisible();
    _hiddenBalanceBanks = await _repository.getHiddenBalanceBanks();
    _scanWindowOption = await _repository.getScanWindow();
    _isInitialized = true;
    notifyListeners();

    // Synchronize scheduled background alarms
    if (_isPushNotificationsEnabled) {
      await ReportNotificationService.instance.syncSchedules();
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _currentThemeMode = mode;
    notifyListeners();
    await _repository.setThemeMode(mode);
  }

  Future<void> setCurrency(String code) async {
    _currentCurrency = AppCurrency.fromCode(code);
    notifyListeners();
    await _repository.setCurrency(code);
    // Currency changed: update scheduled reports formatting
    if (_isPushNotificationsEnabled) {
      await ReportNotificationService.instance.syncSchedules();
    }
  }

  Future<void> setSmsListeningEnabled(bool value) async {
    _isSmsListeningEnabled = value;
    notifyListeners();
    await _repository.setSmsListeningEnabled(value);
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    _isPushNotificationsEnabled = value;
    notifyListeners();
    await _repository.setPushNotificationsEnabled(value);
    if (value) {
      await ReportNotificationService.instance.syncSchedules();
    } else {
      await ReportNotificationService.instance.cancelSchedules();
    }
  }

  Future<void> setDailyReportEnabled(bool value) async {
    _isDailyReportEnabled = value;
    notifyListeners();
    await _repository.setReportDailyEnabled(value);
    if (_isPushNotificationsEnabled) {
      await ReportNotificationService.instance.syncSchedules();
    }
  }

  Future<void> setWeeklyReportEnabled(bool value) async {
    _isWeeklyReportEnabled = value;
    notifyListeners();
    await _repository.setReportWeeklyEnabled(value);
    if (_isPushNotificationsEnabled) {
      await ReportNotificationService.instance.syncSchedules();
    }
  }

  Future<void> setMonthlyReportEnabled(bool value) async {
    _isMonthlyReportEnabled = value;
    notifyListeners();
    await _repository.setReportMonthlyEnabled(value);
    if (_isPushNotificationsEnabled) {
      await ReportNotificationService.instance.syncSchedules();
    }
  }

  /// Fires an immediate test push notification for previewing with live total balance
  Future<bool> sendTestReport(
    String reportType, {
    double? totalBalance,
    String? currency,
  }) async {
    return await ReportNotificationService.instance.sendTestReport(
      reportType,
      totalBalance: totalBalance,
      currency: currency,
    );
  }

  Future<void> setNotifQuickButton1(String value) async {
    _notifQuickButton1 = value;
    notifyListeners();
    await _repository.setNotifQuickButton1(value);
  }

  Future<void> setNotifQuickButton2(String value) async {
    _notifQuickButton2 = value;
    notifyListeners();
    await _repository.setNotifQuickButton2(value);
  }

  Future<void> setCustomMonthAnchorDate(DateTime? date) async {
    _customMonthAnchorDate = date;
    notifyListeners();
    await _repository.setCustomMonthAnchorDate(date);
  }

  Future<void> setUserName(String name) async {
    _userName = name;
    notifyListeners();
    await _repository.setUserName(name);
  }

  Future<void> setOnboardingComplete(bool complete) async {
    _isOnboardingComplete = complete;
    notifyListeners();
    await _repository.setOnboardingComplete(complete);
  }

  Future<void> completeOnboarding() => setOnboardingComplete(true);

  Future<void> toggleBalanceVisibility() async {
    _isBalanceVisible = !_isBalanceVisible;
    notifyListeners();
    await _repository.setIsBalanceVisible(_isBalanceVisible);
  }

  Future<void> setBalanceVisibility(bool isVisible) async {
    if (_isBalanceVisible != isVisible) {
      _isBalanceVisible = isVisible;
      notifyListeners();
      await _repository.setIsBalanceVisible(_isBalanceVisible);
    }
  }
}
