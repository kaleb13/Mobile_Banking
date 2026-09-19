# UI & Design System Rules

Strictly adhere to the following UI guidelines for all Flutter widget and screen implementations across the entire application:

## 1. No Borders or Border Strokes
- **NEVER** use borders, border strokes, or outlines (`Border.all`, `BorderSide`, `BoxBorder`, `ShapeDecoration(side: ...)`, or stroked `OutlineInputBorder`).
- Achieve depth, hierarchy, and card separation purely through background surface colors (`AppColors.surface`, `AppColors.surfaceElevated`, `AppColors.tabBackground`) and subtle radius clipping—never outlines or stroke lines.

## 2. Mandatory 100% Fully Rounded Buttons (Pill Shape)
- **ALL** buttons, clickable chips, action pills, and sub-child button elements **MUST be 100% fully rounded (pill shape)** (`BorderRadius.circular(100)` or `StadiumBorder`).
- **NEVER** use half-rounded rectangles, squircles, or small corner radii (e.g., radius 8, 10, 12, 14, 20) on buttons anywhere in the system.

## 3. Standardized Button Color & Hierarchy System
Follow a YouTube-style action hierarchy:
- **Primary Button (`AppButton.primary`)**:
  - Background: Crisp solid **White** (`AppColors.buttonPrimary` = `#FFFFFF`).
  - Text & Icons: Dark slate/charcoal contrast (`AppColors.buttonPrimaryText` = `#0F172A`).
  - Shape: 100% Fully rounded pill (`borderRadius: 100.0`).
  - *Note*: Primary button is clean white, NOT primary emerald green.
- **Secondary Button (`AppButton.secondary`)**:
  - Background: **Glass-like translucent dark** (`AppColors.buttonSecondary` = `Color(0x1FFFFFFF)` / 12% white opacity).
  - Text & Icons: Clean **White** (`AppColors.buttonSecondaryText` = `#FFFFFF`).
  - Shape: 100% Fully rounded pill (`borderRadius: 100.0`).
  - Usage: Secondary actions, toolbar pills, bookmarks, like/share style actions.
- **Destructive Button (`AppButton.destructive` / `softDestructive`)**:
  - Background: Vibrant red (`#E11D48`) or soft red tint (`#E11D48` @ 14%).
  - Shape: 100% Fully rounded pill (`borderRadius: 100.0`).
- **Ghost Button (`AppButton.ghost`)**:
  - Background: Transparent with white / muted text, fully rounded pill.
- **Pill / Filter Chips (`AppButton.pill`)**:
  - Fully rounded pill (`borderRadius: 100.0`). Selected = white or brand accent; Unselected = glass translucent dark.

## 4. Strict Centralized Color Palette
- **NEVER** use inline hardcoded colors (e.g., `Color(0xFF...)`), Flutter built-ins (`Colors.black`, `Colors.white`, `Colors.blue`), or `color: Colors.xxx.withOpacity(...)`.
- **ALWAYS** use constants defined in `AppColors` (`package:mobile_banking/theme/app_theme.dart`).
- If a new color is genuinely required, define it first as a named constant in `AppColors` before referencing it.

## 5. Mandatory Use of Defined Components
- **NEVER** construct raw, ad-hoc replacements for existing design system components.
- **ALWAYS** check and reuse the pre-built widgets in `lib/widgets/`:
  - Buttons: `AppButton` (Primary = White pill, Secondary = Glass pill), `AppBackButton`
  - Cards & Panels: `AppCard`
  - Inputs & Search: `AppTextField`, `AppSearchBar`, `AppDropdown`
  - Navigation & Tabs: `AppCapsuleTabBar`, `AppHeader`
  - Controls & Tiles: `AppSwitch`, `AppListTile`, `AppBadge`
  - Sheets & Dialogs: `AppBottomSheet`, `AppConfirmDialog`

## 6. Typography & Styling
- Always use `AppTypography` text styles (`AppTypography.headline`, `AppTypography.bodyMedium`, `AppTypography.button`, etc.) rather than ad-hoc inline `TextStyle` definitions.

## 7. Mandatory Full-Width Cards with Border Radius Rounding (Zero Horizontal Margins)
- **EVERY** card, section container, and panel placed on the app's primary background **MUST stretch the full width of the screen** (`width: double.infinity` with zero horizontal margins or padding on the outer scrollable list / page container).
- **NEVER** add horizontal margins (e.g. `EdgeInsets.symmetric(horizontal: 16)`) to card containers on plain pages. Cards must extend edge-to-edge across the screen horizontally.
- **MANDATORY BORDER RADIUS ROUNDING**: Full-width cards **MUST ALWAYS have border radius rounding** (`borderRadius: AppRadius.cardRadius` / `BorderRadius.circular(AppRadius.card)` / 32px with `clipBehavior: Clip.antiAlias`). Full width does NOT mean flat, square-cornered blocks. Depth, hierarchy, and card separation are achieved through background surface colors and subtle radius clipping.
- Inset content using internal padding *inside* the card (e.g., `padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16)`), never external margins on the card itself.

## 8. No Primary Color on Decorative Elements & Feature Icons (Use White Variants)
- **NEVER** use primary emerald green (`AppColors.brandGreen`, `AppColors.positive`) for:
  - Avatar rings, concentric story strokes, or circular border indicators (use clean white variants).
  - Plus button backgrounds on avatars (use crisp solid white `AppColors.buttonPrimary` with `#0F172A` dark slate icon).
  - Feature icons (trending up, sync/cloud icons, auto-awesome, insights, split breakdown, checkmarks).
  - Progress bars in profile/tier sections (use clean white `Colors.white` / `AppColors.textPrimaryLight`).
- **ALWAYS** use clean **White variants** (`Colors.white`, `AppColors.buttonSecondary` glass white, or `AppColors.badgeNeutralBg`) for decorative strokes, progress bars, and icons.
- **Allowed Green Usage**: Primary emerald green (`AppColors.positive` / `AppBadge.success`) is strictly reserved for:
  - Monetary inflow / income numbers (`+ETB`).
  - Active state indicators: `CLOUD SYNC`, tier progress percentage (`85.0%` / `MAX`), and active account (`ACTIVE`).

## 9. Rounded Rectangle Profile Avatars
- **NEVER** render user profile pictures, initials, or avatars as circles (`BoxShape.circle` or `ClipOval`).
- **ALWAYS** render profile avatars as deeply rounded rectangles (squircles):
  - Hero profile avatars (88–92px): `BorderRadius.circular(34–36)` outer stroke, `31.5–33.5` spacer gap, `29–31` image clip.
  - Connected account listing / cards (38–40px): `BorderRadius.circular(16)`.
  - Modal menus & dialogs (28–30px): `BorderRadius.circular(12)`.
  - Bottom navigation bar (20–22px): `BorderRadius.circular(8.5)` image, `11` outer stroke responding to active/inactive color.

## 10. No Subtitles or Descriptions on Page Titles
- **NEVER** add descriptive subtitle text or explanations beneath page titles in screen headers (e.g., do NOT add "Two-way sync with Supabase" or "Offline JSON files on device storage" under the screen title).
- Screen headers must be clean, minimal, and punchy: only the title, standard back button, and optional trailing action icon (e.g. using `AppHeader(title: '...', trailing: ...)` with `subtitle: null`).

