import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.themeBackground,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 12),
                  Text(
                    'Privacy Policy',
                    style: AppTypography.heading1.copyWith(
                      color: context.themeTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header banner card
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: AppRadius.card,
                      customColor: context.themeSurface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Privacy Matters',
                            style: AppTypography.heading2.copyWith(
                              color: context.themeTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last updated: March 2026',
                            style: AppTypography.caption.copyWith(
                              color: context.themeTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Shibre is built on a single core promise: your financial data never leaves your device.',
                            style: AppTypography.bodySmall.copyWith(
                              color: context.themeTextSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSection(
                      context,
                      title: 'SMS Data & Processing',
                      body:
                          'Shibre reads incoming SMS messages exclusively from your supported banks (Telebirr, Commercial Bank of Ethiopia, CBE Birr, Ahadu Bank, Bank of Abyssinia, Dashen Bank, Awash Bank, Zemen Bank, Nib Bank, and any custom senders you configure). These messages are parsed locally on your device in real-time to extract transaction details (amount, date, balance, and reference). Your raw SMS content is stored in the app\'s private local database and is never transmitted, uploaded, or shared with any external server or third party.',
                    ),

                    _buildSection(
                      context,
                      title: '100% Local Storage',
                      body:
                          'All your transaction records, notes, spending categories, reasons, and financial analytics are stored entirely on your device in a private SQLite database. This data resides solely on your phone and is only accessible by the Shibre application.',
                    ),

                    _buildSection(
                      context,
                      title: 'Zero Cloud & Offline Architecture',
                      body:
                          'Shibre operates fully offline. We do not collect, track, or analyze your financial data. There are no remote tracking services, no cloud sync servers, and no user accounts required. Your financial privacy is complete and entirely under your own control.',
                    ),

                    _buildSection(
                      context,
                      title: 'Biometric & Device Lock',
                      body:
                          'To protect your financial information from unauthorized physical access, Shibre supports biometric authentication (Fingerprint / Face ID) and device PIN lock. Authentication is handled directly by Android\'s secure biometric hardware.',
                    ),

                    _buildSection(
                      context,
                      title: 'Local Backups & Data Control',
                      body:
                          'When you export a backup, an encrypted local file is created on your device storage at a location you choose. You can also permanently delete individual transactions, purge unhandled SMS logs, or perform a full factory reset of all data at any time from the app settings.',
                    ),

                    _buildSection(
                      context,
                      title: 'On-Device Notifications',
                      body:
                          'Shibre uses local Android notifications to alert you when a new banking SMS is detected or when a periodic spending summary is scheduled. These alerts are generated locally by your device without involving external push servers.',
                    ),

                    _buildSection(
                      context,
                      title: 'Android Permissions',
                      body:
                          'Shibre requests SMS read permission solely to detect banking transactions, notification permission to show instant spending alerts, and storage access when exporting backups. These permissions are strictly confined to these core financial tracking features.',
                    ),

                    _buildSection(
                      context,
                      title: 'Policy Updates',
                      body:
                          'Any updates to this Privacy Policy will be reflected directly within the application. Continued use of Shibre after updates are published constitutes your acceptance of the policy.',
                    ),

                    const SizedBox(height: 8),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: AppRadius.card,
                      customColor: AppColors.surfaceElevated,
                      child: Center(
                        child: Text(
                          'For questions or concerns about this Privacy Policy, contact the developer directly via Telegram: @Shi_bre',
                          style: AppTypography.bodySmall.copyWith(
                            color: context.themeTextSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        borderRadius: AppRadius.card,
        customColor: context.themeSurface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.heading2.copyWith(
                color: context.themeTextPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: AppTypography.bodySmall.copyWith(
                color: context.themeTextSecondary,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
