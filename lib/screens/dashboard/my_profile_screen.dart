import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../presentation/viewmodels/auth_view_model.dart';
import '../../presentation/viewmodels/analytics_view_model.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../models/stored_account.dart';
import '../../models/account_device_session.dart';
import '../../widgets/widgets.dart';

/// Full-page My Profile screen for managing user identity, Google accounts,
/// Cloud Sync session, and multi-account switching.
/// Adheres strictly to design system Rule 7: All cards stretch the full width of the screen.
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthViewModel>();
        auth.syncSubscription();
        if (auth.isAuthenticated) {
          auth.loadAccountDevices();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildInitials(String name, bool isLight, double fontSize) {
    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(' ')
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : 'U';
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: isLight ? AppColors.textPrimaryLight : Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _promptAddAccount(BuildContext context, AuthViewModel authVM) {
    HapticFeedback.selectionClick();
    if (authVM.isAuthenticated) {
      AppConfirmDialog.show(
        context: context,
        title: 'Add Another Account',
        message:
            'Would you like to connect an additional Google account to this device for multi-account switching?',
        confirmText: 'Add Account',
        cancelText: 'Cancel',
        onConfirm: () => _handleAddAccount(context, authVM),
      );
    } else {
      AppConfirmDialog.show(
        context: context,
        title: 'Sign In with Google',
        message:
            'Would you like to sign in with your Google account to enable multi-account access and cloud sync?',
        confirmText: 'Sign In',
        cancelText: 'Cancel',
        onConfirm: () => _handleGoogleSignIn(context, authVM),
      );
    }
  }

  Future<void> _handleAddAccount(
      BuildContext context, AuthViewModel authVM) async {
    final success = await authVM.addAccount();
    if (context.mounted) {
      if (success) {
        AppToast.success(
          context,
          message: 'Account Added',
          subtitle: authVM.email ?? 'Connected new Google account',
        );
        await AccountSmsModeDrawer.promptIfUnconfigured(
          context: context,
          authVM: authVM,
        );
      } else if (authVM.errorMessage != null) {
        AppToast.error(
          context,
          message: 'Failed to Add Account',
          subtitle: authVM.errorMessage,
        );
      }
    }
  }

  void _confirmSignOut(BuildContext context, AuthViewModel authVM) {
    HapticFeedback.selectionClick();
    AppConfirmDialog.show(
      context: context,
      title: 'Sign Out',
      message:
          'Are you sure you want to sign out? Your offline data will remain preserved, and you can sign back in anytime.',
      confirmText: 'Sign Out',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () => _handleSignOut(context, authVM),
    );
  }

  Future<void> _handleSignOut(
      BuildContext context, AuthViewModel authVM) async {
    await authVM.signOut();
    if (context.mounted) {
      AppToast.info(
        context,
        message: 'Signed Out',
        subtitle: 'Switched to offline guest mode',
      );
    }
  }

  Future<void> _handleGoogleSignIn(
      BuildContext context, AuthViewModel authVM) async {
    final success = await authVM.signInWithGoogle();
    if (context.mounted) {
      if (success) {
        AppToast.success(
          context,
          message: 'Signed in with Google',
          subtitle: authVM.email ?? 'Welcome to Shibre Cloud',
        );
        await AccountSmsModeDrawer.promptIfUnconfigured(
          context: context,
          authVM: authVM,
        );
      } else if (authVM.errorMessage != null) {
        AppToast.error(
          context,
          message: 'Sign In Failed',
          subtitle: authVM.errorMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLightMode;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          systemNavigationBarIconBrightness:
              isLight ? Brightness.dark : Brightness.light,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: isLight
                ? const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.backgroundLight,
                      AppColors.bgMidLight,
                    ],
                  )
                : AppColors.screenBackgroundGradient,
          ),
          child: Consumer3<AuthViewModel, AnalyticsViewModel,
              TransactionsViewModel>(
            builder: (context, authVM, analyticsVM, txVM, _) {
              final bool isAuth = authVM.isAuthenticated;
              final List<StoredAccount> accounts = authVM.storedAccounts;
              final int smsCount = txVM.transactionCount;
              final String formattedSmsCount =
                  NumberFormat('#,##0').format(smsCount);
              final String activeName = authVM.displayName ??
                  (isAuth ? 'Shibre User' : 'Guest Profile');
              final String? activeAvatar = authVM.avatarUrl;

              return Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Unified Top Profile Hero Section (Single section at top matching Loan Tracker & Profile Hub)
                        _buildTopHeroSection(
                          context,
                          authVM,
                          analyticsVM,
                          isLight,
                        ),

                        const SizedBox(height: 16),

                        // 2. Connected Accounts Multi-Account Switcher (Full Width)
                        if (isAuth && accounts.isNotEmpty) ...[
                          _buildConnectedAccountsSection(
                            context,
                            authVM,
                            accounts,
                            isLight,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 3. Logged-in Devices Section (Full Width)
                        if (isAuth) ...[
                          _buildDevicesSection(
                            context,
                            authVM,
                            isLight,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 4. Security & Cloud Synchronization Card (Full Width)
                        _buildSecurityCard(
                          context,
                          isAuth,
                          formattedSmsCount,
                          isLight,
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),

                  // Pinned Collapsing Header Bar on Scroll
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AppScrollHeaderBar(
                      scrollController: _scrollController,
                      mode: AppScrollHeaderMode.revealOnScroll,
                      title: activeName,
                      icon: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: isLight
                              ? AppColors.surfaceLight
                              : AppColors.surface,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: activeAvatar != null &&
                                  activeAvatar.isNotEmpty
                              ? Image.network(
                                  activeAvatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildInitials(activeName, isLight, 10),
                                )
                              : _buildInitials(activeName, isLight, 10),
                        ),
                      ),
                      solidBackgroundColor: isLight
                          ? AppColors.surfaceLight
                          : AppColors.surface,
                      backButtonVariant: isLight
                          ? AppBackButtonVariant.light
                          : AppBackButtonVariant.auto,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Top Profile Hero Section matching Profile Hub & Loan Tracker:
  /// - Flush top with pull-down overscroll fill
  /// - Bottom rounded corners (28px radius)
  /// - AppHeader inside at top with back button & 'My Profile'
  /// - Avatar with concentric circular stroke placed by itself (no overlapping plus icon)
  /// - User name, active email, and status badges
  /// - Dedicated active account Logout / Sign Out action
  Widget _buildTopHeroSection(
    BuildContext context,
    AuthViewModel authVM,
    AnalyticsViewModel analyticsVM,
    bool isLight,
  ) {
    final bool isAuth = authVM.isAuthenticated;
    final String activeName = authVM.displayName ??
        (isAuth ? 'Shibre User' : 'Guest Profile');
    final String? activeEmail = authVM.email;
    final String? activeAvatar = authVM.avatarUrl;
    final String levelName = analyticsVM.userLevelName;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Upward extension filling pull-down overscroll region seamlessly
        Positioned(
          top: -1000,
          left: 0,
          right: 0,
          bottom: 28,
          child: Container(
            color: isLight ? AppColors.surfaceLight : AppColors.surface,
          ),
        ),

        // Hero Container with 28px bottom rounded corners
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isLight ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top spacing for pinned collapsing header bar
                  const SizedBox(height: 52),

                  // Avatar with concentric rounded rectangular stroke placed by itself (no overlapping plus icon)
                  Center(
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: Container(
                        padding: const EdgeInsets.all(2.5), // Outer white ring stroke
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: isLight
                                ? [
                                    AppColors.textPrimaryLight,
                                    AppColors.textPrimaryLight
                                        .withValues(alpha: 0.65),
                                  ]
                                : [
                                    Colors.white,
                                    Colors.white.withValues(alpha: 0.65),
                                  ],
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2.5), // Spacer gap
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(31.5),
                            color: isLight
                                ? AppColors.surfaceLight
                                : AppColors.surface,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(29),
                            child: activeAvatar != null &&
                                    activeAvatar.isNotEmpty
                                ? Image.network(
                                    activeAvatar,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildInitials(
                                      activeName,
                                      isLight,
                                      28,
                                    ),
                                  )
                                : _buildInitials(
                                    activeName,
                                    isLight,
                                    28,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Full User Display Name
                  Center(
                    child: Text(
                      activeName,
                      style: AppTypography.heading1.copyWith(
                        color: context.themeTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Email or Session Status
                  Center(
                    child: Text(
                      activeEmail ??
                          (isAuth
                              ? 'Connected with Google'
                              : 'Offline Guest Session'),
                      style: AppTypography.caption.copyWith(
                        color: context.themeTextSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Badges Row
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAuth) ...[
                          if (authVM.isPro) ...[
                            AppBadge.success(
                              text: authVM.planDisplayName.toUpperCase(),
                              size: AppBadgeSize.micro,
                            ),
                            const SizedBox(width: 6),
                          ],
                          const AppBadge.success(
                            text: 'CLOUD SYNC ACTIVE',
                            size: AppBadgeSize.micro,
                          ),
                          const SizedBox(width: 6),
                          AppBadge.neutral(
                            text: levelName.toUpperCase(),
                            size: AppBadgeSize.micro,
                          ),
                        ] else ...[
                          const AppBadge.neutral(
                            text: 'OFFLINE VAULT',
                            size: AppBadgeSize.micro,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Logout / Sign Out action specifically for this active account
                  Center(
                    child: isAuth
                        ? AppButton.destructive(
                            text: 'Sign Out Account',
                            icon: Icons.logout_rounded,
                            fullWidth: false,
                            height: 38,
                            fontSize: 12.5,
                            iconSize: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            onPressed: () => _confirmSignOut(context, authVM),
                          )
                        : AppButton.primary(
                            text: authVM.isLoading
                                ? 'Signing In...'
                                : 'Sign In with Google',
                            icon: Icons.login_rounded,
                            fullWidth: false,
                            height: 38,
                            fontSize: 12.5,
                            iconSize: 15,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            onPressed: authVM.isLoading
                                ? null
                                : () => _handleGoogleSignIn(context, authVM),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Multi-Account Switcher Section (Full Width Card):
  /// Contains the accounts list with green ACTIVE badge and Add Another Account button.
  Widget _buildConnectedAccountsSection(
    BuildContext context,
    AuthViewModel authVM,
    List<StoredAccount> accounts,
    bool isLight,
  ) {
    final StoredAccount? currentActive = authVM.activeAccount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              Text(
                'CONNECTED ACCOUNTS',
                style: AppTypography.caption.copyWith(
                  color: context.themeTextSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              AppBadge.neutral(
                text: '${accounts.length}',
                size: AppBadgeSize.micro,
              ),
            ],
          ),
        ),
        // Full-Width Connected Accounts Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isLight ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ...accounts.asMap().entries.map((entry) {
                final int index = entry.key;
                final StoredAccount acc = entry.value;
                final bool isActive = acc.userId == currentActive?.userId;
                final bool isLast = index == accounts.length - 1;

                return Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isActive
                          ? null
                          : () async {
                              HapticFeedback.selectionClick();
                              await AccountSmsModeDrawer.switchAccountWithPrompt(
                                context: context,
                                authVM: authVM,
                                account: acc,
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: isLight
                                    ? AppColors.tabBackgroundLight
                                    : AppColors.buttonSecondary,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: acc.avatarUrl != null &&
                                        acc.avatarUrl!.isNotEmpty
                                    ? Image.network(
                                        acc.avatarUrl!,
                                        width: 38,
                                        height: 38,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _buildInitials(
                                          acc.displayName,
                                          isLight,
                                          14,
                                        ),
                                      )
                                    : _buildInitials(
                                        acc.displayName,
                                        isLight,
                                        14,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    acc.displayName,
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: context.themeTextPrimary,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    acc.email,
                                    style: AppTypography.caption.copyWith(
                                      color: context.themeTextSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isActive)
                              const AppBadge.success(
                                text: 'ACTIVE',
                                size: AppBadgeSize.micro,
                              )
                            else
                              Icon(
                                Icons.swap_horiz_rounded,
                                color: context.themeTextSecondary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(left: 68, right: 16),
                        color: isLight
                            ? AppColors.tabBackgroundLight
                            : AppColors.buttonSecondary,
                      ),
                  ],
                );
              }),

              const SizedBox(height: 4),

              // Add Another Account Secondary Pill Button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppButton.secondary(
                  text: 'Add Another Account',
                  icon: Icons.person_add_alt_1_rounded,
                  fullWidth: true,
                  height: 44,
                  onPressed: () => _promptAddAccount(context, authVM),
                ),
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ],
    );
  }

  /// Security & Cloud Synchronization Card (Full Width):
  Widget _buildSecurityCard(
    BuildContext context,
    bool isAuth,
    String formattedSmsCount,
    bool isLight,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: isLight ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLight
                  ? AppColors.tabBackgroundLight
                  : AppColors.buttonSecondary,
            ),
            child: Icon(
              isAuth ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isAuth
                          ? 'Encrypted Cloud Sync'
                          : 'Offline Vault Storage',
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.themeTextPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge.neutral(
                      text: '$formattedSmsCount SMS LINKED',
                      size: AppBadgeSize.micro,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAuth
                      ? '$formattedSmsCount banking SMS transactions are linked and synchronized in real time across your devices with end-to-end encryption.'
                      : '$formattedSmsCount banking SMS transactions are linked and securely stored offline on this device. Sign in to enable multi-device sync.',
                  style: AppTypography.caption.copyWith(
                    color: context.themeTextSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Logged-In Devices & Active Sessions Section (Full Width Card):
  /// Displays current device and remote active/inactive hardware sessions.
  Widget _buildDevicesSection(
    BuildContext context,
    AuthViewModel authVM,
    bool isLight,
  ) {
    final AccountDeviceSession? currentDevice = authVM.currentDeviceSession;
    final List<AccountDeviceSession> otherActive = authVM.otherActiveDevices;
    final List<AccountDeviceSession> inactive = authVM.inactiveDevices;
    final int activeCount =
        (currentDevice != null ? 1 : 0) + otherActive.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              Text(
                'LOGGED-IN DEVICES',
                style: AppTypography.caption.copyWith(
                  color: context.themeTextSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              AppBadge.neutral(
                text: '$activeCount ACTIVE',
                size: AppBadgeSize.micro,
              ),
              const Spacer(),
              GestureDetector(
                onTap: authVM.isLoadingDevices
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        authVM.loadAccountDevices();
                      },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: context.themeTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Refresh',
                        style: AppTypography.caption.copyWith(
                          color: context.themeTextSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Full-Width Logged-in Devices Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isLight ? AppColors.surfaceLight : AppColors.surface,
            borderRadius: AppRadius.cardRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Current Device Tile (Always pinned at top)
              if (currentDevice != null) ...[
                _buildDeviceTile(
                  context: context,
                  session: currentDevice,
                  authVM: authVM,
                  isLight: isLight,
                ),
              ] else ...[
                // Default fallback tile for this device
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isLight
                              ? AppColors.tabBackgroundLight
                              : AppColors.buttonSecondary,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.phone_android_rounded,
                          color: isLight
                              ? AppColors.textPrimaryLight
                              : Colors.white,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authVM.deviceModel,
                              style: AppTypography.bodyMedium.copyWith(
                                color: context.themeTextPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'This device • Active now',
                              style: AppTypography.caption.copyWith(
                                color: context.themeTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const AppBadge.success(
                        text: 'THIS DEVICE',
                        size: AppBadgeSize.micro,
                      ),
                    ],
                  ),
                ),
              ],

              // 2. Other Active Devices List
              if (otherActive.isNotEmpty) ...[
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 68, right: 16),
                  color: isLight
                      ? AppColors.tabBackgroundLight
                      : AppColors.buttonSecondary,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'OTHER ACTIVE SESSIONS',
                    style: AppTypography.caption.copyWith(
                      color: context.themeTextSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                for (int i = 0; i < otherActive.length; i++) ...[
                  _buildDeviceTile(
                    context: context,
                    session: otherActive[i],
                    authVM: authVM,
                    isLight: isLight,
                  ),
                  if (i < otherActive.length - 1)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 68, right: 16),
                      color: isLight
                          ? AppColors.tabBackgroundLight
                          : AppColors.buttonSecondary,
                    ),
                ],
              ],

              // 3. Inactive Devices List
              if (inactive.isNotEmpty) ...[
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 68, right: 16),
                  color: isLight
                      ? AppColors.tabBackgroundLight
                      : AppColors.buttonSecondary,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'INACTIVE SESSIONS',
                    style: AppTypography.caption.copyWith(
                      color: context.themeTextSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                for (int i = 0; i < inactive.length; i++) ...[
                  _buildDeviceTile(
                    context: context,
                    session: inactive[i],
                    authVM: authVM,
                    isLight: isLight,
                  ),
                  if (i < inactive.length - 1)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 68, right: 16),
                      color: isLight
                          ? AppColors.tabBackgroundLight
                          : AppColors.buttonSecondary,
                    ),
                ],
              ],

              // 4. Terminate All Other Sessions Pill Button (if other devices exist)
              if (otherActive.isNotEmpty || inactive.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: AppButton.destructive(
                    text: 'Terminate All Other Sessions',
                    icon: Icons.delete_sweep_rounded,
                    fullWidth: true,
                    height: 44,
                    onPressed: () =>
                        _confirmTerminateAllOtherSessions(context, authVM),
                  ),
                ),
                const SizedBox(height: 6),
              ] else if (!authVM.isLoadingDevices) ...[
                // Subtle informational note when only this device is logged in
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Text(
                    'No other devices are currently logged in to this account.',
                    style: AppTypography.caption.copyWith(
                      color: context.themeTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Single device row with model, last seen relative time, and status badge / chevron
  Widget _buildDeviceTile({
    required BuildContext context,
    required AccountDeviceSession session,
    required AuthViewModel authVM,
    required bool isLight,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => DeviceSessionDetailSheet.show(
          context: context,
          session: session,
          authVM: authVM,
        ),
        splashColor: isLight
            ? AppColors.buttonSecondaryOnLight
            : AppColors.buttonSecondary,
        highlightColor: isLight
            ? AppColors.buttonSecondaryOnLight
            : AppColors.buttonSecondary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isLight
                      ? AppColors.tabBackgroundLight
                      : AppColors.buttonSecondary,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _getDeviceIcon(session.platform, session.deviceModel),
                  color: session.isCurrentDevice
                      ? (isLight ? AppColors.textPrimaryLight : Colors.white)
                      : (isLight
                          ? AppColors.textSecondaryLight
                          : AppColors.textSecondary),
                  size: 19,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.deviceModel,
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.themeTextPrimary,
                        fontWeight: session.isCurrentDevice
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.isCurrentDevice
                          ? 'This device • Active now'
                          : '${session.platform} • ${session.formattedLastSeen}',
                      style: AppTypography.caption.copyWith(
                        color: context.themeTextSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.themeTextSecondary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String platform, String model) {
    final m = model.toLowerCase();
    if (m.contains('tablet') || m.contains('ipad')) {
      return Icons.tablet_mac_rounded;
    } else if (m.contains('desktop') ||
        m.contains('windows') ||
        m.contains('mac')) {
      return Icons.laptop_mac_rounded;
    }
    return Icons.phone_android_rounded;
  }

  void _confirmTerminateAllOtherSessions(
      BuildContext context, AuthViewModel authVM) {
    HapticFeedback.selectionClick();
    AppConfirmDialog.show(
      context: context,
      title: 'Terminate All Other Sessions',
      message:
          'Are you sure you want to log out of all other devices? All other phones and tablets will lose access until signed in again.',
      confirmText: 'Terminate All',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () async {
        final success = await authVM.terminateAllOtherSessions();
        if (context.mounted) {
          if (success) {
            AppToast.success(
              context,
              message: 'Sessions Terminated',
              subtitle: 'All other devices have been logged out',
            );
          } else {
            AppToast.error(context, message: 'Failed to terminate sessions');
          }
        }
      },
    );
  }
}
