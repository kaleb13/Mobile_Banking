import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/finance_provider.dart';
import 'saving_goals_screen.dart';
import 'settings_screen.dart';

Color _levelGlowColor(int level) {
  switch (level) {
    case 1: return const Color(0xFF8B9DFF);
    case 2: return const Color(0xFF34D399);
    case 3: return const Color(0xFF60A5FA);
    case 4: return const Color(0xFFF87171);
    case 5: return const Color(0xFFFBBF24);
    default: return const Color(0xFF8B9DFF);
  }
}

class ProfileHubScreen extends StatelessWidget {
  const ProfileHubScreen({super.key});

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
        backgroundColor: AppColors.background,
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.screenBackgroundGradient,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    
                    // ── Header Row: Title & White Levels Pill ──────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'User Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            _showLevelsInfoDialog(context);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Levels',
                                  style: TextStyle(
                                    color: AppColors.background,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: AppColors.background,
                                  size: 11,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Hero Section: Dynamic Level Badge ─────────────────────
                    Consumer<FinanceProvider>(
                      builder: (context, provider, _) {
                        final level = provider.userLevel;
                        final levelName = provider.userLevelName;
                        final levelDesc = provider.userLevelDescription;
                        final glowColor = _levelGlowColor(level);
                        final badgePath = 'assets/images/LV$level.svg';
                        return Column(
                          children: [
                            SizedBox(
                              width: 140,
                              height: 140,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  OverflowBox(
                                    maxWidth: 340,
                                    maxHeight: 340,
                                    child: Container(
                                      width: 340,
                                      height: 340,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            glowColor.withValues(alpha: 0.45),
                                            glowColor.withValues(alpha: 0.20),
                                            glowColor.withValues(alpha: 0.05),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.35, 0.70, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SvgPicture.asset(badgePath, width: 135, height: 135, fit: BoxFit.contain),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              levelName,
                              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Level $level',
                              style: TextStyle(color: glowColor, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                levelDesc,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, fontWeight: FontWeight.w400, height: 1.45),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // ── Menu List Cards (#111821 bg, no border) ──────────────
                    _buildMenuItemCard(
                      context,
                      title: 'Saving Goals',
                      iconWidget: Image.asset(
                        'assets/images/Saving_Goal_Icon.png',
                        width: 26,
                        height: 26,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavingGoalsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildMenuItemCard(
                      context,
                      title: 'Settings',
                      iconWidget: SvgPicture.asset(
                        'assets/images/Settings_icon.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(
    BuildContext context, {
    required String title,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111821),
            borderRadius: BorderRadius.circular(16),
          ),
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
    );
  }

  void _showLevelsInfoDialog(BuildContext context) {
    const levels = [
      {'level': 1, 'name': 'Survivor', 'range': '≤ 100K ETB', 'badge': 'assets/images/LV1.svg'},
      {'level': 2, 'name': 'Achiever', 'range': '100K – 500K ETB', 'badge': 'assets/images/LV2.svg'},
      {'level': 3, 'name': 'Builder', 'range': '500K – 1M ETB', 'badge': 'assets/images/LV3.svg'},
      {'level': 4, 'name': 'Prospering', 'range': '1M – 5M ETB', 'badge': 'assets/images/LV4.svg'},
      {'level': 5, 'name': 'Elite', 'range': '> 5M ETB', 'badge': 'assets/images/LV5.svg'},
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Financial Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: levels.map((l) {
              final lv = l['level'] as int;
              final glowColor = _levelGlowColor(lv);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SvgPicture.asset(l['badge'] as String, width: 36, height: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LV$lv · ${l['name']}',
                            style: TextStyle(color: glowColor, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            l['range'] as String,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
