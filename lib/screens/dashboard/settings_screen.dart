import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'backup_restore_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../settings/data_maintenance_screen.dart';
import '../settings/expense_definitions_screen.dart';
import '../../widgets/app_header.dart';
import 'reason_management_screen.dart';
import 'about_app_screen.dart';
import '../../models/app_currency.dart';
import '../../models/scan_window_option.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_list_tile.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../widgets/bank_card_widget.dart';
import 'privacy_policy_screen.dart';
import '../privacy/privacy_settings_screen.dart';
import '../settings/notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final bool _isResetting = false;

  @override
  void initState() {
    super.initState();
  }



  Widget _buildCardBase(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF111821),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.background,
          child: Stack(
            children: [
              SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────
                    const AppHeader(
                      title: 'Settings',
                      showBackButton: true,
                      padding: EdgeInsets.fromLTRB(8, 12, 16, 8),
                    ),

                    const SizedBox(height: 4),

                    // ── Section: Financial Logic ────────────────────────
                    _sectionLabel('Core Finance'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.gold, // Gold
                        label: 'Expense Definitions',
                        subtitle: 'Manage recurring and manual templates',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ExpenseDefinitionsScreen()),
                        ),
                        showDivider: true,
                      ),
                      _settingsTile(
                        context,
                        icon: Icons.category_outlined,
                        iconColor: AppColors.violet, // Purple
                        label: 'Category Management',
                        subtitle: 'Manage categories and subcategories',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReasonManagementScreen()),
                        ),
                        showDivider: true,
                      ),
                      Consumer<FinanceProvider>(
                          builder: (context, provider, _) {
                        final anchor = provider.customMonthAnchorDate;
                        final subtitle = anchor == null
                            ? 'Standard calendar (1st of month)'
                            : 'Every 30 days from ${anchor.day.toString().padLeft(2, '0')}/${anchor.month.toString().padLeft(2, '0')}/${anchor.year}';
                        return _settingsTile(
                          context,
                          icon: Icons.calendar_month_outlined,
                          iconColor: AppColors.info, // Light blue
                          label: 'Custom Month Start',
                          subtitle: subtitle,
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: anchor ?? now,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100),
                              helpText: 'SELECT ANCHOR DATE',
                              confirmText: 'SET 30-DAY MONTH',
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: AppColors.positive,
                                      onPrimary: Colors.white,
                                      surface: AppColors.bgMid,
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              await provider.setCustomMonthAnchorDate(picked);
                            }
                          },
                          trailing: anchor != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: AppColors.textSoft, size: 20),
                                  onPressed: () =>
                                      provider.setCustomMonthAnchorDate(null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : const Icon(Icons.arrow_forward_ios_rounded,
                                  color: AppColors.textSoft, size: 14),
                          showDivider: false,
                        );
                      }),
                    ]),

                    const SizedBox(height: 16),

                    // ── Section: Data ──────────────────────────────────
                    _sectionLabel('Data & Storage'),
                    _buildCardBase([
                      Consumer<FinanceProvider>(
                        builder: (context, provider, _) {
                          return _settingsTile(
                            context,
                            icon: Icons.history_rounded,
                            iconColor: AppColors.positive,
                            label: 'SMS Scan History Range',
                            subtitle: provider.scanWindowOption.title,
                            onTap: () => _showScanWindowChooser(context, provider),
                            showDivider: true,
                          );
                        },
                      ),
                      _settingsTile(
                        context,
                        icon: Icons.cloud_upload_outlined,
                        iconColor: AppColors.infoLight,
                        label: 'Backup & Restore',
                        subtitle: 'Export or import your financial data',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const BackupRestoreScreen()),
                        ),
                        showDivider: false,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Section: Maintenance ───────────────────────────
                    _sectionLabel('Maintenance'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        iconColor: AppColors.infoLight,
                        label: 'Data Maintenance',
                        subtitle: 'Refresh or reset your local database',
                        showDivider: false,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DataMaintenanceScreen()),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Section: Notifications ─────────────────────────
                    _sectionLabel('Notifications'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.notifications_active_rounded,
                        iconColor: AppColors.positive,
                        label: 'Notification Settings',
                        subtitle: 'Active listening, quick buttons & reports',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        ),
                        showDivider: false,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Section: Appearance ────────────────────────────
                    _sectionLabel('Appearance'),
                    _buildCardBase([
                      Consumer<FinanceProvider>(
                        builder: (context, provider, _) {
                          final currency = provider.currentCurrency;
                          return _settingsTile(
                            context,
                            icon: Icons.currency_exchange_rounded,
                            iconColor: AppColors.positive,
                            label: 'Currency Icon',
                            subtitle: currency.name,
                            onTap: () => _showCurrencyPickerSheet(context, provider),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppBadge.success(
                                  text: currency.shortLabel,
                                  size: AppBadgeSize.small,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  size: 14,
                                ),
                              ],
                            ),
                            showDivider: true,
                          );
                        },
                      ),
                      _settingsTile(
                        context,
                        icon: Icons.palette_outlined,
                        iconColor: AppColors.chartPurple,
                        label: 'Theme',
                        subtitle: 'Dark mode (default)',
                        onTap: () {},
                        trailing: _comingSoon(),
                        showDivider: false,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Section: Privacy & Security ───────────────────
                    _sectionLabel('Privacy & Security'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.lock_rounded,
                        iconColor: AppColors.gold,
                        label: 'App Lock & Biometrics',
                        subtitle: 'PIN lock and fingerprint unlock',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacySettingsScreen(),
                          ),
                        ),
                        showDivider: false,
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Section: About ─────────────────────────────────
                    _sectionLabel('About'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.amberFaint,
                        label: 'About App',
                        subtitle: 'Developer, contributors, and app info',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AboutAppScreen()),
                        ),
                        showDivider: true,
                      ),
                      _settingsTile(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        iconColor: AppColors.successLight,
                        label: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen()),
                        ),
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),

            // Full-screen loading overlay
            if (_isResetting)
              Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.gold),
                      SizedBox(height: 16),
                      Text('Processing…',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8, top: 24),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.2),
                      size: 14,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.white.withValues(alpha: 0.05),
          ),
      ],
    );
  }


  Widget _comingSoon() {
    return const AppBadge.neutral(
      text: 'Soon',
      size: AppBadgeSize.small,
    );
  }

  void _showCurrencyPickerSheet(BuildContext context, FinanceProvider provider) {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final currentCode = provider.currentCurrency.code;
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Default Currency Icon',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your preferred currency symbol to display across your balance and transactions.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: AppCurrency.supportedCurrencies.map((curr) {
                      final isSelected = curr.code.toLowerCase() == currentCode.toLowerCase();
                      return InkWell(
                        onTap: () {
                          provider.setCurrency(curr.code);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.positive.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                                                      ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: CurrencySymbolWidget(
                                  currency: curr,
                                  size: 18,
                                  color: isSelected ? AppColors.positive : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  curr.name,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.positive : Colors.white,
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.positive,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showScanWindowChooser(BuildContext context, FinanceProvider provider) {
    AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        final currentOption = provider.scanWindowOption;

        return AppDrawer(
          title: 'SMS Scan History Range',
          subtitle: 'Choose how far back Shibre is allowed to import and refresh your banking SMS. All refreshes strictly abide by this boundary.',
          heightFactor: null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...ScanWindowOption.values.map((option) {
                final isSelected = option == currentOption;
                final badgeText = option.badgeLabel;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppListTile(
                    title: option.title,
                    subtitle: option.subtitle,
                    leadingIcon: _getScanOptionIcon(option),
                    leadingColor: isSelected ? AppColors.positive : null,
                    badge: badgeText != null
                        ? (option == ScanWindowOption.sevenDays
                            ? const AppBadge.success(
                                text: 'Recommended',
                                size: AppBadgeSize.micro,
                              )
                            : option.isHeavyLoad
                                ? const AppBadge.destructive(
                                    text: 'Heavy Load',
                                    size: AppBadgeSize.micro,
                                  )
                                : AppBadge.neutral(
                                    text: badgeText,
                                    size: AppBadgeSize.micro,
                                  ))
                        : null,
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.positive,
                            size: 20,
                          )
                        : null,
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      HapticFeedback.lightImpact();

                      _showRescanProgressDialog(context, option.title);

                      await provider.setScanWindowOption(option, rescanImmediately: true);

                      if (context.mounted && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(); // Dismiss progress dialog
                      }

                      if (context.mounted) {
                        AppToast.success(
                          context,
                          message: 'Scan Range Updated',
                          subtitle: 'Active window: ${option.title}',
                        );
                      }
                    },
                  ),
                );
              }),
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.speed_rounded,
                      color: AppColors.brandGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '7 Days or Today provides the fastest, most reliable performance across all devices.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRescanProgressDialog(BuildContext context, String optionTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Consumer<FinanceProvider>(
                builder: (context, provider, _) {
                  final scanProgress = provider.scanProgress;
                  final pct = scanProgress.progress > 0
                      ? scanProgress.progress.clamp(0.05, 1.0)
                      : 0.15;
                  final stage = scanProgress.stage.isNotEmpty
                      ? scanProgress.stage
                      : 'Rescanning verified banking records…';
                  final banks = scanProgress.scannedBanks;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Updating Scan Range',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${(pct * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppColors.positive,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomProgressBar(
                        progress: pct,
                        height: 7,
                        progressColor: AppColors.positive,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        stage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12.5,
                        ),
                      ),
                      if (banks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ...banks.take(4).map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: BankCardWidget.bankLogo(b.bankName, 14),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      b.bankName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${b.transactionCount} msgs',
                                    style: const TextStyle(
                                      color: AppColors.positive,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getScanOptionIcon(ScanWindowOption option) {
    switch (option) {
      case ScanWindowOption.todayOnly:
        return Icons.today_rounded;
      case ScanWindowOption.sevenDays:
        return Icons.date_range_rounded;
      case ScanWindowOption.thirtyDays:
        return Icons.calendar_month_rounded;
      case ScanWindowOption.ninetyDays:
        return Icons.event_note_rounded;
      case ScanWindowOption.allTime:
        return Icons.history_rounded;
    }
  }
}
