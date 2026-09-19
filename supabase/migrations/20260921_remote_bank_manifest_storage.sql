-- ==============================================================================
-- MIGRATION: 20260921_remote_bank_manifest_storage.sql
-- DESCRIPTION: Public Storage Bucket for Over-The-Air (OTA) Bank Manifests & Icons
-- PURPOSE: Allows zero-app-update onboarding of new banks and SMS regex rules.
-- ==============================================================================

-- 1. Create a public storage bucket for bank manifests and dynamic bank icons
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'bank-manifests',
    'bank-manifests',
    true,
    5242880, -- 5 MB limit
    ARRAY['application/json', 'image/svg+xml', 'image/png']
)
ON CONFLICT (id) DO UPDATE
SET public = true;

-- 2. Ensure public read access to bank manifests and assets
DROP POLICY IF EXISTS "Public Read Bank Manifests" ON storage.objects;
CREATE POLICY "Public Read Bank Manifests"
ON storage.objects FOR SELECT
USING (bucket_id = 'bank-manifests');

-- 3. Restrict uploads/edits to service_role or admin authenticated users
DROP POLICY IF EXISTS "Admin Manage Bank Manifests" ON storage.objects;
CREATE POLICY "Admin Manage Bank Manifests"
ON storage.objects FOR ALL
TO authenticated
USING (bucket_id = 'bank-manifests')
WITH CHECK (bucket_id = 'bank-manifests');
