import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
export '../widgets/app_switch.dart';
export '../widgets/app_svg_icon.dart';
export '../widgets/app_icon_badge.dart';
export 'app_typography.dart';

class AppColors {
  static const Color brandGreen = Color(0xFF3EB489); // Primary brand emerald green accent (#3EB489)
  static const Color gold       = brandGreen; // Accent color (mapped to primary brand green)

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color background = Color(0xFF060B12); // Main scaffold background (#060B12)
  static const Color bgMid      = background; // Secondary background / gradient mid (#060B12)
  static const Color bgDeep     = background; // Deepest background stop (#060B12)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Light theme scaffold background
  static const Color bgMidLight      = Color(0xFFF1F5F9); // Light theme mid gradient
  static const Color bgDeepLight     = Color(0xFFE2E8F0); // Light theme deep gradient

  // ── Surfaces & Cards ──────────────────────────────────────────────────────
  static const Color surface        = Color(0xFF111821); // Base card/panel surface (#111821)
  static const Color surfaceElevated = Color(0xFF141D28); // Elevated surface tone (modal & bottom drawer background)
  static const Color drawerCard     = Color(0x0AFFFFFF); // 4% subtle white translucent glass surface over surfaceElevated for modal & drawer cards/inputs
  static const Color modalCard      = drawerCard; // Alias for drawerCard
  static const Color overlay        = surfaceElevated; // Replaced legacy #2A2A34 with #141D28
  static const Color bottomNavDark  = Color(0xFF141D28); // Elevated navy-slate surface
  static const Color bottomNavBg    = Color(0xFC141D28); // 99% translucent frosted elevated dark glass (#141D28 @ 99%)
  static const Color bottomNavBgLight = Color(0xFCFFFFFF); // 99% translucent frosted white glass
  static const Color bottomNavBorder = Color(0x3DFFFFFF); // Subtle translucent white specular rim (24% opacity)
  static const Color surfaceLight   = Color(0xFFFFFFFF); // Light theme card surface
  static const Color cardTileLight  = Color(0xFFF1F5F9); // Light theme elevated tile
  static const Color glassSurface   = Color(0x59111821); // 35% dark surface glass
  static const Color glassSurfaceSubtle = Color(0x1A111821); // 10% dark surface glass
  static const Color glassSurfaceModal  = surfaceElevated; // Solid elevated modal surface tone (#141D28)
  static const double glassBlurSigma    = 20.0; // Centralized glass blur radius
  static const Color destructiveSurface = Color(0x24E11D48); // 14% destructive soft surface
  static const Color tabBackground      = Color(0xFF09101A); // Deep recessed navy track for capsule tabs
  static const Color tabBackgroundLight = Color(0xFFE2E8F0); // Inset slate track for light theme capsule tabs

  // ── Button Palette ────────────────────────────────────────────────────────
  static const Color buttonPrimary          = Color(0xFFFFFFFF); // Primary button pure crisp white (#FFFFFF)
  static const Color buttonPrimaryText      = Color(0xFF0F172A); // Primary button dark contrast text (#0F172A)
  static const Color buttonPrimaryDisabled  = Color(0x66FFFFFF); // Primary button disabled state (40% white)
  static const Color buttonPrimaryOnLight   = Color(0xFF0F172A); // Primary button solid dark slate on light backgrounds
  static const Color buttonPrimaryTextOnLight = Color(0xFFFFFFFF); // Primary button clean white text on light backgrounds
  static const Color buttonSecondary        = Color(0x1FFFFFFF); // Glass-like translucent dark button (12% white)
  static const Color buttonSecondaryText    = Color(0xFFFFFFFF); // Secondary button clean white text
  static const Color buttonSecondaryOnLight = Color(0x140F172A); // Translucent dark slate (8% opacity) for light backgrounds
  static const Color buttonSecondaryTextOnLight = Color(0xFF0F172A); // Secondary button dark slate text on light backgrounds
  static const Color buttonDestructive      = Color(0xFFE11D48); // Destructive button red
  static const Color buttonDestructiveText  = Color(0xFFFFFFFF); // Destructive button text
  static const Color buttonGlass            = Color(0x1AFFFFFF); // Translucent glass action button

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
  static const Color previewCardBg   = drawerCard; // 4% subtle white glass for modal/drawer cards & preview sections

  // ── Badge Solid Colors ────────────────────────────────────────────────────
  static const Color badgeSuccessBg     = Color(0xFF0BA751); // Solid Emerald Green (#0BA751)
  static const Color badgeWarningBg     = Color(0xFFE67E22); // Solid Amber / Orange (#E67E22)
  static const Color badgeDestructiveBg = Color(0xFFE11D48); // Solid Crimson Red (#E11D48)
  static const Color badgeNeutralBg     = Color(0xFF2A3441); // Solid Slate Surface (#2A3441)
  static const Color badgeInfoBg        = Color(0xFF2563EB); // Solid Royal Blue (#2563EB)
  static const Color sim1BadgeBg        = Color(0xFF0F766E); // Solid Deep Teal / Emerald (#0F766E) for SIM 1
  static const Color sim2BadgeBg        = Color(0xFF7C3AED); // Solid Royal Violet / Purple (#7C3AED) for SIM 2

  // ── Tier Level Glows ──────────────────────────────────────────────────────
  static const Color levelGlow1 = Color(0xFF8B9DFF);
  static const Color levelGlow2 = Color(0xFF38BDF8);
  static const Color levelGlow3 = Color(0xFFAC58FE);
  static const Color levelGlow4 = Color(0xFFF87171);
  static const Color levelGlow5 = Color(0xFFFBBF24);

  // ── Daily Net Heatmap Palette ─────────────────────────────────────────────
  static const Color heatmapHeavyGreen   = Color(0xFF34D399); // Vibrant emerald for high positive daily net
  static const Color heatmapSubtleGreen  = Color(0xFF0F5234); // Deep forest green for moderate positive daily net
  static const Color heatmapNeutral      = Color(0xFF1B2431); // Dark charcoal for zero/no transaction days
  static const Color heatmapNeutralLight = Color(0xFFE2E8F0); // Light slate for zero/no transaction days on light theme
  static const Color heatmapSubtleRed    = Color(0xFF4A1D24); // Deep burgundy for moderate negative daily net
  static const Color heatmapHeavyRed     = levelGlow4; // Vibrant coral red for high negative daily net

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF); // Primary text on dark
  static const Color textSecondary = Color(0xFF9CA3AF); // Secondary / muted text
  static const Color textDisabled  = Color(0xFFC7C7C7); // Disabled / faint text
  static const Color textSoft      = Color(0xCCFFFFFF); // 80% white soft label
  static const Color textPrimaryLight = Color(0xFF0F172A); // Dark slate text for light theme
  static const Color textSecondaryLight = Color(0xFF64748B); // Muted slate text for light theme
  static const Color textDisabledLight  = Color(0xFF94A3B8); // Faint slate text for light theme

  // ── Icon Palette ──────────────────────────────────────────────────────────
  static const Color iconLight            = Color(0xFFFFFFFF); // Clean crisp white icon for dark surfaces
  static const Color iconDark             = Color(0xFF0F172A); // High-contrast dark charcoal icon for light surfaces
  static const Color iconMuted            = Color(0xFF9CA3AF); // Muted grey icon on dark surfaces
  static const Color iconMutedLight       = Color(0xFF64748B); // Muted slate icon on light surfaces

  /// Returns high-contrast monochrome icon color based on background surface or light/dark mode.
  static Color adaptiveIcon({
    bool onLightSurface = false,
    Color? surfaceColor,
    Brightness? brightness,
  }) {
    if (onLightSurface) return iconDark;
    if (surfaceColor != null) {
      return surfaceColor.computeLuminance() > 0.35 ? iconDark : iconLight;
    }
    if (brightness == Brightness.light) return iconDark;
    return iconLight;
  }

  // ── UI Controls ───────────────────────────────────────────────────────────
  static const Color border                 = Color(0x33FFFFFF); // Borders / dividers
  static const Color borderLight            = Color(0x1F000000); // Light theme border
  static const Color borderSubtleLight      = Color(0xFFCBD5E1); // Subtle inactive border on light theme
  static const Color donutInactiveRingDark  = Color(0x1AFFFFFF); // 10% white inactive donut chart ring on dark theme
  static const Color toggleActive         = Color(0xFF34C759); // iOS toggle on
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

  // ── CBE & CBE Birr Palette ────────────────────────────────────────────────
  static const Color cbePurple            = Color(0xFF6B4C9A); // Commercial Bank of Ethiopia Purple
  static const Color cbeBirrMagenta       = Color(0xFFE91E63); // CBE Birr Magenta
  static const Color cardCbeBirrDark      = Color(0xFF5E1268); // Deep CBE Birr Brand Violet
  static const Color cardCbeBirrLight     = Color(0xFF9C27B0); // Vibrant CBE Birr Magenta/Purple
  static const Color cardCbeBirrDarkIcon  = Color(0xFF4A0E52); // CBE Birr Dark Accent
  static const Color cardCbeBirrWhite     = Color(0xFFFFFFFF); // Pure white
  static const Color cardCbeBirrSilver    = Color(0xFFE2E8F0); // Sleek white-gray contrast

  // ── Ahadu Bank Palette ───────────────────────────────────────────────────
  static const Color cardAhaduRedDark  = Color(0xFF6B031F); // Deep burgundy / dark crimson base (#6B031F)
  static const Color cardAhaduRed      = Color(0xFFA90533); // Official Ahadu Brand Crimson (#A90533)
  static const Color cardAhaduRedLight = Color(0xFFC71545); // Vibrant Ahadu Crimson highlight (#C71545)
  static const Color cardAhaduPink     = Color(0xFFFFE7EE); // Soft blush pink / tint (FFE7EE)
  static const Color cardAhaduWhite    = Color(0xFFFFFFFF); // Crisp white

  // ── Extended Bank Card Palettes ────────────────────────────────────────────
  static const Color cardCbeBg        = Color(0xFF1B5E4B);
  static const Color cardCbeDarkIcon  = Color(0xFF0F3A2E);
  static const Color cardCbeTitle     = Color(0xFF88C9B8);
  static const Color cardBoaBg        = Color(0xFFFFB800); // BOA Golden Yellow
  static const Color cardBoaDarkIcon  = Color(0xFFC68000); // BOA Deep Amber
  static const Color cardBoaTitle     = Color(0xFFFFFFFF); // BOA Clean Crisp White Text
  static const Color cardBoaObsidianDark = Color(0xFF181510); // BOA Dark Obsidian
  static const Color cardBoaObsidianLight = Color(0xFF2C2010); // BOA Dark Bronze Gradient
  static const Color cardDashenDark     = Color(0xFF162068); // Dashen Navy Blue (From Logo SVG #162068)
  static const Color cardDashenLight    = Color(0xFF2563EB); // Cool Sapphire Blue Gradient Stop
  static const Color cardDashenBg       = Color(0xFF2563EB); // Dashen Primary Blue
  static const Color cardDashenDarkIcon = Color(0xFF162068); // Dashen Deep Blue Icon Tone
  static const Color cardDashenTitle    = Color(0xFF93C5FD); // Dashen Soft Sky Blue Text
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
  static const Color pausedBadgeText    = textPrimary;
  /// Amber border drawn around a paused bank card.
  static const Color pausedBorder       = amber; // = AppColors.amber
  /// Dark greyscale gradient stop for a paused card (start / top).
  static const Color pausedCardDark     = Color(0xFF2A2A2A);
  /// Mid greyscale gradient stop for a paused card (end / bottom).
  static const Color pausedCardMid      = Color(0xFF4A4A4A);
  /// Glow / shadow color for paused card.
  static const Color pausedCardGlow     = greyText;

  // ── Central UI Palette Additions ─────────────────────────────────────────
  static const Color dragHandleDark     = Color(0xFF0F172A);
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
  static const Color slateDarkText      = Color(0xFF475569);
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

  // Analysis Screen Card Gradient & Glow
  static const Color analysisCardGradientStart = Color(0xFF0C3025);
  static const Color analysisCardGradientMid   = Color(0xFF071F18);
  static const Color analysisCardGradientEnd   = Color(0xFF0D151D);
  static const Color analysisAmbientGlow       = Color(0xFF0E382C);

  // ── Additional Semantic & Dynamic UI Palette ──────────────────────────────
  static const Color destructiveRed            = Color(0xFFFF5252);
  static const Color chartWarmOrange           = Color(0xFFFF9800);
  static const Color chartBrightEmerald        = Color(0xFF10B981);
  static const Color chartSkyBlue              = Color(0xFF3B82F6);
  static const Color chartIndigo               = Color(0xFF6366F1);
  static const Color chartCoralPink            = Color(0xFFEC4899);
  static const Color chartAmberYellow          = Color(0xFFF59E0B);
  static const Color chartCyan                 = Color(0xFF06B6D4);
  static const Color chartTeal                 = Color(0xFF14B8A6);
  static const Color chartPurpleVibrant        = Color(0xFFA855F7);
  static const Color chartLimeGreen            = Color(0xFF84CC16);
  static const Color chartSoftViolet           = Color(0xFF8B5CF6);
  static const Color chartRoyalBlue            = Color(0xFF2563EB);
  static const Color chartDarkEmerald          = Color(0xFF059669);
  static const Color chartBronzeAmber          = Color(0xFFD97706);
  static const Color chartCrimson              = Color(0xFFDC2626);
  static const Color cbeDeepPurple             = Color(0xFF6B4C9A);
  static const Color chartOrange               = Color(0xFFF97316);
  static const Color chartYellow               = Color(0xFFEAB308);
  static const Color chartFuchsia              = Color(0xFFD946EF);
  static const Color savingProgressGreenMid    = Color(0xFF047857);
  static const Color savingProgressGreenDark   = Color(0xFF065F46);
  static const Color savingProgressGreenDeep   = Color(0xFF064E3B);
  static const Color savingProgressPurpleStart = Color(0xFF7C3AED);
  static const Color savingProgressPurpleMid   = Color(0xFF5B21B6);
  static const Color savingProgressPurpleDark  = Color(0xFF4C1D95);
  static const Color savingProgressPurpleDeep  = Color(0xFF3B0764);
  static const Color savingProgressBlueMid     = Color(0xFF1E40AF);
  static const Color savingProgressBlueDark    = Color(0xFF1E3A8A);
  static const Color savingProgressBlueDeep    = Color(0xFF172554);


  static const Color buttonSoftDestructiveBg = Color(0x24E11D48); // Soft red background (14% red)
  static const Color buttonGlassBg           = Color(0x1AFFFFFF); // Translucent glass action background

  static const List<Color> unifiedBankBehindGradient = [
    savingProgressGreenMid, // Color(0xFF047857)
    chartDarkEmerald,       // Color(0xFF059669)
    chartBrightEmerald,     // Color(0xFF10B981)
  ];

  static const List<Color> categoryFallbackPalette = [
    chartSkyBlue,
    chartBrightEmerald,
    chartAmberYellow,
    error,
    chartSoftViolet,
    chartCoralPink,
    chartCyan,
    chartLimeGreen,
    chartPurpleVibrant,
    chartOrange,
    chartTeal,
    chartIndigo,
    chartYellow,
    chartFuchsia,
    skyBlue,
    chartDarkEmerald,
  ];

  static Color getLevelGlow(int level) {
    switch (level) {
      case 1:
        return levelGlow1;
      case 2:
        return levelGlow2;
      case 3:
        return levelGlow3;
      case 4:
        return levelGlow4;
      case 5:
        return levelGlow5;
      default:
        return levelGlow1;
    }
  }

  static Color getCategoryReasonColor(String category) {
    final cat = category.trim().toLowerCase();

    // 0. Uncategorized & other fallback color
    if (cat == 'uncategorized' || cat == 'other' || cat == 'other cash' || cat.isEmpty) {
      return slateMuted; // #64748B
    }

    // 1. Explicit distinct color mapping for defined system reasons
    if (cat == 'food' || cat.contains('restaurant') || cat.contains('dining')) {
      return chartWarmOrange;
    }
    if (cat == 'salary' || cat.contains('wage') || cat.contains('payroll')) {
      return chartBrightEmerald;
    }
    if (cat == 'transport' || cat.contains('taxi') || cat.contains('ride') || cat.contains('bus')) {
      return chartSkyBlue;
    }
    if (cat == 'rent' || cat.contains('home') || cat.contains('house')) {
      return chartIndigo;
    }
    if (cat == 'shopping' || cat.contains('clothes') || cat.contains('apparel')) {
      return chartCoralPink;
    }
    if (cat == 'utilities' || cat.contains('utility') || cat.contains('bill') || cat.contains('electricity')) {
      return chartAmberYellow;
    }
    if (cat == 'internet' || cat.contains('wifi') || cat.contains('broadband')) {
      return chartCyan;
    }
    if (cat == 'fuel' || cat.contains('gas') || cat.contains('petrol')) {
      return error;
    }
    if (cat == 'medical' || cat.contains('health') || cat.contains('pharmacy') || cat.contains('hospital')) {
      return chartTeal;
    }
    if (cat == 'gift' || cat.contains('donation') || cat.contains('charity')) {
      return chartPurpleVibrant;
    }
    if (cat == 'loan' || cat.contains('credit') || cat.contains('debt')) {
      return chartLimeGreen;
    }
    if (cat == 'entertainment' || cat.contains('entertain') || cat.contains('movie') || cat.contains('fun')) {
      return chartSoftViolet;
    }
    if (cat == 'education' || cat.contains('school') || cat.contains('tuition')) {
      return chartRoyalBlue;
    }
    if (cat == 'investment' || cat.contains('stock') || cat.contains('savings')) {
      return chartDarkEmerald;
    }
    if (cat == 'airtime' || cat.contains('recharge') || cat.contains('mobile')) {
      return skyBlue;
    }
    if (cat == 'cash' || cat.contains('atm') || cat.contains('withdrawal')) {
      return chartBronzeAmber;
    }
    if (cat == 'bounce') {
      return chartCrimson;
    }
    if (cat.contains('cbe') || cat.contains('bank')) {
      return cbePurple;
    }
    if (cat.contains('telebirr')) {
      return telebirrGreen;
    }
    if (cat.contains('ahadu')) {
      return cbeBirrMagenta;
    }

    // 2. Deterministic vibrant color for any undefined/custom reasons
    final hash = cat.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return categoryFallbackPalette[hash.abs() % categoryFallbackPalette.length];
  }

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

  static const LinearGradient screenBackgroundGradientLight = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      backgroundLight,
      bgMidLight,
    ],
  );
}

/// Centralized corner radius design tokens across the application.
/// Strictly enforces a single source of truth for cards, sheets, dialogs, and buttons.
class AppRadius {
  /// Single source of truth for all card corner rounding across the application.
  /// Modifying this value will instantly and uniformly change the roundness
  /// of every card throughout the entire app.
  static const double card = 32.0;

  /// Corner radius for smaller / compact card sub-elements or inner cards.
  static const double cardSm = 20.0;

  /// Convenience [BorderRadius] getters:
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get cardRadiusSm => BorderRadius.circular(cardSm);

  /// Standard sheet corner radius
  static const double sheet = 32.0;
  static BorderRadius get sheetRadius => const BorderRadius.vertical(top: Radius.circular(sheet));

  /// Standard dialog corner radius
  static const double dialog = 32.0;
  static BorderRadius get dialogRadius => BorderRadius.circular(dialog);

  /// 100% fully rounded pill button radius
  static const double button = 100.0;
  static BorderRadius get buttonRadius => BorderRadius.circular(button);
}

/// Official Material 3 ThemeExtension for full theme-switching tweening,
/// widget-scoped styling, and architectural purity.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color background;
  final Color bgMid;
  final Color bgDeep;
  final Color surface;
  final Color surfaceElevated;
  final Color cardTile;
  final Color overlay;
  final Color bottomNavBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;
  final Color brandGreen;
  final Color buttonPrimary;
  final Color buttonPrimaryText;
  final Color buttonPrimaryDisabled;
  final Color buttonSecondary;
  final Color buttonSecondaryText;
  final Color buttonDestructive;
  final Color buttonDestructiveText;
  final Color buttonSoftDestructiveBg;
  final Color positive;
  final Color negative;
  final Color warning;
  final Color error;
  final Color info;
  final LinearGradient screenGradient;

  const AppThemeColors({
    required this.background,
    required this.bgMid,
    required this.bgDeep,
    required this.surface,
    required this.surfaceElevated,
    required this.cardTile,
    required this.overlay,
    required this.bottomNavBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.brandGreen,
    required this.buttonPrimary,
    required this.buttonPrimaryText,
    required this.buttonPrimaryDisabled,
    required this.buttonSecondary,
    required this.buttonSecondaryText,
    required this.buttonDestructive,
    required this.buttonDestructiveText,
    required this.buttonSoftDestructiveBg,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.error,
    required this.info,
    required this.screenGradient,
  });

  static const AppThemeColors dark = AppThemeColors(
    background: AppColors.background,
    bgMid: AppColors.bgMid,
    bgDeep: AppColors.bgDeep,
    surface: AppColors.surface,
    surfaceElevated: AppColors.surfaceElevated,
    cardTile: AppColors.darkTileBg,
    overlay: AppColors.overlay,
    bottomNavBg: AppColors.bottomNavBg,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textDisabled: AppColors.textDisabled,
    border: AppColors.border,
    brandGreen: AppColors.brandGreen,
    buttonPrimary: AppColors.buttonPrimary,
    buttonPrimaryText: AppColors.buttonPrimaryText,
    buttonPrimaryDisabled: AppColors.buttonPrimaryDisabled,
    buttonSecondary: AppColors.buttonSecondary,
    buttonSecondaryText: AppColors.buttonSecondaryText,
    buttonDestructive: AppColors.buttonDestructive,
    buttonDestructiveText: AppColors.buttonDestructiveText,
    buttonSoftDestructiveBg: AppColors.buttonSoftDestructiveBg,
    positive: AppColors.positive,
    negative: AppColors.negative,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    screenGradient: AppColors.screenBackgroundGradient,
  );

  static const AppThemeColors light = AppThemeColors(
    background: AppColors.backgroundLight,
    bgMid: AppColors.bgMidLight,
    bgDeep: AppColors.bgDeepLight,
    surface: AppColors.surfaceLight,
    surfaceElevated: AppColors.cardTileLight,
    cardTile: AppColors.cardTileLight,
    overlay: AppColors.surfaceLight,
    bottomNavBg: AppColors.surfaceLight,
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textDisabled: AppColors.textDisabledLight,
    border: AppColors.borderLight,
    brandGreen: AppColors.brandGreen,
    buttonPrimary: AppColors.textPrimaryLight,
    buttonPrimaryText: AppColors.surfaceLight,
    buttonPrimaryDisabled: AppColors.textDisabledLight,
    buttonSecondary: AppColors.cardTileLight,
    buttonSecondaryText: AppColors.textPrimaryLight,
    buttonDestructive: AppColors.buttonDestructive,
    buttonDestructiveText: AppColors.surfaceLight,
    buttonSoftDestructiveBg: AppColors.buttonSoftDestructiveBg,
    positive: AppColors.positive,
    negative: AppColors.negative,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    screenGradient: AppColors.screenBackgroundGradientLight,
  );

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? bgMid,
    Color? bgDeep,
    Color? surface,
    Color? surfaceElevated,
    Color? cardTile,
    Color? overlay,
    Color? bottomNavBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
    Color? brandGreen,
    Color? buttonPrimary,
    Color? buttonPrimaryText,
    Color? buttonPrimaryDisabled,
    Color? buttonSecondary,
    Color? buttonSecondaryText,
    Color? buttonDestructive,
    Color? buttonDestructiveText,
    Color? buttonSoftDestructiveBg,
    Color? positive,
    Color? negative,
    Color? warning,
    Color? error,
    Color? info,
    LinearGradient? screenGradient,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      bgMid: bgMid ?? this.bgMid,
      bgDeep: bgDeep ?? this.bgDeep,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      cardTile: cardTile ?? this.cardTile,
      overlay: overlay ?? this.overlay,
      bottomNavBg: bottomNavBg ?? this.bottomNavBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDisabled: textDisabled ?? this.textDisabled,
      border: border ?? this.border,
      brandGreen: brandGreen ?? this.brandGreen,
      buttonPrimary: buttonPrimary ?? this.buttonPrimary,
      buttonPrimaryText: buttonPrimaryText ?? this.buttonPrimaryText,
      buttonPrimaryDisabled: buttonPrimaryDisabled ?? this.buttonPrimaryDisabled,
      buttonSecondary: buttonSecondary ?? this.buttonSecondary,
      buttonSecondaryText: buttonSecondaryText ?? this.buttonSecondaryText,
      buttonDestructive: buttonDestructive ?? this.buttonDestructive,
      buttonDestructiveText: buttonDestructiveText ?? this.buttonDestructiveText,
      buttonSoftDestructiveBg: buttonSoftDestructiveBg ?? this.buttonSoftDestructiveBg,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      screenGradient: screenGradient ?? this.screenGradient,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t) ?? background,
      bgMid: Color.lerp(bgMid, other.bgMid, t) ?? bgMid,
      bgDeep: Color.lerp(bgDeep, other.bgDeep, t) ?? bgDeep,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t) ?? surfaceElevated,
      cardTile: Color.lerp(cardTile, other.cardTile, t) ?? cardTile,
      overlay: Color.lerp(overlay, other.overlay, t) ?? overlay,
      bottomNavBg: Color.lerp(bottomNavBg, other.bottomNavBg, t) ?? bottomNavBg,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t) ?? textDisabled,
      border: Color.lerp(border, other.border, t) ?? border,
      brandGreen: Color.lerp(brandGreen, other.brandGreen, t) ?? brandGreen,
      buttonPrimary: Color.lerp(buttonPrimary, other.buttonPrimary, t) ?? buttonPrimary,
      buttonPrimaryText: Color.lerp(buttonPrimaryText, other.buttonPrimaryText, t) ?? buttonPrimaryText,
      buttonPrimaryDisabled: Color.lerp(buttonPrimaryDisabled, other.buttonPrimaryDisabled, t) ?? buttonPrimaryDisabled,
      buttonSecondary: Color.lerp(buttonSecondary, other.buttonSecondary, t) ?? buttonSecondary,
      buttonSecondaryText: Color.lerp(buttonSecondaryText, other.buttonSecondaryText, t) ?? buttonSecondaryText,
      buttonDestructive: Color.lerp(buttonDestructive, other.buttonDestructive, t) ?? buttonDestructive,
      buttonDestructiveText: Color.lerp(buttonDestructiveText, other.buttonDestructiveText, t) ?? buttonDestructiveText,
      buttonSoftDestructiveBg: Color.lerp(buttonSoftDestructiveBg, other.buttonSoftDestructiveBg, t) ?? buttonSoftDestructiveBg,
      positive: Color.lerp(positive, other.positive, t) ?? positive,
      negative: Color.lerp(negative, other.negative, t) ?? negative,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      error: Color.lerp(error, other.error, t) ?? error,
      info: Color.lerp(info, other.info, t) ?? info,
      screenGradient: LinearGradient.lerp(screenGradient, other.screenGradient, t) ?? screenGradient,
    );
  }
}

enum AppThemeMode {
  hybrid,
  light,
  dark,
}

extension AppThemeContext on BuildContext {
  bool get isLightMode => Theme.of(this).brightness == Brightness.light;
  AppThemeColors get themeColors =>
      Theme.of(this).extension<AppThemeColors>() ??
      (isLightMode ? AppThemeColors.light : AppThemeColors.dark);

  Color get themeBackground => themeColors.background;
  Color get themeSurface => themeColors.surface;
  Color get themeSurfaceElevated => themeColors.surfaceElevated;
  Color get themeTextPrimary => themeColors.textPrimary;
  Color get themeTextSecondary => themeColors.textSecondary;
  Color get themeTextDisabled => themeColors.textDisabled;
  Color get themeBorder => themeColors.border;
  Color get themeTileBg => themeColors.cardTile;

  Color get themeIconPrimary => isLightMode ? AppColors.iconDark : AppColors.iconLight;
  Color get themeIconMuted => isLightMode ? AppColors.iconMutedLight : AppColors.iconMuted;

  /// Dynamically resolves high-contrast icon color based on background surface or light/dark mode.
  Color adaptiveIconColor({bool? onLightSurface, Color? surfaceColor}) {
    if (onLightSurface != null) {
      return onLightSurface ? AppColors.iconDark : AppColors.iconLight;
    }
    if (surfaceColor != null) {
      return surfaceColor.onIconColor;
    }
    return themeIconPrimary;
  }

  LinearGradient get themeScreenGradient => themeColors.screenGradient;

  SystemUiOverlayStyle get themeOverlayStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness:
            isLightMode ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness:
            isLightMode ? Brightness.dark : Brightness.light,
      );
}

extension ColorContrast on Color {
  /// Returns high-contrast text color based on the background's relative luminance:
  /// - If background is light (luminance > 0.35) -> Dark Slate (#0F172A)
  /// - If background is dark (luminance <= 0.35) -> Crisp White (#FFFFFF)
  Color get onColor => computeLuminance() > 0.35
      ? AppColors.textPrimaryLight
      : Colors.white;

  Color get onColorSecondary => computeLuminance() > 0.35
      ? AppColors.textSecondaryLight
      : AppColors.textSecondary;

  /// High-contrast icon color based on the background's relative luminance:
  /// - If background is light (luminance > 0.35) -> Dark Slate (#0F172A)
  /// - If background is dark (luminance <= 0.35) -> Crisp White (#FFFFFF)
  Color get onIconColor => computeLuminance() > 0.35
      ? AppColors.iconDark
      : AppColors.iconLight;

  Color get onIconMuted => computeLuminance() > 0.35
      ? AppColors.iconMutedLight
      : AppColors.iconMuted;
}

class AppTheme {
  static ThemeData themeFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return lightTheme;
      case AppThemeMode.dark:
        return darkTheme;
      case AppThemeMode.hybrid:
        return hybridTheme;
    }
  }

  static ThemeData get hybridTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.brandGreen,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      extensions: const [AppThemeColors.dark],
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        modalBarrierColor: const Color(0xA6000000), // 65% dark black barrier
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheetRadius,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialogRadius,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: AppColors.buttonPrimaryText,
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.brandGreen,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      cardColor: AppColors.surfaceLight,
      extensions: const [AppThemeColors.light],
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: AppColors.textPrimaryLight,
            displayColor: AppColors.textPrimaryLight,
            fontFamily: 'Inter',
          ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        modalBarrierColor: const Color(0x8C000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheetRadius,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialogRadius,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimaryText,
          foregroundColor: AppColors.buttonPrimary,
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => hybridTheme;
}
