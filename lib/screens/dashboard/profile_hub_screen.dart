import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../widgets/interactive_3d_badge.dart';
import '../../widgets/level_up_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_scroll_header_bar.dart';
import '../../theme/app_theme.dart';
import '../../presentation/viewmodels/analytics_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/auth_view_model.dart';
import '../../widgets/app_toast.dart';
import 'saving_goals_screen.dart';
import 'settings_screen.dart';
import 'my_profile_screen.dart';

Color _levelGlowColor(int level) => AppColors.getLevelGlow(level);

String _levelShortDescription(int level) {
  switch (level) {
    case 1:
      return 'focuses on tracking day-to-day spending and building emergency savings.';
    case 2:
      return 'establishes a solid financial foundation with consistent savings discipline.';
    case 3:
      return 'maintains a substantial financial cushion with accelerating capital growth.';
    case 4:
      return 'achieves high financial security through disciplined wealth growth.';
    case 5:
      return 'represents the pinnacle tier of financial independence and wealth.';
    default:
      return 'focuses on tracking spending habits and steady wealth accumulation.';
  }
}


class ProfileHubScreen extends StatefulWidget {
  const ProfileHubScreen({super.key});

  @override
  State<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends State<ProfileHubScreen> {
  bool _isProgressExpanded = false;
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthViewModel>().syncSubscription();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLight = context.isLightMode;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
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
        child: Stack(
          children: [
              SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Top Section (Matches Spending Chart & Loan Tracker) ──
                    Consumer3<AuthViewModel, AnalyticsViewModel, SettingsViewModel>(
                      builder: (context, authVM, analyticsVM, settingsVM, _) {
                        return _buildTopHeroSection(
                          context,
                          authVM,
                          analyticsVM,
                          settingsVM,
                          isLight,
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Navigation Menu Card: My Profile & Saving Goals (Full Width) ──
                    Consumer<AuthViewModel>(
                      builder: (context, authVM, _) {
                        return _buildNavigationMenuCard(context, authVM, isLight);
                      },
                    ),

                    const SizedBox(height: 110),
                  ],
                ),
              ),

              // Pinned Collapsing Header Bar on Scroll
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Consumer<AuthViewModel>(
                  builder: (context, authVM, _) {
                    return AppScrollHeaderBar(
                      scrollController: _scrollController,
                      mode: AppScrollHeaderMode.revealOnScroll,
                      showBackButton: false,
                      title: 'Profile Hub',
                      solidBackgroundColor: isLight
                          ? AppColors.surfaceLight
                          : AppColors.surface,
                      trailing: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _showSubscriptionPlanSheet(context, authVM);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isLight
                                ? AppColors.tabBackgroundLight
                                : AppColors.buttonSecondary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                authVM.isPro
                                    ? Icons.workspace_premium_rounded
                                    : Icons.auto_awesome_rounded,
                                size: 14,
                                color: isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                authVM.planDisplayName,
                                style: AppTypography.caption.copyWith(
                                  color: isLight
                                      ? AppColors.textPrimaryLight
                                      : Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Top hero section modeled after Spending Charts & Loan Tracker:
  /// - Flush top with pull-down overscroll fill
  /// - Bottom rounded corners (28px radius)
  /// - Header with Settings button on the top right
  /// - Centered large profile picture + user name
  /// - Rollup container: 3D badge, badge name, tag label, requirement on right, 2-line description
  /// - Small collapsible progress section with custom progress bar & Levels info button
  Widget _buildTopHeroSection(
    BuildContext context,
    AuthViewModel authVM,
    AnalyticsViewModel analyticsVM,
    SettingsViewModel settingsVM,
    bool isLight,
  ) {
    final String name = authVM.displayName ?? (authVM.isAuthenticated ? 'Shibre User' : 'Guest Profile');
    final String? avatarUrl = authVM.avatarUrl;
    final int level = analyticsVM.userLevel;
    final String levelName = analyticsVM.userLevelName;
    final String levelDesc = analyticsVM.userLevelDescription;
    final Color glowColor = _levelGlowColor(level);
    final String badgePath = 'assets/images/LV$level.svg';

    final String? nextLvName = analyticsVM.nextLevelName;
    final double progress = analyticsVM.nextLevelProgress;
    final double? targetBal = analyticsVM.nextLevelTargetBalance;
    final NumberFormat fmt = NumberFormat('#,##0.00');
    final bool isVisible = settingsVM.isBalanceVisible;

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

        // Hero Container
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
                  // 1. Spacer for the pinned scroll header bar
                  const SizedBox(height: 48),

                  // 2. Large Profile Picture with Concentric Story Rings & Add Account Badge
                  Center(
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Concentric Rounded Rectangular Story Rings: Outer colored stroke + inner empty gap stroke
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyProfileScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2.5), // Outer white ring stroke
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(36),
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
                                            Colors.white
                                                .withValues(alpha: 0.65),
                                          ],
                                  ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2.5), // "First stroke is empty" spacer gap
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(33.5),
                                    color: isLight
                                        ? AppColors.surfaceLight
                                        : AppColors.surface,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(31),
                                    child: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _buildInitials(name, isLight, 30),
                                          )
                                        : (authVM.isAuthenticated
                                            ? _buildInitials(name, isLight, 30)
                                            : Icon(
                                                Icons.person_outline_rounded,
                                                size: 40,
                                                color: isLight
                                                    ? AppColors.textSecondaryLight
                                                    : AppColors.textSecondary,
                                              )),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Level Badge positioned directly on bottom right of Profile Picture with its own clipping stroke
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                showLevelUpModal(
                                  context,
                                  newLevel: level,
                                  newLevelName: levelName,
                                  newLevelDescription: levelDesc,
                                  nextLevelName: nextLvName,
                                  nextLevelProgress: progress,
                                  isBalanceVisible: true,
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: _BadgeWithClippingStroke(
                                badgePath: badgePath,
                                size: 34,
                                strokeWidth: 2.5,
                                strokeColor: isLight
                                    ? AppColors.surfaceLight
                                    : AppColors.surface,
                                child: Interactive3DBadge(
                                  level: level,
                                  levelName: levelName,
                                  badgePath: badgePath,
                                  glowColor: glowColor,
                                  size: 34,
                                  showAmbientGlow: false,
                                  showBackText: false,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    showLevelUpModal(
                                      context,
                                      newLevel: level,
                                      newLevelName: levelName,
                                      newLevelDescription: levelDesc,
                                      nextLevelName: nextLvName,
                                      nextLevelProgress: progress,
                                      isBalanceVisible: true,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. User Name (Level Badge moved up to avatar)
                  Center(
                    child: Text(
                      name,
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

                  // Status Micro-Badges
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (authVM.isAuthenticated) ...[
                          const AppBadge.success(
                            text: 'CLOUD SYNC',
                            size: AppBadgeSize.micro,
                          ),
                          if (authVM.storedAccounts.length > 1) ...[
                            const SizedBox(width: 6),
                            AppBadge.info(
                              text: '${authVM.storedAccounts.length} ACCOUNTS',
                              size: AppBadgeSize.micro,
                            ),
                          ],
                        ] else ...[
                          const AppBadge.neutral(
                            text: 'OFFLINE VAULT',
                            size: AppBadgeSize.micro,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. Description Section (Same Color, No Dot, In the Same Line)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text.rich(
                      TextSpan(
                        style: AppTypography.caption.copyWith(
                          color: context.themeTextSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: '$levelName ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: _levelShortDescription(level),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. Small Collapsible Progress Section
                  Container(
                    decoration: BoxDecoration(
                      color: isLight
                          ? AppColors.cardTileLight
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Collapsible Header Row
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isProgressExpanded = !_isProgressExpanded;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  size: 18,
                                  color: isLight
                                      ? AppColors.textPrimaryLight
                                      : Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    nextLvName != null
                                        ? 'Tier Progress to LV${level + 1}'
                                        : 'Tier Progress (Max Level)',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: context.themeTextPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                AppBadge.success(
                                  text: isVisible
                                      ? (nextLvName != null
                                          ? '${(progress * 100).toStringAsFixed(1)}%'
                                          : 'MAX')
                                      : '•••%',
                                  size: AppBadgeSize.micro,
                                ),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  turns: _isProgressExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeInOutCubic,
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: isLight
                                        ? AppColors.textSecondaryLight
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expandable Content Body
                        AnimatedCrossFade(
                          firstChild: const SizedBox(
                            width: double.infinity,
                            height: 0,
                          ),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 4),
                                CustomProgressBar(
                                  progress: isVisible ? progress : 0.0,
                                  height: 7,
                                  backgroundColor: isLight
                                      ? AppColors.tabBackgroundLight
                                      : AppColors.buttonSecondary,
                                  progressColor: isLight
                                      ? AppColors.textPrimaryLight
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                const SizedBox(height: 8),
                                if (nextLvName != null)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isVisible
                                            ? '${fmt.format(analyticsVM.totalBalance)} ETB'
                                            : '•••••••• ETB',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: context.themeTextPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        isVisible
                                            ? 'Target: ${fmt.format(targetBal ?? 0)} ETB'
                                            : 'Target: •••••••• ETB',
                                        style: AppTypography.caption.copyWith(
                                          color: context.themeTextSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: AppButton.secondary(
                                    text: 'Levels Breakdown',
                                    icon: Icons.military_tech_rounded,
                                    trailingIcon:
                                        Icons.arrow_forward_ios_rounded,
                                    fullWidth: false,
                                    height: 28,
                                    fontSize: 11.5,
                                    iconSize: 13,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    onPressed: () =>
                                        _showLevelsInfoDialog(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          crossFadeState: _isProgressExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 240),
                          sizeCurve: Curves.easeInOutCubic,
                          firstCurve: Curves.easeInOutCubic,
                          secondCurve: Curves.easeInOutCubic,
                        ),
                      ],
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

  /// Builds the Grouped Navigation Menu Card:
  /// - My Profile (opens Account Management & Switching Sheet)
  /// - 1px Divider
  /// - Saving Goals
  Widget _buildNavigationMenuCard(
    BuildContext context,
    AuthViewModel authVM,
    bool isLight,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isLight ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. My Profile Tile
          _buildMenuItemTile(
            context,
            title: 'My Profile',
            iconWidget: Icon(
              Icons.person_rounded,
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              size: 24,
            ),
            showDivider: true,
            isLight: isLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyProfileScreen(),
                ),
              );
            },
          ),

          // 2. Saving Goals Tile
          _buildMenuItemTile(
            context,
            title: 'Saving Goals',
            iconWidget: Icon(
              Icons.savings_rounded,
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              size: 24,
            ),
            showDivider: true,
            isLight: isLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavingGoalsScreen(),
                ),
              );
            },
          ),

          // 3. Settings Tile
          _buildMenuItemTile(
            context,
            title: 'Settings',
            iconWidget: Icon(
              Icons.settings_rounded,
              color: isLight ? AppColors.textPrimaryLight : Colors.white,
              size: 24,
            ),
            showDivider: false,
            isLight: isLight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemTile(
    BuildContext context, {
    required String title,
    required Widget iconWidget,
    required VoidCallback onTap,
    required bool isLight,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: isLight
                ? AppColors.buttonSecondaryOnLight
                : AppColors.buttonSecondary,
            highlightColor: isLight
                ? AppColors.buttonSecondaryOnLight
                : AppColors.buttonSecondary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    child: iconWidget,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.bodyLarge.copyWith(
                        color: context.themeTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isLight
                        ? AppColors.textSecondaryLight
                        : AppColors.textSecondary,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: isLight
                ? AppColors.tabBackgroundLight
                : AppColors.buttonSecondary,
          ),
      ],
    );
  }

  Widget _buildInitials(String name, bool isLight, double fontSize) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      alignment: Alignment.center,
      color: isLight ? AppColors.cardTileLight : AppColors.buttonSecondary,
      child: Text(
        letter,
        style: AppTypography.titleMedium.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Subscription & Plan Bottom Sheet:
  /// Displays the user's active plan and previews upcoming Premium subscription tiers.
  void _showSubscriptionPlanSheet(BuildContext context, AuthViewModel authVM) {
    final bool isLight = context.isLightMode;
    final bool isPro = authVM.isPro;

    AppBottomSheet.show(
      context: context,
      builder: (sheetCtx) {
        return AppBottomSheet(
          title: 'Subscription & Plans',
          icon: Icons.workspace_premium_rounded,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current Active Plan Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight
                      ? AppColors.cardTileLight
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isLight
                                    ? AppColors.tabBackgroundLight
                                    : AppColors.buttonSecondary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPro
                                    ? Icons.workspace_premium_rounded
                                    : Icons.auto_awesome_rounded,
                                color: isLight
                                    ? AppColors.textPrimaryLight
                                    : Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              authVM.planDisplayName,
                              style: AppTypography.titleLarge.copyWith(
                                color: context.themeTextPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        isPro
                            ? const AppBadge.success(
                                text: 'ACTIVE',
                                size: AppBadgeSize.small,
                              )
                            : const AppBadge.neutral(
                                text: 'CURRENT PLAN',
                                size: AppBadgeSize.small,
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPro
                          ? (authVM.proUntil != null
                              ? 'Active until ${DateFormat('MMM dd, yyyy').format(authVM.proUntil!)}. Includes unlimited cloud sync, multi-device backup, and advanced analytics.'
                              : 'Lifetime license active. Includes unlimited cloud sync, multi-device backup, and advanced analytics.')
                          : 'Includes unlimited local transaction tracking, automated SMS parsing, categories, and offline vault security.',
                      style: AppTypography.caption.copyWith(
                        color: isLight
                            ? AppColors.textSecondaryLight
                            : AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // If user is Free, show Shibre Pro preview; if Pro, show active features
              if (!isPro) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.tabBackgroundLight
                        : AppColors.buttonSecondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isLight
                                      ? AppColors.tabBackgroundLight
                                      : AppColors.buttonSecondary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.workspace_premium_rounded,
                                  color: isLight
                                      ? AppColors.textPrimaryLight
                                      : Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Shibre Pro',
                                style: AppTypography.titleLarge.copyWith(
                                  color: context.themeTextPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const AppBadge.info(
                            text: 'UPGRADE',
                            size: AppBadgeSize.small,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        context,
                        'Unlimited Encrypted Cloud Sync & Backup',
                        isLight,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                        context,
                        'Multi-Account Switching on Single Device',
                        isLight,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                        context,
                        'Advanced Financial Analytics & Forecasts',
                        isLight,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                        context,
                        'Server-Authoritative Anti-Tampering Security',
                        isLight,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppButton.primary(
                  text: 'Upgrade to Pro (Coming Soon)',
                  icon: Icons.star_rounded,
                  height: 48,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    AppToast.info(
                      context,
                      message: 'Subscription Plans Coming Soon',
                      subtitle: 'Direct in-app subscription purchasing will be available shortly.',
                    );
                  },
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.tabBackgroundLight
                        : AppColors.buttonSecondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Plan Capabilities',
                        style: AppTypography.titleMedium.copyWith(
                          color: context.themeTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildFeatureItem(
                        context,
                        'Unlimited Encrypted Cloud Sync & Backup',
                        isLight,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                        context,
                        'Multi-Account Switching on Single Device',
                        isLight,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                        context,
                        'Server-Authoritative Anti-Tampering Security',
                        isLight,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppButton.secondary(
                  text: 'License Active',
                  icon: Icons.check_circle_rounded,
                  height: 48,
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                  },
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text, bool isLight) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: isLight ? AppColors.textPrimaryLight : Colors.white,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: isLight
                  ? AppColors.textPrimaryLight
                  : AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }







  void _showLevelsInfoDialog(BuildContext context) {
    AppDrawer.show(
      context: context,
      builder: (ctx) => Consumer2<AnalyticsViewModel, SettingsViewModel>(
        builder: (context, analyticsVM, settingsVM, _) {
          final currentLv = analyticsVM.userLevel;
          final currentLvName = analyticsVM.userLevelName;
          final nextLvName = analyticsVM.nextLevelName;
          final remaining = analyticsVM.remainingToNextLevel;
          final progress = analyticsVM.nextLevelProgress;
          final fmt = NumberFormat('#,##0.00');
          final isVisible = settingsVM.isBalanceVisible;
          final bool isLight = context.isLightMode;

          const levels = [
            {
              'level': 1,
              'name': 'Survivor',
              'range': '≤ 100K ETB',
              'badge': 'assets/images/LV1.svg'
            },
            {
              'level': 2,
              'name': 'Builder',
              'range': '100K – 500K ETB',
              'badge': 'assets/images/LV2.svg'
            },
            {
              'level': 3,
              'name': 'Flourishing',
              'range': '500K – 1M ETB',
              'badge': 'assets/images/LV3.svg'
            },
            {
              'level': 4,
              'name': 'Prospering',
              'range': '1M – 5M ETB',
              'badge': 'assets/images/LV4.svg'
            },
            {
              'level': 5,
              'name': 'Elite',
              'range': '> 5M ETB',
              'badge': 'assets/images/LV5.svg'
            },
          ];

          return AppDrawer(
            headerCard: const AppDrawerHeaderCard(
              icon: Icons.military_tech_rounded,
              title: 'Financial Levels',
            ),
            bottomAction: AppButton.primary(
              text: 'Got It',
              height: 48,
              onPressed: () => Navigator.pop(ctx),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current Level Progress Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.previewCardBg,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/LV$currentLv.svg',
                            width: 44,
                            height: 44,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Level $currentLv · $currentLvName',
                                      style: AppTypography.titleLarge.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const AppBadge.neutral(text: 'CURRENT'),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nextLvName != null
                                      ? (isVisible
                                          ? '${(progress * 100).toStringAsFixed(1)}% to Level ${currentLv + 1} ($nextLvName)'
                                          : '•••• to Level ${currentLv + 1} ($nextLvName)')
                                      : 'Max Financial Level Reached!',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Progress Bar
                      CustomProgressBar(
                        progress: isVisible ? progress : 0.0,
                        height: 8,
                        backgroundColor: AppColors.buttonSecondary,
                        progressColor: isLight
                            ? AppColors.textPrimaryLight
                            : Colors.white,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      const SizedBox(height: 10),

                      // Remaining Balance Statement
                      Text(
                        nextLvName != null
                            ? (isVisible
                                ? 'You need ${fmt.format(remaining)} ETB more to reach Level ${currentLv + 1} ($nextLvName).'
                                : 'You need •••••••• ETB more to reach Level ${currentLv + 1} ($nextLvName).')
                            : 'Congratulations! You have reached the highest financial level.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // All Levels Breakdown
                ...levels.map((l) {
                  final lv = l['level'] as int;
                  final isCurrent = lv == currentLv;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.buttonSecondary
                          : Colors.transparent,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          l['badge'] as String,
                          width: 32,
                          height: 32,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'LV$lv · ${l['name']}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                l['range'] as String,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          const AppBadge.neutral(text: 'CURRENT'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Renders a badge with an outer silhouette clipping stroke matching the
/// exact shape and contours of the badge SVG. This silhouette cuts cleanly into
/// the avatar behind it using the background surface color, with zero circular borders.
class _BadgeWithClippingStroke extends StatelessWidget {
  final String badgePath;
  final double size;
  final double strokeWidth;
  final Color strokeColor;
  final Widget child;

  const _BadgeWithClippingStroke({
    required this.badgePath,
    required this.size,
    this.strokeWidth = 2.5,
    required this.strokeColor,
    required this.child,
  });

  static final List<Offset> _defaultOffsets = () {
    const int count = 16;
    const double radius = 2.5;
    final list = <Offset>[Offset.zero];
    for (int i = 0; i < count; i++) {
      final theta = i * 2 * math.pi / count;
      list.add(Offset(math.cos(theta) * radius, math.sin(theta) * radius));
    }
    return list;
  }();

  List<Offset> _computeOffsets() {
    if (strokeWidth == 2.5) return _defaultOffsets;
    const int count = 16;
    final list = <Offset>[Offset.zero];
    for (int i = 0; i < count; i++) {
      final theta = i * 2 * math.pi / count;
      list.add(Offset(math.cos(theta) * strokeWidth, math.sin(theta) * strokeWidth));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final offsets = _computeOffsets();

    return RepaintBoundary(
      child: SizedBox(
        width: size + strokeWidth * 2,
        height: size + strokeWidth * 2,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outer clipping stroke: badge silhouette dilated in 16 directions by strokeWidth
            for (final offset in offsets)
              Transform.translate(
                offset: offset,
                child: SvgPicture.asset(
                  badgePath,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(strokeColor, BlendMode.srcIn),
                ),
              ),
            // The central interactive badge itself
            child,
          ],
        ),
      ),
    );
  }
}
