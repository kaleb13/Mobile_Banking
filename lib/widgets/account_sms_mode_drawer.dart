import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/stored_account.dart';
import '../theme/app_theme.dart';
import '../presentation/viewmodels/auth_view_model.dart';
import 'app_drawer.dart';
import 'app_button.dart';
import 'app_badges.dart';
import 'app_toast.dart';

/// Standardized AppDrawer that lets the user choose whether an account
/// should ingest local device SMS or operate in Cloud-Only mode upon switching.
/// Adheres strictly to design system rules: zero borders, 100% rounded pill button,
/// squircle avatar, and solid non-transparent surfaces.
class AccountSmsModeDrawer extends StatefulWidget {
  final StoredAccount account;

  const AccountSmsModeDrawer({
    super.key,
    required this.account,
  });

  /// Displays the drawer using the standardized [AppDrawer.show] pattern.
  /// Returns `true` for Device SMS, `false` for Cloud-Only, or `null` if dismissed.
  static Future<bool?> show({
    required BuildContext context,
    required StoredAccount account,
  }) {
    return AppDrawer.show<bool>(
      context: context,
      builder: (ctx) => AccountSmsModeDrawer(account: account),
    );
  }

  /// Coordinates switching to [account] with first-time mode selection if not yet configured.
  /// If [account.hasConfiguredSmsMode] is false, presents [AccountSmsModeDrawer] once.
  /// On all subsequent switches, immediately switches using the remembered [account.syncDeviceSms] state.
  static Future<bool> switchAccountWithPrompt({
    required BuildContext context,
    required AuthViewModel authVM,
    required StoredAccount account,
  }) async {
    bool chosenMode = account.syncDeviceSms;

    // Only show drawer if SMS mode has NOT yet been configured on this device
    if (!account.hasConfiguredSmsMode) {
      final selected = await AccountSmsModeDrawer.show(
        context: context,
        account: account,
      );
      if (selected == null) return false; // Cancelled
      chosenMode = selected;
    }

    final success = await authVM.switchAccount(
      account.userId,
      syncDeviceSms: chosenMode,
    );

    if (context.mounted) {
      if (success) {
        AppToast.success(
          context,
          message: 'Switched to ${account.displayName}',
          subtitle: chosenMode ? 'Reading device SMS' : 'Cloud-only mode',
        );
      } else {
        AppToast.error(context, message: 'Failed to switch account');
      }
    }

    return success;
  }

  /// Prompts the user to configure SMS mode if [authVM.activeAccount] has not yet
  /// configured its SMS mode on this physical device.
  /// If this device has logged into this account before, it immediately returns true without showing any UI.
  static Future<bool> promptIfUnconfigured({
    required BuildContext context,
    required AuthViewModel authVM,
  }) async {
    final account = authVM.activeAccount;
    if (account == null) return false;
    if (account.hasConfiguredSmsMode) return true;

    final selected = await AccountSmsModeDrawer.show(
      context: context,
      account: account,
    );
    if (selected == null) return false;

    await authVM.updateActiveAccountSyncDeviceSms(selected);
    if (context.mounted) {
      AppToast.info(
        context,
        message: 'SMS Mode Configured',
        subtitle: selected ? 'Reading device SMS' : 'Cloud-only mode',
      );
    }
    return true;
  }

  @override
  State<AccountSmsModeDrawer> createState() => _AccountSmsModeDrawerState();
}

class _AccountSmsModeDrawerState extends State<AccountSmsModeDrawer> {
  late bool _syncDeviceSms;

  @override
  void initState() {
    super.initState();
    _syncDeviceSms = widget.account.syncDeviceSms;
  }

  Widget _buildAvatar() {
    final name = widget.account.displayName;
    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : 'U';

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.tabBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: widget.account.avatarUrl != null &&
              widget.account.avatarUrl!.isNotEmpty
          ? Image.network(
              widget.account.avatarUrl!,
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitials(initials),
            )
          : _buildInitials(initials),
    );
  }

  Widget _buildInitials(String initials) {
    return Text(
      initials,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildModeOptionCard({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : AppColors.tabBackground,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left icon container (Solid, zero borders)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.surfaceElevated
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Title + subtitle + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      AppBadge.neutral(text: badgeText),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Selection indicator (zero stroke, solid circle/dot)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.buttonPrimary
                    : AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: AppColors.buttonPrimaryText,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawer(
      isBodyScrollable: false,
      backgroundColor: AppColors.surfaceElevated,
      headerCard: AppDrawerHeaderCard(
        leading: _buildAvatar(),
        title: 'Switch to ${widget.account.displayName}',
      ),
      bottomAction: SizedBox(
        width: double.infinity,
        child: AppButton.primary(
          text: 'Confirm & Switch',
          onPressed: () {
            Navigator.of(context).pop(_syncDeviceSms);
          },
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Select how this account should handle SMS on this device:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          _buildModeOptionCard(
            isSelected: _syncDeviceSms,
            icon: Icons.phonelink_ring_rounded,
            title: 'Track Device SMS',
            subtitle:
                'Reads and auto-detects banking SMS from this phone\'s SIM cards into this account.',
            badgeText: 'PRIMARY DEVICE',
            onTap: () => setState(() => _syncDeviceSms = true),
          ),
          const SizedBox(height: 10),
          _buildModeOptionCard(
            isSelected: !_syncDeviceSms,
            icon: Icons.cloud_outlined,
            title: 'Cloud Only',
            subtitle:
                'Does not read SMS on this phone. Transactions sync strictly from cloud backup.',
            badgeText: 'CLOUD VIEWER',
            onTap: () => setState(() => _syncDeviceSms = false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
