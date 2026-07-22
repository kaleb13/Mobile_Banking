import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color gold      = Color(0xFFF0B90B); // Brand golden accent

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF1F1F25); // Main scaffold background
  static const Color bgMid      = Color(0xFF1B1B21); // Secondary background / gradient mid
  static const Color bgDeep     = Color(0xFF0A0B0D); // Deepest background stop

  // ── Surfaces & Cards ──────────────────────────────────────────────────────
  static const Color surface        = Color(0xFF121417); // Base card/panel surface
  static const Color surfaceCard    = Color(0xFF1C1F24); // Raised card surface
  static const Color surfaceElevated = Color(0xFF363640); // Elevated surface / divider
  static const Color overlay        = Color(0xFF2A2A34); // Modal / bottom sheet

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color positive      = Color(0xFF3EB489); // Income / positive amounts
  static const Color negative      = Color(0xFFE11D48); // Expense / negative amounts
  static const Color success       = Color(0xFF0BA751); // Success confirmation
  static const Color successLight  = Color(0xFFA5D6A7); // Light success / pastel green
  static const Color warning       = Color(0xFFE67E22); // Warning / loan overdue
  static const Color error         = Color(0xFFEF4444); // Error / chart alert
  static const Color info          = Color(0xFF64B5F6); // Info accent blue
  static const Color infoLight     = Color(0xFF4FC3F7); // Light info / sky blue
  static const Color coral         = Color(0xFFFF8A65); // Coral / soft orange
  static const Color amber         = Color(0xFFFFB74D); // Warm amber
  static const Color amberFaint    = Color(0xFFFFCC80); // Pale amber / faint gold
  static const Color violet        = Color(0xFFAB47BC); // Violet / purple accent
  static const Color chartPurple   = Color(0xFFCE93D8); // Chart — pastel purple
  static const Color chartPink     = Color(0xFFF48FB1); // Chart — pastel pink
  static const Color tealDark      = Color(0xFF1A2530); // Dark blue-teal surface

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF); // Primary text on dark
  static const Color textSecondary = Color(0xFF9CA3AF); // Secondary / muted text
  static const Color textDisabled  = Color(0xFFC7C7C7); // Disabled / faint text
  static const Color textSoft      = Color(0xCCFFFFFF); // 80% white soft label

  // ── UI Controls ───────────────────────────────────────────────────────────
  static const Color border          = Color(0x33FFFFFF); // Borders / dividers
  static const Color toggleActive    = Color(0xFF34C759); // iOS toggle on
  static const Color toggleInactive  = Color(0xFF39393D); // iOS toggle off
  static const Color brownDark       = Color(0xFF301900); // Dark brown icon tint

  // ── Wallet Card Palette ───────────────────────────────────────────────────
  static const Color cardBrownDark  = Color(0xFF3D1B0F); // Wallet — brown dark
  static const Color cardBrownMid   = Color(0xFF6E482F); // Wallet — brown mid
  static const Color cardLime       = Color(0xFF88BF47); // Wallet — lime green
  static const Color cardSilver     = Color(0xFFAFAFB3); // Wallet — silver text
  static const Color cardGrayDark   = Color(0xFF2F2F39); // Wallet — gray dark
  static const Color cardGrayMid    = Color(0xFF4F4F59); // Wallet — gray mid
  static const Color cardGrayLight  = Color(0xFF3E3E4A); // Wallet — gray light

  // ── Ahadu Bank Palette ───────────────────────────────────────────────────
  static const Color cardAhaduRed   = Color(0xFFC62828); // Ahadu Red / Crimson
  static const Color cardAhaduPink  = Color(0xFFFFE7EE); // Soft blush pink / tint (FFE7EE)
  static const Color cardAhaduWhite = Color(0xFFFFFFFF); // Crisp white

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      background,
      bgMid,
      surface,
      bgDeep,
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  static const LinearGradient screenBackgroundGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      background,
      bgMid,
    ],
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.gold,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// iOS-style toggle switch — use this everywhere instead of raw Switch()
// ─────────────────────────────────────────────────────────────────────────────
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 68,
        height: 30,
        padding: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: value ? AppColors.toggleActive : AppColors.toggleInactive,
          borderRadius: BorderRadius.circular(17),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 38,
            height: 25,
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
