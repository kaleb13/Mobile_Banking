import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'backup_restore_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';

import '../settings/expense_definitions_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isResetting = false;

  // Helper for grouped cards
  Widget _buildCardBase(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        backgroundColor: const Color(0xFF1F1F25),
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Settings',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3)),
                          Text(
                            'Customize your app experience',
                            style: TextStyle(
                                color: AppColors.textGray, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Section: Financial Logic ────────────────────────
                    _sectionLabel('Core Finance'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.receipt_long_outlined,
                        iconColor: const Color(0xFFF2A900), // Gold
                        label: 'Expense Definitions',
                        subtitle: 'Manage recurring and manual templates',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ExpenseDefinitionsScreen()),
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
                          iconColor: const Color(0xFF64B5F6), // Light blue
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
                                      primary: Color(0xFFF0B90B),
                                      onPrimary: Colors.black,
                                      surface: Color(0xFF2A2A34),
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
                                      color: AppColors.textGray, size: 20),
                                  onPressed: () =>
                                      provider.setCustomMonthAnchorDate(null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : const Icon(Icons.arrow_forward_ios_rounded,
                                  color: AppColors.textGray, size: 14),
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
                        iconColor: const Color(0xFF4FC3F7),
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

                    // ── Section: Cache & Data ──────────────────────────
                    _sectionLabel('Cache & Data'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.refresh_rounded,
                        iconColor: const Color(0xFF4FC3F7),
                        label: 'Smart Refresh',
                        subtitle: 'Rescan SMS, keep your reason tags',
                        showDivider: true,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A34),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Icons.refresh_rounded,
                                      color: Color(0xFF4FC3F7), size: 20),
                                  SizedBox(width: 10),
                                  Text('Smart Refresh',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16)),
                                ],
                              ),
                              content: const Text(
                                'This will:\n\n'
                                '• Keep all transactions that have a reason tag\n'
                                '• Rescan all other messages from SMS\n'
                                '• Restore previous dates for messages without an embedded date\n\n'
                                'Your reason labels and linked transactions are safe.',
                                style: TextStyle(
                                    color: AppColors.textGray, fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel',
                                      style:
                                          TextStyle(color: AppColors.textGray)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Refresh',
                                      style:
                                          TextStyle(color: Color(0xFF4FC3F7))),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            setState(() => _isResetting = true);
                            await context
                                .read<FinanceProvider>()
                                .smartRefresh();
                            if (context.mounted) {
                              setState(() => _isResetting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Smart Refresh complete ✓'),
                                  backgroundColor: Color(0xFF3EB489),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      _settingsTile(
                        context,
                        icon: Icons.delete_sweep_rounded,
                        iconColor: AppColors.alertRed,
                        label: 'Full Reset',
                        subtitle: 'Erase all data & rescan all messages',
                        showDivider: false,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF2A2A34),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: AppColors.alertRed, size: 20),
                                  SizedBox(width: 10),
                                  Text('Full Reset',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16)),
                                ],
                              ),
                              content: const Text(
                                'This will permanently delete:\n\n'
                                '• ALL transactions\n'
                                '• ALL custom reasons and tags\n'
                                '• ALL notifications\n\n'
                                'The app will then rescan all SMS messages from scratch. '
                                'This cannot be undone.',
                                style: TextStyle(
                                    color: AppColors.textGray, fontSize: 13),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel',
                                      style:
                                          TextStyle(color: AppColors.textGray)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Reset Everything',
                                      style: TextStyle(
                                          color: AppColors.alertRed,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            setState(() => _isResetting = true);
                            await context.read<FinanceProvider>().fullReset();
                            if (context.mounted) {
                              setState(() => _isResetting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Full reset complete ✓'),
                                  backgroundColor: Color(0xFF3EB489),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // ── Section: Appearance ────────────────────────────
                    _sectionLabel('Appearance'),
                    _buildCardBase([
                      _settingsTile(
                        context,
                        icon: Icons.palette_outlined,
                        iconColor: const Color(0xFFCE93D8),
                        label: 'Theme',
                        subtitle: 'Dark mode (default)',
                        onTap: () {},
                        trailing: _comingSoon(),
                        showDivider: true,
                      ),
                      _settingsTile(
                        context,
                        icon: Icons.language_outlined,
                        iconColor: const Color(0xFF80DEEA),
                        label: 'Language',
                        subtitle: 'English (default)',
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
                        iconColor: const Color(0xFFFFCC80),
                        label: 'App Version',
                        subtitle: '1.0.0',
                        onTap: () {},
                        showDivider: true,
                      ),
                      _settingsTile(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        iconColor: const Color(0xFFA5D6A7),
                        label: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () {},
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
                      CircularProgressIndicator(color: Color(0xFFF0B90B)),
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
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 32, bottom: 8, top: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textGray,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
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
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.textGray,
                      size: 14,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 16, right: 16),
            color: Colors.white.withOpacity(0.04),
          ),
      ],
    );
  }

  Widget _comingSoon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          color: AppColors.textGray,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
