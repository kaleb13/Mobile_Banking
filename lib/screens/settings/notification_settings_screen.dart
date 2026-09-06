import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../presentation/viewmodels/analytics_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_info_section.dart';
import '../../widgets/app_banner_card.dart';
import '../dashboard/reason_selection_sheet.dart';

/// Compact Notification Settings Detail Screen.
///
/// Houses:
/// 1. Real-Time SMS Listening toggle (default ON).
/// 2. Notification Quick Action Buttons Customization (Slots 1 & 2 + Categorize).
/// 3. Push Notifications Master Switch (OFF by default) & Periodic Summary Reports
///    (Daily, Weekly, and Monthly spending & analysis reports).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _isDismissedInSession = false;

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
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 10),
                    const Text(
                      'Notification Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Consumer<SettingsViewModel>(
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
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── ONBOARDING / TIP BANNER ──
                          if (!settings.isNotifGuideDismissed && !_isDismissedInSession) ...[
                            _buildOnboardingCard(context, settings),
                          ],

                          // ── SECTION 1: REAL-TIME SMS ────────────────────────
                          _sectionHeader('REAL-TIME SMS'),
                          const SizedBox(height: 6),
                          _buildCard([
                            _toggleTile(
                              title: 'Active SMS Detection',
                              subtitle: isSmsListening
                                  ? 'Auto-capture bank SMS & update balance'
                                  : 'Real-time detection paused',
                              value: isSmsListening,
                              onChanged: (val) => settings.setSmsListeningEnabled(val),
                              showDivider: false,
                            ),
                          ]),

                          const SizedBox(height: 16),

                          // ── SECTION 2: BANNER ACTIONS ───────────────────────
                          _sectionHeader('BANNER ACTIONS'),
                          const SizedBox(height: 6),
                          _buildCard([
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

                          // ── SECTION 3: REPORTS & SUMMARIES ──────────────────
                          _sectionHeader('REPORTS & SUMMARIES'),
                          const SizedBox(height: 6),
                          _buildCard([
                            // Master Push Notification Toggle
                            _toggleTile(
                              title: 'Push Reports',
                              subtitle: isPushEnabled
                                  ? 'Daily, weekly & monthly summaries active'
                                  : 'Scheduled periodic financial summaries',
                              value: isPushEnabled,
                              onChanged: (val) => settings.setPushNotificationsEnabled(val),
                              showDivider: isPushEnabled,
                            ),

                            // Periodic Reports Sub-Section (Revealed when Push Notifications is ON)
                            if (isPushEnabled) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                                child: Text(
                                  'SCHEDULED REPORTS',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              _toggleTile(
                                title: 'Daily Summary',
                                subtitle: 'Evening expense update • 8:00 PM',
                                value: isDailyReport,
                                onChanged: (val) => settings.setDailyReportEnabled(val),
                                trailingPillText: 'Test',
                                onTrailingPillPressed: () async {
                                  final totalBal = context.read<AnalyticsViewModel>().totalBalance;
                                  await settings.sendTestReport('daily', totalBalance: totalBal);
                                  if (context.mounted) {
                                    AppToast.success(context, message: 'Daily Summary notification triggered');
                                  }
                                },
                                showDivider: true,
                              ),
                              _toggleTile(
                                title: 'Weekly Report',
                                subtitle: 'Sunday financial review • 8:00 PM',
                                value: isWeeklyReport,
                                onChanged: (val) => settings.setWeeklyReportEnabled(val),
                                trailingPillText: 'Test',
                                onTrailingPillPressed: () async {
                                  final totalBal = context.read<AnalyticsViewModel>().totalBalance;
                                  await settings.sendTestReport('weekly', totalBalance: totalBal);
                                  if (context.mounted) {
                                    AppToast.success(context, message: 'Weekly Report notification triggered');
                                  }
                                },
                                showDivider: true,
                              ),
                              _toggleTile(
                                title: 'Monthly Analysis',
                                subtitle: 'Budget & category overview • 1st, 9:00 AM',
                                value: isMonthlyReport,
                                onChanged: (val) => settings.setMonthlyReportEnabled(val),
                                trailingPillText: 'Test',
                                onTrailingPillPressed: () async {
                                  final totalBal = context.read<AnalyticsViewModel>().totalBalance;
                                  await settings.sendTestReport('monthly', totalBalance: totalBal);
                                  if (context.mounted) {
                                    AppToast.success(context, message: 'Monthly Analysis notification triggered');
                                  }
                                },
                                showDivider: false,
                              ),
                            ],
                          ]),

                          const SizedBox(height: 16),

                          // ── SECTION 4: PRIVACY GUARANTEE INFO SECTION ────────
                          const AppInfoSection(
                            title: 'Offline Processing',
                            description:
                                'All notifications and reports are processed 100% offline on your device.',
                            icon: Icons.info_outline_rounded,
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingCard(BuildContext context, SettingsViewModel settings) {
    return AppBannerCard.onboarding(
      text: 'Assign reasons to transactions directly from incoming SMS banners!',
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onDismiss: () {
        setState(() => _isDismissedInSession = true);
        settings.dismissNotifGuide();
      },
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
      width: double.infinity,
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
    final icon = AppTheme.getCategoryIcon(reasonName);

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
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 18),
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
                      'Banner Button $slotNumber',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
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
              Icon(
                Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.45),
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE BANNER PREVIEW',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
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
    final icon = !isPrimary ? AppTheme.getCategoryIcon(label) : null;

    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.buttonPrimary
            : AppColors.buttonSecondary,
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: AppColors.buttonSecondaryText,
            ),
            const SizedBox(width: 5),
          ],
          Flexible(
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
          ),
        ],
      ),
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? trailingPillText,
    VoidCallback? onTrailingPillPressed,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingPillText != null && onTrailingPillPressed != null) ...[
                const SizedBox(width: 8),
                AppButton.pill(
                  text: trailingPillText,
                  height: 26,
                  fontSize: 11,
                  isSelected: false,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  onPressed: onTrailingPillPressed,
                ),
              ],
              const SizedBox(width: 10),
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
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}
