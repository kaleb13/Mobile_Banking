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
