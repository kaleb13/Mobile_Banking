import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'backup_restore_screen.dart';
import '../loans/loan_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        backgroundColor: const Color(0xFF0A0B0D),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 20.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Color(0xFF87C0DA), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Preferences & data',
                          style:
                              TextStyle(color: Color(0xFF6B8FA6), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Section: Loans ──────────────────────────────────
              _sectionLabel('Loan Management'),
              _settingsTile(
                context,
                icon: Icons.handshake_outlined,
                iconColor: const Color(0xFF3EB489),
                label: 'Loan Manager',
                subtitle: 'Track money lent & borrowed, set return dates',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoanManagementScreen()),
                ),
              ),

              const SizedBox(height: 8),

              // ── Section: Data ──────────────────────────────────
              _sectionLabel('Data & Storage'),
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
              ),

              const SizedBox(height: 8),

              // ── Section: Appearance ────────────────────────────
              _sectionLabel('Appearance'),
              _settingsTile(
                context,
                icon: Icons.palette_outlined,
                iconColor: const Color(0xFFCE93D8),
                label: 'Theme',
                subtitle: 'Dark mode (default)',
                onTap: () {}, // placeholder
                trailing: _comingSoon(),
              ),
              _settingsTile(
                context,
                icon: Icons.language_outlined,
                iconColor: const Color(0xFF80DEEA),
                label: 'Language',
                subtitle: 'English (default)',
                onTap: () {}, // placeholder
                trailing: _comingSoon(),
              ),

              const SizedBox(height: 8),

              // ── Section: About ─────────────────────────────────
              _sectionLabel('About'),
              _settingsTile(
                context,
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFFFFCC80),
                label: 'App Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
              _settingsTile(
                context,
                icon: Icons.privacy_tip_outlined,
                iconColor: const Color(0xFFA5D6A7),
                label: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: () {}, // placeholder
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.04),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                    ),
                  ),
                ],
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
    );
  }

  Widget _comingSoon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0D739F).withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          color: AppColors.textGray,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
