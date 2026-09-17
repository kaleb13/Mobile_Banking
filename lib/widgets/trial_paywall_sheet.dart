import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../presentation/viewmodels/auth_view_model.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_card.dart';

/// Modal paywall shown when a device's 30-day trial has elapsed or device is restricted.
/// 
/// Strictly adheres to the zero-border / 100% rounded pill button design system rules.
class TrialPaywallSheet extends StatelessWidget {
  const TrialPaywallSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TrialPaywallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();

    return PopScope(
      canPop: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: context.themeBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.themeTextSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Glowing Shield Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: AppColors.brandGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Free Trial Completed',
                style: AppTypography.heading1.copyWith(
                  color: context.themeTextPrimary,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                'The 30-day trial for this device (${authVM.deviceModel}) has expired. Sign in with Google to restore your subscription or activate Shibre Pro.',
                style: AppTypography.bodySmall.copyWith(
                  color: context.themeTextSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Feature benefits card
              AppCard(
                padding: const EdgeInsets.all(16),
                customColor: context.themeSurface,
                borderRadius: AppRadius.card,
                child: Column(
                  children: [
                    _buildFeatureRow(context, Icons.flash_on_rounded, 'Real-time SMS banking detection'),
                    const SizedBox(height: 12),
                    _buildFeatureRow(context, Icons.bar_chart_rounded, 'Advanced monthly spending analytics'),
                    const SizedBox(height: 12),
                    _buildFeatureRow(context, Icons.sync_rounded, 'Multi-device cloud backup & sync'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action: Google Sign-In (Crisp White Pill)
              AppButton.primary(
                text: authVM.isLoading ? 'Signing In...' : 'Sign In with Google',
                icon: Icons.login_rounded,
                onPressed: authVM.isLoading
                    ? null
                    : () async {
                        final success = await authVM.signInWithGoogle();
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
              ),
              const SizedBox(height: 12),

              // Secondary Action: Telegram Support (Translucent Glass Pill)
              AppButton.secondary(
                text: 'Contact Developer (@Shi_bre)',
                onPressed: () async {
                  final uri = Uri.parse('https://t.me/Shi_bre');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.brandGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: context.themeTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
