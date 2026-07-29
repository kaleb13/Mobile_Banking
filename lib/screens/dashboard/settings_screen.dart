import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'backup_restore_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../services/database_service.dart';
import '../settings/data_maintenance_screen.dart';
import '../settings/expense_definitions_screen.dart';
import '../../widgets/app_back_button.dart';
import 'reason_management_screen.dart';
import 'about_app_screen.dart';
import '../../models/app_currency.dart';
import '../../widgets/currency_symbol_widget.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final bool _isResetting = false;
  bool _showPersistentNotification = true; // default ON

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final val = await DatabaseService.instance
        .getSetting('show_persistent_notification');
    if (mounted) {
      setState(() {
        // null = not yet set → default true
        _showPersistentNotification = val == null || val == '1';
      });
    }
  }

  Future<void> _setNotificationPref(bool value) async {
    await DatabaseService.instance
        .setSetting('show_persistent_notification', value ? '1' : '0');
    if (mounted) setState(() => _showPersistentNotification = value);

    // Tell the background service to sync its mode immediately
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('syncNotification');
      }
    } catch (_) {}
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                      child: Row(
                        children: [
                          const AppBackButton(),
                          const Text(
                            'Settings',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
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
                        label: 'Reason Management',
                        subtitle: 'Manage transaction reasons and bank links',
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
                      _toggleTile(
                        icon: Icons.notifications_outlined,
                        iconColor: AppColors.amber,
                        label: 'Status Bar Notification',
                        subtitle: _showPersistentNotification
                            ? 'Shown in status bar'
                            : 'Hidden while active',
                        value: _showPersistentNotification,
                        onChanged: _setNotificationPref,
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
                            icon: Icons.monetization_on_outlined,
                            iconColor: AppColors.positive,
                            label: 'Currency Icon',
                            subtitle: currency.name,
                            onTap: () => _showCurrencyPickerSheet(context, provider),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.positive.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.positive.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CurrencySymbolWidget(
                                        currency: currency,
                                        size: 14,
                                        color: AppColors.positive,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        currency.shortLabel,
                                        style: const TextStyle(
                                          color: AppColors.positive,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
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

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _comingSoon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showCurrencyPickerSheet(BuildContext context, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final currentCode = provider.currentCurrency.code;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161F2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.positive
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
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
}
