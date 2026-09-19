-- ============================================================================
-- Shibre Cloud Transactions: Device ID Tagging & Bank-Level Batch Control
-- Version: 1.2.0
-- Security: Row Level Security (RLS) enforced
-- Idempotent: Can be run multiple times safely without errors
-- ============================================================================

-- 1. Add device identification columns to cloud_transactions
ALTER TABLE public.cloud_transactions 
    ADD COLUMN IF NOT EXISTS device_fingerprint TEXT;

ALTER TABLE public.cloud_transactions 
    ADD COLUMN IF NOT EXISTS device_model TEXT;

-- 2. Create performance indexes for batch operations
-- Index for batch deletion and filtering by device
CREATE INDEX IF NOT EXISTS idx_cloud_tx_user_device 
    ON public.cloud_transactions(user_id, device_fingerprint);

-- Index for batch deletion and filtering by bank name
CREATE INDEX IF NOT EXISTS idx_cloud_tx_user_bank 
    ON public.cloud_transactions(user_id, bank_name);

-- 3. Comment explanations for database catalog documentation
COMMENT ON COLUMN public.cloud_transactions.device_fingerprint IS 
    'Hardware-backed persistent SHA-256 fingerprint of the physical device that uploaded the transaction';

COMMENT ON COLUMN public.cloud_transactions.device_model IS 
    'Human-readable device model (e.g., Samsung Galaxy A54, Google Pixel 8) that uploaded the transaction';
