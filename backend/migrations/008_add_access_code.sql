-- UP: production-safe access_code migration
ALTER TABLE tests
ADD COLUMN IF NOT EXISTS access_code VARCHAR(255);

-- Keep nullable for legacy rows (safe in production)
ALTER TABLE tests
ALTER COLUMN access_code DROP NOT NULL;

-- Optional one-time backfill for existing NULL rows (run only if needed)
-- UPDATE tests
-- SET access_code = 'legacy_' || substr(md5(random()::text || clock_timestamp()::text), 1, 12)
-- WHERE access_code IS NULL;

-- DOWN
-- ALTER TABLE tests DROP COLUMN IF EXISTS access_code;