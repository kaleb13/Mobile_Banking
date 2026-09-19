-- ============================================================================
-- Shibre Multi-Device Real-Time Cloud Sync & Security Schema
-- Version: 1.1.0
-- Security: Row Level Security (RLS) enabled on all tables
-- Realtime: Enabled for instant multi-device synchronization
-- Idempotent: Can be run multiple times safely without errors
-- ============================================================================

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- 1. Profiles Table (User identity and sync preferences)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    display_name TEXT,
    avatar_url TEXT,
    cloud_sync_enabled BOOLEAN DEFAULT true,
    last_synced_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Ensure columns exist if table was already created previously
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cloud_sync_enabled BOOLEAN DEFAULT true;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view and update own profile" ON public.profiles;
CREATE POLICY "Users can view and update own profile"
    ON public.profiles
    FOR ALL
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

GRANT ALL ON TABLE public.profiles TO authenticated, service_role;

-- 2. User Devices (Anti-fraud, trial enforcement & device binding)
CREATE TABLE IF NOT EXISTS public.user_devices (
    device_fingerprint TEXT PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    device_model TEXT,
    trial_ends_at TIMESTAMPTZ,
    is_blocked BOOLEAN DEFAULT false,
    last_active_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon and authenticated to select user_devices" ON public.user_devices;
CREATE POLICY "Allow anon and authenticated to select user_devices"
    ON public.user_devices
    FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Allow anon and authenticated to insert user_devices" ON public.user_devices;
CREATE POLICY "Allow anon and authenticated to insert user_devices"
    ON public.user_devices
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon and authenticated to update user_devices" ON public.user_devices;
CREATE POLICY "Allow anon and authenticated to update user_devices"
    ON public.user_devices
    FOR UPDATE
    TO anon, authenticated
    USING (true)
    WITH CHECK (true);

GRANT ALL ON TABLE public.user_devices TO anon, authenticated, service_role;

-- 3. Cloud Categories & Subcategories
CREATE TABLE IF NOT EXISTS public.cloud_categories (
    id BIGINT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    parent_id BIGINT,
    icon TEXT,
    color TEXT,
    is_system BOOLEAN DEFAULT false,
    is_special BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, id)
);

ALTER TABLE public.cloud_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own categories" ON public.cloud_categories;
CREATE POLICY "Users can manage own categories"
    ON public.cloud_categories
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_cloud_categories_user ON public.cloud_categories(user_id);
GRANT ALL ON TABLE public.cloud_categories TO authenticated, service_role;

-- 4. Cloud Wallets (Bank accounts and container balances)
CREATE TABLE IF NOT EXISTS public.cloud_wallets (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    account_number TEXT,
    current_balance DOUBLE PRECISION DEFAULT 0.0,
    last_updated TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, sender_name)
);

ALTER TABLE public.cloud_wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own wallets" ON public.cloud_wallets;
CREATE POLICY "Users can manage own wallets"
    ON public.cloud_wallets
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_cloud_wallets_user ON public.cloud_wallets(user_id);
GRANT ALL ON TABLE public.cloud_wallets TO authenticated, service_role;

-- 5. Cloud Transactions (Bank SMS transactions and Cash transactions)
CREATE TABLE IF NOT EXISTS public.cloud_transactions (
    id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    bank_name TEXT NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    type TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    counterparty TEXT,
    total_balance DOUBLE PRECISION DEFAULT 0.0,
    category TEXT DEFAULT 'Auto',
    note TEXT,
    reason TEXT,
    reason_id BIGINT,
    category_id BIGINT,
    subcategory_id BIGINT,
    custom_reason_text TEXT,
    is_bookmarked BOOLEAN DEFAULT false,
    linked_transaction_id TEXT,
    raw_message TEXT,
    sim_slot INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, id)
);

ALTER TABLE public.cloud_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own transactions" ON public.cloud_transactions;
CREATE POLICY "Users can manage own transactions"
    ON public.cloud_transactions
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_cloud_tx_user_date ON public.cloud_transactions(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_cloud_tx_updated ON public.cloud_transactions(user_id, updated_at DESC);
GRANT ALL ON TABLE public.cloud_transactions TO authenticated, service_role;

-- 6. Cloud Saving Goals
CREATE TABLE IF NOT EXISTS public.cloud_saving_goals (
    id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    target_amount DOUBLE PRECISION NOT NULL,
    saved_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    color_theme TEXT DEFAULT 'green',
    target_date TEXT,
    priority INTEGER DEFAULT 1,
    status TEXT DEFAULT 'active',
    allocation_mode TEXT DEFAULT 'global_percent',
    account_allocations JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, id)
);

ALTER TABLE public.cloud_saving_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own saving goals" ON public.cloud_saving_goals;
CREATE POLICY "Users can manage own saving goals"
    ON public.cloud_saving_goals
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

GRANT ALL ON TABLE public.cloud_saving_goals TO authenticated, service_role;

-- 7. Cloud Loans & Repayment Records
CREATE TABLE IF NOT EXISTS public.cloud_loans (
    id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    person_name TEXT NOT NULL,
    loan_type TEXT NOT NULL,
    principal_amount DOUBLE PRECISION NOT NULL,
    paid_amount DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    loan_date TIMESTAMPTZ NOT NULL,
    due_date TIMESTAMPTZ NOT NULL,
    status TEXT DEFAULT 'active',
    note TEXT,
    contract_number TEXT,
    payments JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, id)
);

ALTER TABLE public.cloud_loans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own loans" ON public.cloud_loans;
CREATE POLICY "Users can manage own loans"
    ON public.cloud_loans
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

GRANT ALL ON TABLE public.cloud_loans TO authenticated, service_role;

-- 8. Cloud Deleted Category Tombstones
CREATE TABLE IF NOT EXISTS public.cloud_deleted_reasons (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    parent_name TEXT NOT NULL,
    deleted_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, name, parent_name)
);

ALTER TABLE public.cloud_deleted_reasons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own deleted reasons" ON public.cloud_deleted_reasons;
CREATE POLICY "Users can manage own deleted reasons"
    ON public.cloud_deleted_reasons
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

GRANT ALL ON TABLE public.cloud_deleted_reasons TO authenticated, service_role;

-- 9. Realtime Publication (Safe Idempotent Registration)
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_transactions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_categories;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_wallets;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_saving_goals;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_loans;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;

-- 10. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';

