import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 10),
                  const Text(
                    'Privacy Policy',
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
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.cardRadius,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Privacy Matters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Last updated: March 2025',
                            style: TextStyle(
                              color: AppColors.textSoft,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Shibre is built on a single core promise: your financial data never leaves your device.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildSection(
                      title: 'SMS Data & Processing',
                      body:
                          'Shibre reads incoming SMS messages exclusively from your supported banks (Telebirr, Commercial Bank of Ethiopia, CBE Birr, Ahadu Bank, Bank of Abyssinia, Dashen Bank, and any custom senders you configure). These messages are parsed locally on your device in real-time to extract transaction details (amount, date, balance, and reference). Your raw SMS content is stored in the app\'s private local database and is never transmitted, uploaded, or shared with any external server or third party.',
                    ),

                    _buildSection(
                      title: '100% Local Storage',
                      body:
                          'All your transaction records, notes, spending categories, reasons, and financial analytics are stored entirely on your device in a private SQLite database. This data resides solely on your phone and is only accessible by the Shibre application.',
                    ),

                    _buildSection(
                      title: 'Zero Cloud & Offline Architecture',
                      body:
                          'Shibre operates fully offline. We do not collect, track, or analyze your financial data. There are no remote tracking services, no cloud sync servers, and no user accounts required. Your financial privacy is complete and entirely under your own control.',
                    ),

                    _buildSection(
                      title: 'Biometric & Device Lock',
                      body:
                          'To protect your financial information from unauthorized physical access, Shibre supports biometric authentication (Fingerprint / Face ID) and device PIN lock. Authentication is handled directly by Android\'s secure biometric hardware.',
                    ),

                    _buildSection(
                      title: 'Local Backups & Data Control',
                      body:
                          'When you export a backup, an encrypted local file is created on your device storage at a location you choose. You can also permanently delete individual transactions, purge unhandled SMS logs, or perform a full factory reset of all data at any time from the app settings.',
                    ),

                    _buildSection(
                      title: 'On-Device Notifications',
                      body:
                          'Shibre uses local Android notifications to alert you when a new banking SMS is detected or when a loan reminder is due. These alerts are generated locally by your device without involving external push servers.',
                    ),

                    _buildSection(
                      title: 'Android Permissions',
                      body:
                          'Shibre requests SMS read permission solely to detect banking transactions, notification permission to show instant spending alerts, and storage access when exporting backups. These permissions are strictly confined to these core financial tracking features.',
                    ),

                    _buildSection(
                      title: 'Policy Updates',
                      body:
                          'Any updates to this Privacy Policy will be reflected directly within the application. Continued use of Shibre after updates are published constitutes your acceptance of the policy.',
                    ),

                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.08),
                        borderRadius: AppRadius.cardRadius,
                      ),
                      child: Text(
                        'For questions or concerns about this Privacy Policy, contact the developer directly via Telegram: @Shi_bre',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildSection({
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
