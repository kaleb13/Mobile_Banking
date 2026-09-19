import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/account_device_session.dart';
import '../presentation/viewmodels/auth_view_model.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_badges.dart';
import 'app_confirm_dialog.dart';
import 'app_toast.dart';

/// Bottom sheet displaying detailed session metadata for a logged-in hardware device.
/// Allows the user to terminate remote sessions.
class DeviceSessionDetailSheet extends StatelessWidget {
  final AccountDeviceSession session;
  final AuthViewModel authVM;

  const DeviceSessionDetailSheet({
    super.key,
    required this.session,
    required this.authVM,
  });

  static Future<void> show({
    required BuildContext context,
    required AccountDeviceSession session,
    required AuthViewModel authVM,
  }) {
    HapticFeedback.selectionClick();
    return AppBottomSheet.show(
      context: context,
      builder: (_) => DeviceSessionDetailSheet(
        session: session,
        authVM: authVM,
      ),
    );
  }

  IconData _getDeviceIcon(String platform, String model) {
    final m = model.toLowerCase();
    if (m.contains('tablet') || m.contains('ipad')) {
      return Icons.tablet_mac_rounded;
    } else if (m.contains('desktop') || m.contains('windows') || m.contains('mac')) {
      return Icons.laptop_mac_rounded;
    }
    return Icons.phone_android_rounded;
  }

  void _confirmTerminate(BuildContext context) {
    HapticFeedback.selectionClick();
    AppConfirmDialog.show(
      context: context,
      title: 'Terminate Session',
      message:
          'Are you sure you want to log out of ${session.deviceModel}? This device will lose access to your account until signed in again.',
      confirmText: 'Terminate',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () async {
        final navigator = Navigator.of(context);
        final success =
            await authVM.terminateDeviceSession(session.deviceFingerprint);
        if (context.mounted) {
          navigator.pop();
          if (success) {
            AppToast.success(
              context,
              message: 'Session Terminated',
              subtitle: 'Signed out ${session.deviceModel}',
            );
          } else {
            AppToast.error(context, message: 'Failed to terminate session');
          }
        }
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tabBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (trailing != null)
            trailing
          else
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fingerprintSnippet = session.deviceFingerprint.length > 16
        ? '${session.deviceFingerprint.substring(0, 8)}...${session.deviceFingerprint.substring(session.deviceFingerprint.length - 6)}'
        : session.deviceFingerprint;

    final formattedCreated = session.createdAt != null
        ? DateFormat('MMMM d, yyyy').format(session.createdAt!.toLocal())
        : 'Unknown';

    final formattedLastActive =
        DateFormat('MMM d, yyyy • HH:mm').format(session.lastUsedAt.toLocal());

    return AppBottomSheet(
      title: 'Device Details',
      icon: _getDeviceIcon(session.platform, session.deviceModel),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card with Device Icon and Status Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.tabBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _getDeviceIcon(session.platform, session.deviceModel),
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.deviceModel,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.platform} • ${session.formattedLastSeen}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (session.isCurrentDevice)
                  const AppBadge.success(
                    text: 'THIS DEVICE',
                    size: AppBadgeSize.micro,
                  )
                else if (session.isInactive)
                  const AppBadge.neutral(
                    text: 'INACTIVE',
                    size: AppBadgeSize.micro,
                  )
                else
                  const AppBadge.success(
                    text: 'ACTIVE',
                    size: AppBadgeSize.micro,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Metadata Details List
          _buildInfoRow('Status', session.isCurrentDevice ? 'Online Now' : session.formattedLastSeen),
          const SizedBox(height: 8),
          _buildInfoRow('Platform', session.platform),
          const SizedBox(height: 8),
          _buildInfoRow('Last Active', formattedLastActive),
          const SizedBox(height: 8),
          _buildInfoRow('First Connected', formattedCreated),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Hardware Signature',
            fingerprintSnippet,
            trailing: Text(
              fingerprintSnippet,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Action Button
          if (session.isCurrentDevice)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tabBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                'This is your current physical device.\nTo sign out, use the Sign Out button in your Profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            )
          else
            AppButton.destructive(
              text: 'Terminate Session',
              icon: Icons.delete_outline_rounded,
              fullWidth: true,
              height: 46,
              onPressed: () => _confirmTerminate(context),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
