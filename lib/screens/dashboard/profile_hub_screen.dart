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
import '../../widgets/app_header.dart';
import '../../theme/app_theme.dart';
import '../../presentation/viewmodels/analytics_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import 'saving_goals_screen.dart';
import 'settings_screen.dart';

Color _levelGlowColor(int level) => AppColors.getLevelGlow(level);

class ProfileHubScreen extends StatelessWidget {
  const ProfileHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: context.isLightMode
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header: AppHeader with Levels Action ──────────────────
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AppHeader(
                    title: 'Profile Hub',
                    showBackButton: false,
                    padding: EdgeInsets.zero,
                    trailing: AppButton.secondary(
                      text: 'Levels',
                      trailingIcon: Icons.arrow_forward_ios_rounded,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11.5,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () => _showLevelsInfoDialog(context),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

                    // ── Hero Section: Dynamic Level Badge & Progress Card ───────────────
                    Consumer2<AnalyticsViewModel, SettingsViewModel>(
                      builder: (context, analyticsVM, settingsVM, _) {
                        final level = analyticsVM.userLevel;
                        final levelName = analyticsVM.userLevelName;
                        final levelDesc = analyticsVM.userLevelDescription;
                        final glowColor = _levelGlowColor(level);
                        final badgePath = 'assets/images/LV$level.svg';

                        final nextLvName = analyticsVM.nextLevelName;
                        final remaining = analyticsVM.remainingToNextLevel;
                        final progress = analyticsVM.nextLevelProgress;
                        final targetBal = analyticsVM.nextLevelTargetBalance;
                        final fmt = NumberFormat('#,##0.00');
                        final isVisible = settingsVM.isBalanceVisible;

                        return Column(
                          children: [
                            // 1. Interactive 3D Level Badge (tap → level-up modal)
                            GestureDetector(
                              onTap: () => showLevelUpModal(
                                context,
                                newLevel: level,
                                newLevelName: levelName,
                                newLevelDescription: levelDesc,
                                nextLevelName: nextLvName,
                                nextLevelProgress: progress,
                              ),
                              child: Interactive3DBadge(
                                level: level,
                                levelName: levelName,
                                badgePath: badgePath,
                                glowColor: glowColor,
                                size: 130,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              levelName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Level $level',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. Premium Level Progress Card with CustomProgressBar
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.cardRadius,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Progress Header Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.bolt_rounded,
                                            color: AppColors.positive,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            nextLvName != null
                                                ? 'Progress to Level ${level + 1}'
                                                : 'Maximum Level',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      AppBadge.success(
                                        text: nextLvName != null
                                            ? '${(progress * 100).toStringAsFixed(1)}%'
                                            : 'MAX',
                                        size: AppBadgeSize.small,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Reusable CustomProgressBar Component
                                  CustomProgressBar(
                                    progress: progress,
                                    height: 10,
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    progressColor: AppColors.positive,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  const SizedBox(height: 12),

                                  // Progress Balance Labels & Status Message
                                  if (nextLvName != null) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isVisible
                                              ? '${fmt.format(analyticsVM.totalBalance)} ETB'
                                              : '•••••••• ETB',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          'Target: ${fmt.format(targetBal ?? 0)} ETB',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isVisible
                                          ? 'Need ${fmt.format(remaining)} ETB more to unlock Level ${level + 1} ($nextLvName)'
                                          : 'Need •••••••• ETB more to unlock Level ${level + 1} ($nextLvName)',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      'You have achieved Level 5 ($levelName)! You are in the highest tier of financial growth.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 3. Level Description Text
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                levelDesc,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.50),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── Grouped Navigation Card (Saving Goals & Settings in one unified card) ──
                    _buildGroupedCardBase([
                      _buildMenuItemTile(
                        context,
                        title: 'Saving Goals',
                        iconWidget: Image.asset(
                          'assets/images/Saving_Goal_Icon.png',
                          width: 26,
                          height: 26,
                        ),
                        showDivider: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SavingGoalsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildMenuItemTile(
                        context,
                        title: 'Settings',
                        iconWidget: const AppSvgIcon(
                          'assets/images/Settings_icon.svg',
                          size: 24,
                        ),
                        showDivider: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildGroupedCardBase(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItemTile(
    BuildContext context, {
    required String title,
    required Widget iconWidget,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.03),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 15,
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
            color: Colors.white.withValues(alpha: 0.05),
          ),
      ],
    );
  }

  void _showLevelsInfoDialog(BuildContext context) {
    AppDrawer.show(
      context: context,
      builder: (ctx) => Consumer<AnalyticsViewModel>(
        builder: (context, analyticsVM, _) {
          final currentLv = analyticsVM.userLevel;
          final currentLvName = analyticsVM.userLevelName;
          final nextLvName = analyticsVM.nextLevelName;
          final remaining = analyticsVM.remainingToNextLevel;
          final progress = analyticsVM.nextLevelProgress;
          final fmt = NumberFormat('#,##0.00');

          const levels = [
            {'level': 1, 'name': 'Survivor', 'range': '≤ 100K ETB', 'badge': 'assets/images/LV1.svg'},
            {'level': 2, 'name': 'Builder', 'range': '100K – 500K ETB', 'badge': 'assets/images/LV2.svg'},
            {'level': 3, 'name': 'Flourishing', 'range': '500K – 1M ETB', 'badge': 'assets/images/LV3.svg'},
            {'level': 4, 'name': 'Prospering', 'range': '1M – 5M ETB', 'badge': 'assets/images/LV4.svg'},
            {'level': 5, 'name': 'Elite', 'range': '> 5M ETB', 'badge': 'assets/images/LV5.svg'},
          ];

          return AppDrawer(
            headerCard: const AppDrawerHeaderCard(
              icon: Icons.military_tech_rounded,
              iconColor: AppColors.gold,
              title: 'Financial Levels',
              subtitle: 'Earn wealth tiers as your net worth grows',
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const AppBadge.success(text: 'CURRENT'),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  nextLvName != null
                                      ? '${(progress * 100).toStringAsFixed(1)}% to Level ${currentLv + 1} ($nextLvName)'
                                      : 'Max Financial Level Reached!',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
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
                        progress: progress,
                        height: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        progressColor: AppColors.positive,
                      ),
                      const SizedBox(height: 10),

                      // Remaining Balance Statement
                      Text(
                        nextLvName != null
                            ? 'You need ${fmt.format(remaining)} ETB more to reach Level ${currentLv + 1} ($nextLvName).'
                            : 'Congratulations! You have reached the highest financial level.',
                        style: const TextStyle(
                          color: Colors.white,
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
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                l['range'] as String,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.50),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          const AppBadge.success(text: 'CURRENT'),
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
