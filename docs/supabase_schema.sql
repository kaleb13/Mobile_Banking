-- ==============================================================================
-- SHIBRE - PRODUCTION SUPABASE POSTGRESQL SCHEMA MIGRATION
-- ==============================================================================
-- Designed for 1:1 parity with Shibre's local SQLite database.
-- Includes Row-Level Security (RLS), multi-tenant user scoping,
-- automated update triggers, and bidirectional sync support (PowerSync / Realtime).
-- ==============================================================================

-- 1. EXTENSIONS & HELPER FUNCTIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Automated updated_at timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 2. BANK SENDER PROFILES & WALLET CONTAINERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS senders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_name TEXT NOT NULL,
    is_paused BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(user_id, sender_name)
);

ALTER TABLE senders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own senders"
    ON senders FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER trg_senders_updated_at
    BEFORE UPDATE ON senders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 3. REASONS & HIERARCHICAL SPENDING CATEGORIES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    parent_id UUID REFERENCES reasons(id) ON DELETE SET NULL,
    is_special BOOLEAN NOT NULL DEFAULT FALSE,
    icon TEXT,
    color TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE reasons ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own reasons"
    ON reasons FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER trg_reasons_updated_at
    BEFORE UPDATE ON reasons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Reason Counterparty Auto-Links
CREATE TABLE IF NOT EXISTS reason_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason_id UUID NOT NULL REFERENCES reasons(id) ON DELETE CASCADE,
    linked_name TEXT NOT NULL,
    link_type TEXT NOT NULL CHECK (link_type IN ('sender', 'receiver')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE reason_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own reason links"
    ON reason_links FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 4. TRANSACTIONS TABLE (SMS & Manual Banking Records)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY, -- Supports client-generated hash/bankRef or UUID
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    date TIMESTAMPTZ NOT NULL,
    sender TEXT NOT NULL,
    category TEXT NOT NULL,
    raw_message TEXT, -- Optional: Can be omitted in cloud for enhanced privacy
    is_auto_detected BOOLEAN NOT NULL DEFAULT TRUE,
    total_balance NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    reason TEXT,
    reason_id UUID REFERENCES reasons(id) ON DELETE SET NULL,
    category_id UUID REFERENCES reasons(id) ON DELETE SET NULL,
    subcategory_id UUID REFERENCES reasons(id) ON DELETE SET NULL,
    custom_reason_text TEXT,
    note TEXT,
    linked_transaction_id TEXT,
    bank_reference TEXT,
    is_bookmarked BOOLEAN NOT NULL DEFAULT FALSE,
    sim_slot INTEGER NOT NULL DEFAULT 0,
    account_identifier TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own transactions"
    ON transactions FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_supabase_tx_user_date ON transactions(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_supabase_tx_user_type ON transactions(user_id, type);
CREATE INDEX IF NOT EXISTS idx_supabase_tx_bank_ref ON transactions(user_id, bank_reference);

CREATE TRIGGER trg_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 5. CASH WALLET TRANSACTIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cash_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    amount NUMERIC(14, 2) NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    note TEXT,
    reason_id UUID REFERENCES reasons(id) ON DELETE SET NULL,
    category_id UUID REFERENCES reasons(id) ON DELETE SET NULL,
    subcategory_id UUID REFERENCES reasons(id) ON DELETE SET NULL,
    custom_reason_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE cash_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own cash transactions"
    ON cash_transactions FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_supabase_cash_user_date ON cash_transactions(user_id, date DESC);

CREATE TRIGGER trg_cash_transactions_updated_at
    BEFORE UPDATE ON cash_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 6. SAVING GOALS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS saving_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    target_amount NUMERIC(14, 2) NOT NULL,
    current_amount NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    deadline TIMESTAMPTZ,
    color_hex TEXT,
    icon_name TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    priority INTEGER NOT NULL DEFAULT 1,
    note TEXT,
    is_on_hold BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE saving_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own saving goals"
    ON saving_goals FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER trg_saving_goals_updated_at
    BEFORE UPDATE ON saving_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ------------------------------------------------------------------------------
-- 7. LOAN RECORDS & REPAYMENT TRACKING
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS loan_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    borrower_name TEXT NOT NULL,
    amount NUMERIC(14, 2) NOT NULL,
    remaining_amount NUMERIC(14, 2) NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('lent', 'borrowed')),
    date TIMESTAMPTZ NOT NULL,
    due_date TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'active',
    monitored_banks TEXT,
    repayment_history JSONB DEFAULT '[]'::jsonb,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

ALTER TABLE loan_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own loan records"
    ON loan_records FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER trg_loan_records_updated_at
    BEFORE UPDATE ON loan_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
