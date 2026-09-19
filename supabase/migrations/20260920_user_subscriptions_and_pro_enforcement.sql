-- ============================================================================
-- Shibre Server-Authoritative Subscriptions & Pro Enforcement Schema
-- Version: 1.4.0
-- Security: Row Level Security (RLS) enabled
-- Realtime: Enabled for user_subscriptions
-- Admin-Controlled: Users have SELECT-only access; write access is restricted
-- ============================================================================

-- 1. Create user_subscriptions Table
CREATE TABLE IF NOT EXISTS public.user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    plan TEXT NOT NULL DEFAULT 'free', -- 'free', 'pro', 'premium'
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'expired', 'canceled'
    valid_until TIMESTAMPTZ, -- NULL means lifetime, otherwise expiration timestamp
    granted_by TEXT DEFAULT 'admin_manual', -- 'admin_manual', 'chapa', 'telebirr', etc.
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_user_subscription UNIQUE (user_id)
);

-- Ensure columns exist if table was already created
ALTER TABLE public.user_subscriptions ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.user_subscriptions ADD COLUMN IF NOT EXISTS plan TEXT NOT NULL DEFAULT 'free';
ALTER TABLE public.user_subscriptions ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
ALTER TABLE public.user_subscriptions ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ;
ALTER TABLE public.user_subscriptions ADD COLUMN IF NOT EXISTS granted_by TEXT DEFAULT 'admin_manual';
ALTER TABLE public.user_subscriptions ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- 2. Enable Row-Level Security
ALTER TABLE public.user_subscriptions ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies: Authenticated users can ONLY SELECT their own subscription record.
-- Critical Security Guardrail: Users CANNOT insert, update, or delete their subscription.
-- Only service_role or Admin via Supabase Dashboard can modify subscription records.
DROP POLICY IF EXISTS "Users can view own subscription" ON public.user_subscriptions;
CREATE POLICY "Users can view own subscription"
    ON public.user_subscriptions
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Explicitly revoke write permissions for anon and authenticated users
REVOKE INSERT, UPDATE, DELETE ON TABLE public.user_subscriptions FROM anon, authenticated;
GRANT SELECT ON TABLE public.user_subscriptions TO authenticated;
GRANT ALL ON TABLE public.user_subscriptions TO service_role;

-- 4. Index for high-speed lookup by user_id and email
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user ON public.user_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_email ON public.user_subscriptions(email);

-- 5. Auto-Provisioning Trigger on New User Signup
-- Whenever a new user signs up in auth.users, automatically initialize a free tier row
CREATE OR REPLACE FUNCTION public.handle_new_user_subscription()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_subscriptions (user_id, email, plan, status)
    VALUES (NEW.id, NEW.email, 'free', 'active')
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created_subscription ON auth.users;
CREATE TRIGGER on_auth_user_created_subscription
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_subscription();

-- Backfill existing auth users if they don't have a subscription row yet
INSERT INTO public.user_subscriptions (user_id, email, plan, status)
SELECT id, email, 'free', 'active'
FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

-- 6. Server-Side Verification Helper Function
-- Can be called from other RLS policies or RPC to verify genuine Pro status
CREATE OR REPLACE FUNCTION public.is_user_pro(target_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    is_pro BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.user_subscriptions
        WHERE user_id = target_user_id
          AND plan IN ('pro', 'premium')
          AND status = 'active'
          AND (valid_until IS NULL OR valid_until > now())
    ) INTO is_pro;
    RETURN is_pro;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Realtime Publication for user_subscriptions
-- Changes made by Admin in Dashboard push immediately to the client app
ALTER TABLE public.user_subscriptions REPLICA IDENTITY FULL;

DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_subscriptions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;

-- 8. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
