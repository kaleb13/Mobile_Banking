import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../presentation/viewmodels/auth_view_model.dart';
import '../theme/app_theme.dart';
import '../models/stored_account.dart';
import 'account_sms_mode_drawer.dart';
import 'app_toast.dart';

/// Compact floating modal menu for switching between accounts and adding new ones.
///
/// Positioned floating directly above the bottom navigation bar when long-pressing
/// the Profile Hub nav item. Adheres strictly to design system rules:
/// - Zero borders
/// - Clean dark surface without blur
/// - Compact width (200px) and small height
/// - Only profile pictures, names, active checkmark, and circular "Add account"
/// - No emails, descriptions, or sign out buttons
class ProfileAccountMenuModal extends StatelessWidget {
  final AuthViewModel authVM;

  const ProfileAccountMenuModal({
    super.key,
    required this.authVM,
  });

  /// Static helper to display the menu modal anchored right above the bottom nav bar.
  static Future<void> show(BuildContext context, AuthViewModel authVM) async {
    HapticFeedback.selectionClick();
    final StoredAccount? selectedAccount =
        await showGeneralDialog<StoredAccount>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Profile Menu',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        return ProfileAccountMenuModal(authVM: authVM);
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = Curves.easeOutCubic.transform(anim1.value);
        return Opacity(
          opacity: anim1.value,
          child: Transform.scale(
            scale: 0.94 + (0.06 * curve),
            alignment: const Alignment(0.85, 0.95),
            child: child,
          ),
        );
      },
    );

    if (selectedAccount != null && context.mounted) {
      await AccountSmsModeDrawer.switchAccountWithPrompt(
        context: context,
        authVM: authVM,
        account: selectedAccount,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = context.isLightMode;
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;
    final double modalBottom = bottomPadding + 74.0; // Anchored right above bottom nav bar
    const double modalWidth = 200.0; // Compact popup width

    final List<StoredAccount> accounts = authVM.storedAccounts;
    final StoredAccount? activeAccount = authVM.activeAccount;

    return Stack(
      children: [
        // Tap outside to dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),

        // Anchored Compact Modal Menu Card
        Positioned(
          bottom: modalBottom,
          right: 14.0,
          width: modalWidth,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: isLight ? AppColors.surfaceLight : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.50),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accounts List (Only Avatar, Name, Icon)
                    if (accounts.isEmpty) ...[
                      _buildGuestAccountTile(context, isLight),
                    ] else ...[
                      for (final account in accounts)
                        _buildAccountTile(
                          context: context,
                          account: account,
                          isActive: activeAccount?.userId == account.userId,
                          isLight: isLight,
                        ),
                    ],

                    // Subtle Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Container(
                        height: 1,
                        color: isLight
                            ? AppColors.tabBackgroundLight
                            : AppColors.buttonSecondary,
                      ),
                    ),

                    // Add Account Action Row (Only circular plus icon and "Add account")
                    _buildAddAccountTile(context, isLight),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Single account tile with ONLY avatar, name, and active checkmark icon
  Widget _buildAccountTile({
    required BuildContext context,
    required StoredAccount account,
    required bool isActive,
    required bool isLight,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          if (!isActive) {
            Navigator.of(context).pop(account);
          }
        },
        splashColor: isLight
            ? AppColors.buttonSecondaryOnLight
            : AppColors.buttonSecondary,
        highlightColor: isLight
            ? AppColors.buttonSecondaryOnLight
            : AppColors.buttonSecondary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildAvatar(account, isLight, isActive),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account.displayName,
                  style: AppTypography.bodySmall.copyWith(
                    color: isActive
                        ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                        : (isLight
                            ? AppColors.textSecondaryLight
                            : Colors.white.withValues(alpha: 0.40)),
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Guest account tile
  Widget _buildGuestAccountTile(BuildContext context, bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isLight
                  ? AppColors.cardTileLight
                  : AppColors.buttonSecondary,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 16,
              color: isLight
                  ? AppColors.textSecondaryLight
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Guest',
              style: AppTypography.bodySmall.copyWith(
                color: isLight
                    ? AppColors.textPrimaryLight
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Add account tile: circular plus icon and "Add account" (no descriptions)
  Widget _buildAddAccountTile(BuildContext context, bool isLight) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          Navigator.of(context).pop();
          final success = await authVM.addAccount();
          if (context.mounted) {
            if (success) {
              AppToast.success(context, message: 'Account added');
              await AccountSmsModeDrawer.promptIfUnconfigured(
                context: context,
                authVM: authVM,
              );
            } else if (authVM.errorMessage != null) {
              AppToast.error(
                context,
                message: 'Failed to add account',
                subtitle: authVM.errorMessage,
              );
            }
          }
        },
        splashColor: isLight
            ? AppColors.buttonSecondaryOnLight
            : AppColors.buttonSecondary,
        highlightColor: isLight
            ? AppColors.buttonSecondaryOnLight
            : AppColors.buttonSecondary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLight
                      ? AppColors.cardTileLight
                      : AppColors.buttonSecondary,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 16,
                  color: isLight
                      ? AppColors.textPrimaryLight
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add account',
                  style: AppTypography.bodySmall.copyWith(
                    color: isLight
                        ? AppColors.textPrimaryLight
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds rounded rectangle avatar with image or initial character (28px).
  /// Active account gets a clean white stroke squircle border; inactive account has no stroke.
  Widget _buildAvatar(StoredAccount account, bool isLight, bool isActive) {
    const double size = 28.0;
    final strokeColor = isLight ? AppColors.textPrimaryLight : Colors.white;

    Widget inner;
    if (account.avatarUrl != null && account.avatarUrl!.isNotEmpty) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(isActive ? 9.5 : 12),
        child: Image.network(
          account.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildFallbackInitials(account, isLight, size, isActive),
        ),
      );
    } else {
      inner = _buildFallbackInitials(account, isLight, size, isActive);
    }

    if (isActive) {
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: strokeColor,
            width: 1.6,
          ),
        ),
        child: inner,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: inner,
    );
  }

  Widget _buildFallbackInitials(
      StoredAccount account, bool isLight, double size, bool isActive) {
    final initial = (account.displayName.isNotEmpty
            ? account.displayName[0]
            : (account.email.isNotEmpty ? account.email[0] : 'U'))
        .toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isActive ? 8.5 : 12),
        color: isLight ? AppColors.cardTileLight : AppColors.buttonSecondary,
      ),
      child: Text(
        initial,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.bold,
          color: isActive
              ? (isLight ? AppColors.textPrimaryLight : Colors.white)
              : (isLight
                  ? AppColors.textSecondaryLight
                  : Colors.white.withValues(alpha: 0.50)),
          fontSize: 12,
        ),
      ),
    );
  }
}
