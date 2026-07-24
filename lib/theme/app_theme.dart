import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color gold      = Color(0xFFF0B90B); // Brand golden accent

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF050A11); // Main scaffold background (#050a11)
  static const Color bgMid      = Color(0xFF080F1A); // Secondary background / gradient mid
  static const Color bgDeep     = Color(0xFF03060A); // Deepest background stop

  // ── Surfaces & Cards ──────────────────────────────────────────────────────
  static const Color surface        = Color(0xFF121417); // Base card/panel surface
  static const Color surfaceCard    = Color(0xFF1C1F24); // Raised card surface
  static const Color tabBackground  = Color(0xFF191F28); // Capsule tab & loan card background (#191F28)
  static const Color surfaceElevated = Color(0xFF363640); // Elevated surface / divider
  static const Color overlay        = Color(0xFF2A2A34); // Modal / bottom sheet
  static const Color bottomNavBg    = Color(0xFF141924); // Navigation bar & Freeze Account button background (#141924)

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

  // ── CBE Birr Palette ───────────────────────────────────────────────────────
  static const Color cardCbeBirrWhite  = Color(0xFFFFFFFF); // Pure white
  static const Color cardCbeBirrSilver = Color(0xFFE2E8F0); // Sleek white-gray contrast

  // ── Ahadu Bank Palette ───────────────────────────────────────────────────
  static const Color cardAhaduRed   = Color(0xFFC62828); // Ahadu Red / Crimson
  static const Color cardAhaduPink  = Color(0xFFFFE7EE); // Soft blush pink / tint (FFE7EE)
  static const Color cardAhaduWhite = Color(0xFFFFFFFF); // Crisp white

  // ── Extended Bank Card Palettes ────────────────────────────────────────────
  static const Color cardCbeBg        = Color(0xFF1B5E4B);
  static const Color cardCbeDarkIcon  = Color(0xFF0F3A2E);
  static const Color cardCbeTitle     = Color(0xFF88C9B8);
  static const Color cardBoaBg        = Color(0xFF9E4B2D);
  static const Color cardBoaDarkIcon  = Color(0xFF542412);
  static const Color cardBoaTitle     = Color(0xFFE8BDB0);
  static const Color cardDashenBg     = Color(0xFFF9B825);
  static const Color cardDashenDarkIcon = Color(0xFF805A04);
  static const Color cardDashenTitle  = Color(0xFFFFF1C6);
  static const Color cardCoopBg       = Color(0xFF5E35B1);
  static const Color cardCoopDarkIcon = Color(0xFF2E175B);
  static const Color cardCoopTitle    = Color(0xFFD1C4E9);

  // ── Service & Provider Tints ──────────────────────────────────────────────
  static const Color slackPurple       = Color(0xFF4A154B);
  static const Color telebirrGreen     = Color(0xFF00A859);
  static const Color telebirrGreenSoft = Color(0xFFDCF5E8);
  static const Color cbeBirrPink       = Color(0xFFE91E63);

  // ── Neutral Dark/Light & Alerts ────────────────────────────────────────────
  static const Color darkCharcoal       = Color(0xFF1A1A1A);
  static const Color surfaceGreyBlue    = Color(0xFF2A2D36);
  static const Color lightGreyBackground= Color(0xFFF2F4F7);
  static const Color lightGreySurface   = Color(0xFFF0F0F0);
  static const Color mediumGreyText     = Color(0xFF757575);
  static const Color greyText           = Color(0xFF888888);
  static const Color darkGreyText       = Color(0xFF555555);
  static const Color lightGreyText       = Color(0xFFCCCCCC);
  static const Color overlayDark50      = Color(0x80000000);
  static const Color alertRed           = Color(0xFFE53935);
  static const Color alertOrange        = Color(0xFFFF6D00);


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
      primaryColor: AppColors.positive,
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
          backgroundColor: AppColors.positive,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
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
