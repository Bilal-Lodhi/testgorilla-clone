-- Allow essay questions and add manual review metadata for non-MCQ answers

ALTER TABLE questions
  DROP CONSTRAINT IF EXISTS questions_type_check;

ALTER TABLE questions
  ADD CONSTRAINT questions_type_check
  CHECK (type IN ('mcq', 'coding', 'essay'));

ALTER TABLE question_responses
  ADD COLUMN IF NOT EXISTS grading_status VARCHAR(50) NOT NULL DEFAULT 'auto_graded',
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP,
  ADD COLUMN IF NOT EXISTS review_notes TEXT;
