-- ============================================================================
-- Shibre Cloud Sync: Transaction Splits (Multi-Category Itemization) Schema
-- Version: 1.4.0
-- Security: Row Level Security (RLS) enabled on all tables
-- Realtime: Enabled for instant multi-device synchronization
-- Idempotent: Can be run multiple times safely without errors
-- ============================================================================

-- 1. Cloud Transaction Splits Table
CREATE TABLE IF NOT EXISTS public.cloud_transaction_splits (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    transaction_id TEXT NOT NULL,
    split_index INT NOT NULL,
    amount NUMERIC NOT NULL,
    reason_name TEXT,
    parent_reason_name TEXT,
    category_name TEXT,
    custom_reason_text TEXT,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, transaction_id, split_index)
);

ALTER TABLE public.cloud_transaction_splits ENABLE ROW LEVEL SECURITY;

-- 2. Row Level Security Policies for cloud_transaction_splits
DROP POLICY IF EXISTS "Users can view own transaction splits" ON public.cloud_transaction_splits;
CREATE POLICY "Users can view own transaction splits"
    ON public.cloud_transaction_splits
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transaction splits" ON public.cloud_transaction_splits;
CREATE POLICY "Users can insert own transaction splits"
    ON public.cloud_transaction_splits
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own transaction splits" ON public.cloud_transaction_splits;
CREATE POLICY "Users can update own transaction splits"
    ON public.cloud_transaction_splits
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own transaction splits" ON public.cloud_transaction_splits;
CREATE POLICY "Users can delete own transaction splits"
    ON public.cloud_transaction_splits
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

GRANT ALL ON TABLE public.cloud_transaction_splits TO authenticated, service_role;

CREATE INDEX IF NOT EXISTS idx_cloud_splits_user_tx ON public.cloud_transaction_splits(user_id, transaction_id);

-- 3. Realtime Publication for cloud_transaction_splits
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_transaction_splits;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
