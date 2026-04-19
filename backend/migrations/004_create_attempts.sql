-- Create test_attempts table
CREATE TABLE IF NOT EXISTS test_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  end_time TIMESTAMP,
  status VARCHAR(50) NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted')),
  score INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(test_id, user_id)
);

-- Create question_responses table
CREATE TABLE IF NOT EXISTS question_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id UUID NOT NULL REFERENCES test_attempts(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  selected_option_id UUID,
  code_answer TEXT,
  is_correct BOOLEAN DEFAULT false,
  marks_obtained INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_test_attempts_test_id ON test_attempts(test_id);
CREATE INDEX IF NOT EXISTS idx_test_attempts_user_id ON test_attempts(user_id);
CREATE INDEX IF NOT EXISTS idx_test_attempts_status ON test_attempts(status);
CREATE INDEX IF NOT EXISTS idx_question_responses_attempt_id ON question_responses(attempt_id);
CREATE INDEX IF NOT EXISTS idx_question_responses_question_id ON question_responses(question_id);

-- Create trigger to update test_attempts updated_at
CREATE OR REPLACE FUNCTION update_test_attempts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_test_attempts_updated_at ON test_attempts;
CREATE TRIGGER trigger_test_attempts_updated_at
  BEFORE UPDATE ON test_attempts
  FOR EACH ROW
  EXECUTE FUNCTION update_test_attempts_updated_at();

-- Create trigger to update question_responses updated_at
CREATE OR REPLACE FUNCTION update_question_responses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_question_responses_updated_at ON question_responses;
CREATE TRIGGER trigger_question_responses_updated_at
  BEFORE UPDATE ON question_responses
  FOR EACH ROW
  EXECUTE FUNCTION update_question_responses_updated_at();
