import 'package:flutter/material.dart';
import '../../../models/app_notification.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_back_button.dart';
import '../../../widgets/app_button.dart';

import '../../../widgets/app_drawer.dart';

class NotificationOptionsSheet extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onClose;
  final VoidCallback onManualInsert;
  final VoidCallback onIgnore;

  const NotificationOptionsSheet({
    super.key,
    required this.notification,
    required this.onClose,
    required this.onManualInsert,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final isSystem = notification.sender.startsWith('Loan') ||
        notification.sender.startsWith('System');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.sheetRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Message Options',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppBackButton.dark(onPressed: onClose),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isSystem) ...[
                  AppDrawerActionTile(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Insert Transaction Manually',
                    subtitle: 'Create a custom record from this SMS',
                    onTap: onManualInsert,
                  ),
                ],
                AppDrawerActionTile(
                  icon: Icons.block_rounded,
                  title: 'Ignore Message',
                  subtitle: 'Dismiss permanently from notifications',
                  onTap: onIgnore,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class NotificationConfirmationDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final bool isDestructive;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const NotificationConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.isDestructive = false,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: onCancel,
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.dialogRadius,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.left,
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.left,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.secondary(
                            text: 'Cancel',
                            height: 42,
                            onPressed: onCancel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: isDestructive
                              ? AppButton.destructive(
                                  text: confirmLabel,
                                  height: 42,
                                  onPressed: onConfirm,
                                )
                              : AppButton.primary(
                                  text: confirmLabel,
                                  height: 42,
                                  onPressed: onConfirm,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SendToDeveloperSheet extends StatelessWidget {
  final int count;
  final String bankFilter;
  final VoidCallback onClose;
  final VoidCallback onConfirmSend;
  final VoidCallback? onOpenDirectChat;
  final bool isExporting;

  const SendToDeveloperSheet({
    super.key,
    required this.count,
    required this.bankFilter,
    required this.onClose,
    required this.onConfirmSend,
    this.onOpenDirectChat,
    this.isExporting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.sheetRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.skyBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.telegram_rounded,
                  color: AppColors.skyBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Send to Developer',
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppBackButton.dark(onPressed: onClose),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Help improve Shibre banking parser by sharing unrecognized messages with developer @zkaleb.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.positive,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Zero personal data or credentials collected. Only raw SMS patterns will be exported ($count messages${bankFilter != 'All' ? ' for $bankFilter' : ''}).',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppButton.primary(
            text: isExporting ? 'Preparing File...' : 'Export & Share Report',
            icon: Icons.send_rounded,
            isLoading: isExporting,
            onPressed: isExporting ? null : onConfirmSend,
          ),
          if (onOpenDirectChat != null) ...[
            const SizedBox(height: 10),
            AppButton.secondary(
              text: 'Open @zkaleb on Telegram',
              icon: Icons.open_in_new_rounded,
              onPressed: onOpenDirectChat,
            ),
          ],
        ],
      ),
    );
  }
}
