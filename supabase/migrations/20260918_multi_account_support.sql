-- ============================================================================
-- Shibre Multi-Account Device Binding Schema
-- Version: 1.2.0
-- Security: Row Level Security (RLS) enabled
-- Purpose: Tracks multiple authenticated accounts per physical device
-- ============================================================================

-- 1. Device Accounts Table (Associates multiple user accounts to a single physical device)
CREATE TABLE IF NOT EXISTS public.device_accounts (
    device_fingerprint TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT false,
    last_used_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (device_fingerprint, user_id)
);

ALTER TABLE public.device_accounts ENABLE ROW LEVEL SECURITY;

-- 2. Row Level Security Policies
DROP POLICY IF EXISTS "Users can view own device accounts" ON public.device_accounts;
CREATE POLICY "Users can view own device accounts"
    ON public.device_accounts
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own device accounts" ON public.device_accounts;
CREATE POLICY "Users can insert own device accounts"
    ON public.device_accounts
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own device accounts" ON public.device_accounts;
CREATE POLICY "Users can update own device accounts"
    ON public.device_accounts
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own device accounts" ON public.device_accounts;
CREATE POLICY "Users can delete own device accounts"
    ON public.device_accounts
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

GRANT ALL ON TABLE public.device_accounts TO authenticated, service_role;

CREATE INDEX IF NOT EXISTS idx_device_accounts_fingerprint ON public.device_accounts(device_fingerprint);
CREATE INDEX IF NOT EXISTS idx_device_accounts_user ON public.device_accounts(user_id);

-- 3. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
