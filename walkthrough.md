# UI Polish, Collapsing Scroll Headers & Supabase Migration Guide

## 1. Overview
This update addresses the user requests across five key areas:
1. **Supabase Cloud Schema Status & Migration Guide**: Clarifying exactly what SQL changes must be run in Supabase for recent cloud features (Device Fingerprinting, Bank-Level Purge, and Device Sessions).
2. **Dynamic Collapsing Sticky Headers on Scroll**: Built a reusable `AppScrollHeaderBar` component with smooth opacity fading and pinned back arrow, and deployed it to `MyProfileScreen`, `SettingsScreen`, and `AnalysisScreen`.
3. **Danger-Style Action Buttons on Profile**: Converted "Sign Out Account" and "Terminate All Other Sessions" in `MyProfileScreen` to soft destructive red pill buttons (`AppButton.softDestructive`).
4. **Solid Color AppBars for Detail Pages**: Replaced semi-transparent backgrounds with solid `AppColors.background` and added category / bank / calendar icon chips across `TransactionDetailScreen`, `CategoryDetailScreen`, `DateTransactionsScreen`, and `ReasonTransactionsScreen`.
5. **Restored Counterparty Name Accent Color**: Restored the counterparty name in `TransactionDetailScreen` to the primary emerald accent color (`AppColors.positive`).

---

## 2. Supabase Cloud Status: Do You Need to Make Any Changes?

> [!IMPORTANT]
> **Yes, to activate Cloud-side Device Tracking, Batch Cloud Purging by Device, and Multi-Device Session Management, you need to execute the migration SQL in your Supabase SQL Editor.**
>
> If you haven't run the scripts yet, the local app continues working smoothly (using SQLite locally), but cloud sync will omit the device fingerprint until the columns are added.

### Copy-and-Paste Migration SQL for Supabase

Run this in your **Supabase Dashboard -> SQL Editor -> New Query**:

```sql
-- 1. Device Fingerprinting & Bank Filter Controls on cloud_transactions
ALTER TABLE public.cloud_transactions 
ADD COLUMN IF NOT EXISTS device_fingerprint TEXT,
ADD COLUMN IF NOT EXISTS device_model TEXT;

CREATE INDEX IF NOT EXISTS idx_cloud_tx_user_device 
ON public.cloud_transactions(user_id, device_fingerprint);

CREATE INDEX IF NOT EXISTS idx_cloud_tx_user_bank 
ON public.cloud_transactions(user_id, bank_name);

-- 2. Multi-Device Accounts Table (for seeing active/inactive logged-in devices across accounts)
CREATE TABLE IF NOT EXISTS public.device_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_fingerprint TEXT NOT NULL,
  device_model TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  account_email TEXT NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_device_approved BOOLEAN NOT NULL DEFAULT true,
  fcm_token TEXT,
  UNIQUE(device_fingerprint, user_id)
);

CREATE INDEX IF NOT EXISTS idx_device_accounts_fingerprint ON public.device_accounts(device_fingerprint);
CREATE INDEX IF NOT EXISTS idx_device_accounts_user_id ON public.device_accounts(user_id);

ALTER TABLE public.device_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to read their device registrations"
  ON public.device_accounts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR device_fingerprint IS NOT NULL);

CREATE POLICY "Allow users to insert device registrations"
  ON public.device_accounts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Allow users to update their device registrations"
  ON public.device_accounts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Allow users to delete their device registrations"
  ON public.device_accounts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
```

---

## 3. UI Changes & Features

### A. Reusable Collapsing Sticky Scroll Header (`AppScrollHeaderBar`)
- **Location**: `lib/widgets/app_scroll_header_bar.dart` (exported in `lib/widgets/widgets.dart`).
- **Behavior**:
  - At scroll offset 0, background is transparent and only the back button is visible.
  - As the user scrolls up (content moves under the header), a solid surface background smoothly fades in along with an icon/avatar and title.
  - Performance: Uses `AnimatedBuilder` attached directly to the `ScrollController`, avoiding full-screen rebuilds.
- **Implemented on**:
  1. `MyProfileScreen`: Displays user's squircle avatar (`BorderRadius.circular(10)`) and account display name when scrolling past profile hero header.
  2. `SettingsScreen`: Displays settings icon chip and "Settings" title.
  3. `AnalysisScreen`: Displays analytics icon chip, category spending title, and trailing filter pill.

### B. Danger-Indicator Action Buttons on Profile
- In `lib/screens/dashboard/my_profile_screen.dart`:
  - **"Sign Out Account"**: Changed to `AppButton.softDestructive` (100% pill shape, soft red background `#E11D48` @ 14%, red text and icon).
  - **"Terminate All Other Sessions"**: Changed to `AppButton.softDestructive` to visually reflect its destructive security nature.

### C. Solid Color AppBars with Leading Icon Chips
- Detail pages now use solid backgrounds (`AppColors.background`) rather than translucent `withValues(alpha: 0.85)`:
  - `TransactionDetailScreen`: Bank logo icon chip + solid `AppColors.background`.
  - `CategoryDetailScreen`: Category icon chip + solid `AppColors.background`.
  - `DateTransactionsScreen`: Calendar icon chip + solid `AppColors.background`.
  - `ReasonTransactionsScreen`: Category/reason icon chip + solid `AppColors.background`.

### D. Counterparty Name Color Restoration
- In `lib/screens/dashboard/transaction_detail_screen.dart`:
  - Added `valueColor` support to `_buildCollapsibleInfoRow`.
  - Counterparty name text is now rendered with `AppColors.positive` (emerald green primary accent).
  - The insight spark icon next to counterparty name is styled with `AppColors.positive`.

---

## 4. Verification & Testing

1. **Dart Static Analysis**:
   ```bash
   dart analyze lib/widgets/app_scroll_header_bar.dart lib/screens/dashboard/my_profile_screen.dart lib/screens/dashboard/settings_screen.dart lib/screens/dashboard/analysis_screen.dart lib/screens/dashboard/transaction_detail_screen.dart lib/screens/dashboard/category_detail_screen.dart lib/screens/dashboard/date_transactions_screen.dart lib/screens/dashboard/reason_transactions_screen.dart
   # Result: No issues found! (Clean 0 errors/warnings)
   ```

2. **AppScrollHeaderBar Tests**:
   - `test/widgets/app_scroll_header_bar_test.dart` passes with 100% success rate.
