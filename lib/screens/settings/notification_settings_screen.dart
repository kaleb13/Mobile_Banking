import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

/// Compact Notification Settings Detail Screen.
///
/// Houses:
/// 1. Real-Time SMS Listening toggle (default ON).
/// 2. Push Notifications Master Switch (OFF by default) & Periodic Summary Reports
///    (Daily, Weekly, and Monthly spending & analysis reports).
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

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
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          title: const Text(
            'Notification Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.background.withValues(alpha: 0.85),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const AppBackButton(),
        ),
        body: Consumer<FinanceProvider>(
          builder: (context, provider, _) {
            final isSmsListening = provider.isSmsListeningEnabled;
            final isPushEnabled = provider.isPushNotificationsEnabled;
            final isDailyReport = provider.isDailyReportEnabled;
            final isWeeklyReport = provider.isWeeklyReportEnabled;
            final isMonthlyReport = provider.isMonthlyReportEnabled;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── SECTION 1: REAL-TIME SMS LISTENING ─────────────────
                  _sectionHeader('REAL-TIME LISTENING'),
                  const SizedBox(height: 6),
                  _buildCard([
                    _toggleTile(
                      icon: isSmsListening
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_rounded,
                      iconColor: isSmsListening
                          ? AppColors.positive
                          : AppColors.textSoft,
                      title: 'Active SMS Listening',
                      subtitle: isSmsListening
                          ? 'Capturing bank SMS & auto-refreshing in real time'
                          : 'Real-time SMS detection & notifications turned off',
                      value: isSmsListening,
                      onChanged: (val) => provider.setSmsListeningEnabled(val),
                      showDivider: false,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── SECTION 2: PUSH NOTIFICATIONS & REPORTS ───────────
                  _sectionHeader('PUSH NOTIFICATIONS & REPORTS'),
                  const SizedBox(height: 6),
                  _buildCard([
                    // Master Push Notification Toggle (OFF by default!)
                    _toggleTile(
                      icon: isPushEnabled
                          ? Icons.mark_email_unread_rounded
                          : Icons.notifications_none_rounded,
                      iconColor: isPushEnabled
                          ? AppColors.positive
                          : AppColors.textSoft,
                      title: 'Push Notifications',
                      subtitle: isPushEnabled
                          ? 'Push notifications and scheduled reports are active'
                          : 'Off by default. Enable to receive push reports',
                      value: isPushEnabled,
                      onChanged: (val) => provider.setPushNotificationsEnabled(val),
                      showDivider: isPushEnabled,
                    ),

                    // Periodic Reports Sub-Section (Revealed when Push Notifications is ON)
                    if (isPushEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.analytics_outlined,
                              color: AppColors.textSecondary,
                              size: 13,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PERIODIC SUMMARY REPORTS',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _toggleTile(
                        icon: Icons.today_rounded,
                        iconColor: AppColors.positive,
                        title: 'Daily Spending Summary',
                        subtitle: 'Evening push update of expenses & balance',
                        value: isDailyReport,
                        onChanged: (val) => provider.setDailyReportEnabled(val),
                        showDivider: true,
                      ),
                      _toggleTile(
                        icon: Icons.date_range_rounded,
                        iconColor: AppColors.positive,
                        title: 'Weekly Financial Report',
                        subtitle: 'End-of-week breakdown of income vs expenses',
                        value: isWeeklyReport,
                        onChanged: (val) => provider.setWeeklyReportEnabled(val),
                        showDivider: true,
                      ),
                      _toggleTile(
                        icon: Icons.calendar_month_rounded,
                        iconColor: AppColors.positive,
                        title: 'Monthly Spending Analysis',
                        subtitle: 'Monthly categorization, budget & trend analysis',
                        value: isMonthlyReport,
                        onChanged: (val) => provider.setMonthlyReportEnabled(val),
                        showDivider: false,
                      ),
                    ],
                  ]),

                  const SizedBox(height: 14),

                  // Compact Info Note Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.privacy_tip_outlined,
                          color: AppColors.positive,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All push reports are generated 100% offline on your device.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppSwitch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
            indent: 58,
          ),
      ],
    );
  }
}
