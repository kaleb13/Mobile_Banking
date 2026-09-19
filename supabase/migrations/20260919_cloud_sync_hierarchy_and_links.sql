-- ============================================================================
-- Shibre Cloud Sync: Hierarchy Preservation & Linked Users Schema
-- Version: 1.3.0
-- Security: Row Level Security (RLS) enabled on all tables
-- Realtime: Enabled for cloud_reason_links
-- Idempotent: Can be run multiple times safely without errors
-- ============================================================================

-- 1. Extend cloud_categories with parent_name for natural hierarchy preservation
ALTER TABLE public.cloud_categories ADD COLUMN IF NOT EXISTS parent_name TEXT;

-- 2. Cloud Reason Links Table (Contact/Counterparty auto-categorization rules)
CREATE TABLE IF NOT EXISTS public.cloud_reason_links (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    linked_name TEXT NOT NULL,
    link_type TEXT NOT NULL,
    reason_name TEXT NOT NULL,
    parent_reason_name TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, linked_name, link_type)
);

ALTER TABLE public.cloud_reason_links ENABLE ROW LEVEL SECURITY;

-- 3. Row Level Security Policies for cloud_reason_links
DROP POLICY IF EXISTS "Users can view own reason links" ON public.cloud_reason_links;
CREATE POLICY "Users can view own reason links"
    ON public.cloud_reason_links
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own reason links" ON public.cloud_reason_links;
CREATE POLICY "Users can insert own reason links"
    ON public.cloud_reason_links
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own reason links" ON public.cloud_reason_links;
CREATE POLICY "Users can update own reason links"
    ON public.cloud_reason_links
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own reason links" ON public.cloud_reason_links;
CREATE POLICY "Users can delete own reason links"
    ON public.cloud_reason_links
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

GRANT ALL ON TABLE public.cloud_reason_links TO authenticated, service_role;

CREATE INDEX IF NOT EXISTS idx_cloud_reason_links_user ON public.cloud_reason_links(user_id);

-- 4. Realtime Publication for cloud_reason_links
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_reason_links;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;

-- 5. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
