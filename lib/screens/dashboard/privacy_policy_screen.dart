import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F25),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A34),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_outline_rounded,
                            color: AppColors.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Privacy Matters',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Last updated: March 2025',
                              style: TextStyle(
                                color: AppColors.labelGray,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Shibre is built on a single core promise: your financial data never leaves your device.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSection(
              icon: Icons.sms_outlined,
              iconColor: const Color(0xFF64B5F6),
              title: 'SMS Data',
              body:
                  'Shibre reads incoming SMS messages exclusively from your registered banks (CBE, Telebirr, CBE Birr). These messages are processed locally on your device only to extract transaction details such as amount, date, and sender. The raw message content is stored in the app\'s private local database and is never transmitted, uploaded, or shared with any server or third party.',
            ),

            _buildSection(
              icon: Icons.storage_outlined,
              iconColor: const Color(0xFFA5D6A7),
              title: 'Local Storage',
              body:
                  'All your transaction records, reasons, categories, and financial summaries are stored entirely on your device in a local SQLite database. This data exists solely on your phone and is only accessible by the Shibre application.',
            ),

            _buildSection(
              icon: Icons.wifi_off_outlined,
              iconColor: const Color(0xFFCE93D8),
              title: 'No Internet Required',
              body:
                  'Shibre operates fully offline. We do not collect, transmit, or analyze any personal data. There are no user accounts, no cloud sync, and no remote servers. Your data belongs entirely to you.',
            ),

            _buildSection(
              icon: Icons.backup_outlined,
              iconColor: const Color(0xFFF0B90B),
              title: 'Backups',
              body:
                  'When you create a backup, it is saved as a local file directly on your device storage at a location you choose. The backup file is not uploaded anywhere. You are solely responsible for safeguarding any backup files you export.',
            ),

            _buildSection(
              icon: Icons.notifications_none_outlined,
              iconColor: const Color(0xFFFF8A65),
              title: 'Notifications',
              body:
                  'Shibre uses local notifications to alert you of detected transactions and overdue loans. These notifications are generated entirely on-device and do not involve any external notification service or server.',
            ),

            _buildSection(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF4FC3F7),
              title: 'Permissions',
              body:
                  'The app requests SMS read permission to detect bank messages, and storage permission to enable local backup exports. These permissions are used strictly for their stated purposes and are never used to access unrelated data.',
            ),

            _buildSection(
              icon: Icons.child_care_outlined,
              iconColor: AppColors.labelGray,
              title: "Children's Privacy",
              body:
                  'Shibre is not intended for individuals under the age of 13. We do not knowingly collect any data from children.',
            ),

            _buildSection(
              icon: Icons.edit_outlined,
              iconColor: const Color(0xFFA5D6A7),
              title: 'Changes to This Policy',
              body:
                  'We may update this Privacy Policy from time to time. Any changes will be reflected within the app itself. Continued use of Shibre after changes are published constitutes your acceptance of the updated policy.',
            ),

            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.2), width: 1),
              ),
              child: Text(
                'For questions or concerns about this Privacy Policy, contact the developer directly via Telegram: @zkaleb',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A34),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
