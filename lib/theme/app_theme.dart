import 'package:flutter/material.dart';
export '../widgets/app_switch.dart';

class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color gold      = Color(0xFFF0B90B); // Brand golden accent

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF050C16); // Main scaffold background (#050C16)
  static const Color bgMid      = Color(0xFF050C16); // Secondary background / gradient mid (#050C16)
  static const Color bgDeep     = Color(0xFF050C16); // Deepest background stop (#050C16)

  // ── Surfaces & Cards ──────────────────────────────────────────────────────
  static const Color surface        = Color(0xFF111821); // Base card/panel surface (#111821)
  static const Color surfaceCard    = Color(0xFF111821); // Raised card surface (#111821)
  static const Color tabBackground  = Color(0xFF111821); // Capsule tab & loan card background (#111821)
  static const Color cardDarkHex    = Color(0xFF111821); // Defined card background color (#111821)
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
  static const Color statusActiveBg  = Color(0xFF0F3A2E); // Deep emerald background for active status
  static const Color statusWarningBg = Color(0xFF3A240F); // Deep amber background for warning status
  static const Color previewCardBg   = Color(0xFF141D2B); // Dark navy tint for notification preview card

  // ── Tier Level Glows ──────────────────────────────────────────────────────
  static const Color levelGlow1 = Color(0xFF8B9DFF);
  static const Color levelGlow2 = Color(0xFF38BDF8);
  static const Color levelGlow3 = Color(0xFFAC58FE);
  static const Color levelGlow4 = Color(0xFFF87171);
  static const Color levelGlow5 = Color(0xFFFBBF24);

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

  // ── Saving Card & Progress Bar Palette ─────────────────────────────────
  static const Color savingCardTopLeft     = Color(0xFFD55B43);
  static const Color savingCardCenter      = Color(0xFF8B2231);
  static const Color savingCardBottomRight = Color(0xFF9A2551);
  static const Color savingProgressDark    = Color(0xFF7E1C30);
  static const Color savingProgressGradStart = Color(0xFFFF6846);
  static const Color savingProgressGradEnd   = Color(0xFFFE9F99);
  static const Color activeBadgeBg         = Color(0xFFDCFCE7);
  static const Color activeBadgeText       = Color(0xFF166534);

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
  static const Color cardBoaBg        = Color(0xFFFFB800); // BOA Golden Yellow
  static const Color cardBoaDarkIcon  = Color(0xFFC68000); // BOA Deep Amber
  static const Color cardBoaTitle     = Color(0xFF1D1302); // BOA Dark Bronze Text
  static const Color cardBoaObsidianDark = Color(0xFF181510); // BOA Dark Obsidian
  static const Color cardBoaObsidianLight = Color(0xFF2C2010); // BOA Dark Bronze Gradient
  static const Color cardBoaWhite     = Color(0xFFFFFFFF); // BOA Crisp White
  static const Color cardDashenBg     = Color(0xFFF9B825);
  static const Color cardDashenDarkIcon = Color(0xFF805A04);
  static const Color cardDashenTitle  = Color(0xFFFFF1C6);
  static const Color cardCoopBg       = Color(0xFF5E35B1);
  static const Color cardCoopDarkIcon = Color(0xFF2E175B);
  static const Color cardCoopTitle    = Color(0xFFD1C4E9);
  // ── Stat Cards Palette (Dashboard Analytics) ────────────────────────────────
  static const Color statCardExpenseMonthBg        = Color(0xFF9E4B2D); // Terracotta reddish-brown
  static const Color statCardExpenseMonthDarkIcon  = Color(0xFF542412);
  static const Color statCardExpenseMonthTitle     = Color(0xFFE8BDB0);

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

  // ── Paused Tracking State ──────────────────────────────────────────────────
  /// Amber badge/button background used when a bank's tracking is paused.
  static const Color pausedBadge        = Color(0xFFB45309); // dark amber
  /// Text / icon color on the amber pause badge.
  static const Color pausedBadgeText    = Color(0xFFFFFFFF);
  /// Amber border drawn around a paused bank card.
  static const Color pausedBorder       = Color(0xFFFFB74D); // = AppColors.amber
  /// Dark greyscale gradient stop for a paused card (start / top).
  static const Color pausedCardDark     = Color(0xFF2A2A2A);
  /// Mid greyscale gradient stop for a paused card (end / bottom).
  static const Color pausedCardMid      = Color(0xFF4A4A4A);
  /// Glow / shadow color for paused card.
  static const Color pausedCardGlow     = Color(0xFF888888);

  // ── Central UI Palette Additions ─────────────────────────────────────────
  static const Color dragHandleDark     = Color(0xFF0F172A);
  static const Color navyDark           = Color(0xFF0F172A);
  static const Color navyCard           = Color(0xFF161F2C);
  static const Color deepNavy           = Color(0xFF0E1520);
  static const Color darkSheetBg        = Color(0xFF141419);
  static const Color darkTileBg         = Color(0xFF16181D);
  static const Color midnightBlack      = Color(0xFF09090D);
  static const Color slatePanel         = Color(0xFF1E293B);
  static const Color slateBorder        = Color(0xFF334155);
  static const Color slateMuted         = Color(0xFF64748B);
  static const Color slateLight         = Color(0xFFCBD5E1);
  static const Color slateSurface       = Color(0xFFF1F5F9);
  static const Color whiterGlow         = Color(0xFFF8FAFC);
  static const Color emeraldDeep        = Color(0xFF00875A);
  static const Color emeraldBright      = Color(0xFF00A86B);
  static const Color amberDark          = Color(0xFFFFA000);
  static const Color softRed            = Color(0xFFFF6B6B);
  static const Color grayLight          = Color(0xFFE5E7EB);
  static const Color grayDarkText       = Color(0xFF374151);
  static const Color grayMuted          = Color(0xFF8E95A2);
  static const Color skyBlue            = Color(0xFF0284C7);
  static const Color onboardingDark     = Color(0xFF071410);
  static const Color onboardingDeep     = Color(0xFF060D0A);


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
