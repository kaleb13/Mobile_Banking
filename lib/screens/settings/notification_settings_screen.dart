import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../dashboard/reason_selection_sheet.dart';

/// Compact Notification Settings Detail Screen.
///
/// Houses:
/// 1. Real-Time SMS Listening toggle (default ON).
/// 2. Notification Quick Action Buttons Customization (Slots 1 & 2 + Categorize).
/// 3. Push Notifications Master Switch (OFF by default) & Periodic Summary Reports
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
          titleSpacing: 10,
          leadingWidth: 48,
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
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: AppBackButton(),
          ),
        ),
        body: Consumer<SettingsViewModel>(
          builder: (context, settings, _) {
            final isSmsListening = settings.isSmsListeningEnabled;
            final isPushEnabled = settings.isPushNotificationsEnabled;
            final isDailyReport = settings.isDailyReportEnabled;
            final isWeeklyReport = settings.isWeeklyReportEnabled;
            final isMonthlyReport = settings.isMonthlyReportEnabled;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
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
                      onChanged: (val) => settings.setSmsListeningEnabled(val),
                      showDivider: false,
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── SECTION 2: NOTIFICATION QUICK BUTTONS ──────────────
                  _sectionHeader('SMS NOTIFICATION ACTION BUTTONS'),
                  const SizedBox(height: 6),
                  _buildCard([
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Text(
                        'Customize the 2 one-tap reason buttons that appear on incoming SMS notification banners. The 3rd button is always "Categorize".',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                    _quickButtonSlotTile(
                      context: context,
                      slotNumber: 1,
                      reasonName: settings.notifQuickButton1,
                      onChanged: (newReason) => settings.setNotifQuickButton1(newReason),
                      showDivider: true,
                    ),
                    _quickButtonSlotTile(
                      context: context,
                      slotNumber: 2,
                      reasonName: settings.notifQuickButton2,
                      onChanged: (newReason) => settings.setNotifQuickButton2(newReason),
                      showDivider: false,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: _buildBannerPreview(settings),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // ── SECTION 3: PUSH NOTIFICATIONS & REPORTS ───────────
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
                      onChanged: (val) => settings.setPushNotificationsEnabled(val),
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
                        onChanged: (val) => settings.setDailyReportEnabled(val),
                        showDivider: true,
                      ),
                      _toggleTile(
                        icon: Icons.date_range_rounded,
                        iconColor: AppColors.positive,
                        title: 'Weekly Financial Report',
                        subtitle: 'End-of-week breakdown of income vs expenses',
                        value: isWeeklyReport,
                        onChanged: (val) => settings.setWeeklyReportEnabled(val),
                        showDivider: true,
                      ),
                      _toggleTile(
                        icon: Icons.calendar_month_rounded,
                        iconColor: AppColors.positive,
                        title: 'Monthly Spending Analysis',
                        subtitle: 'Monthly categorization, budget & trend analysis',
                        value: isMonthlyReport,
                        onChanged: (val) => settings.setMonthlyReportEnabled(val),
                        showDivider: false,
                      ),
                    ],
                  ]),

                  const SizedBox(height: 14),

                  // Compact Info Note Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
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
                            'All push reports and notifications are processed 100% offline on your device.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _quickButtonSlotTile({
    required BuildContext context,
    required int slotNumber,
    required String reasonName,
    required ValueChanged<String> onChanged,
    bool showDivider = false,
  }) {
    final icon = _getReasonIcon(reasonName);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.positive, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reasonName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Button $slotNumber on notification banner',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppButton.pill(
                text: 'Change',
                height: 28,
                fontSize: 11.5,
                isSelected: false,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onPressed: () {
                  AppBottomSheet.show(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ReasonSelectionSheet(
                      onReasonSelected: (selectedReason) {
                        onChanged(selectedReason.name);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
            indent: 62,
          ),
      ],
    );
  }

  Widget _buildBannerPreview(SettingsViewModel settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.preview_rounded,
                color: AppColors.textSecondary,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                'NOTIFICATION BANNER PREVIEW',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionPill(
                  settings.notifQuickButton1,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionPill(
                  settings.notifQuickButton2,
                  isPrimary: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionPill(
                  'Categorize',
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill(String label, {required bool isPrimary}) {
    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.buttonPrimary
            : AppColors.buttonSecondary,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isPrimary
              ? AppColors.buttonPrimaryText
              : AppColors.buttonSecondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _getReasonIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('food') || lower.contains('restaurant') || lower.contains('dining') || lower.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('good') || lower.contains('shopping') || lower.contains('market') || lower.contains('grocer')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('fuel') || lower.contains('gas') || lower.contains('transport') || lower.contains('taxi') || lower.contains('ride')) {
      return Icons.local_gas_station_rounded;
    }
    if (lower.contains('rent') || lower.contains('house') || lower.contains('home')) {
      return Icons.home_rounded;
    }
    if (lower.contains('util') || lower.contains('electric') || lower.contains('water') || lower.contains('bill')) {
      return Icons.receipt_long_rounded;
    }
    if (lower.contains('health') || lower.contains('med') || lower.contains('doctor') || lower.contains('pharmacy')) {
      return Icons.medical_services_rounded;
    }
    if (lower.contains('entertain') || lower.contains('fun') || lower.contains('movie')) {
      return Icons.movie_rounded;
    }
    if (lower.contains('airtime') || lower.contains('phone') || lower.contains('internet')) {
      return Icons.phone_android_rounded;
    }
    return Icons.category_rounded;
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
