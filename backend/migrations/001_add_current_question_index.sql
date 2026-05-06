-- Migration: Add current_question_index to test_attempts for resume support
-- Also adds duration_minutes column to track per-attempt duration (source of truth)

ALTER TABLE test_attempts
ADD COLUMN IF NOT EXISTS current_question_index INTEGER DEFAULT 0;

-- Index for fast active attempt lookups
CREATE INDEX IF NOT EXISTS idx_test_attempts_user_status 
ON test_attempts(user_id, status) 
WHERE status = 'in_progress';