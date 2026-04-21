const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Start a test attempt - candidate begins taking a test
 * @param {string} testId - Test ID
 * @param {string} userId - User ID (candidate)
 * @returns {Promise<Object>} Created attempt with questions
 */
const startAttempt = async (testId, userId) => {
  try {
    const client = await db.getClient();

    try {
      await client.query('BEGIN');

      // Check if user already has an active attempt for this test
      const existingAttempt = await client.query(
        `SELECT id FROM test_attempts 
         WHERE test_id = $1 AND user_id = $2 AND status = 'in_progress'`,
        [testId, userId]
      );

      if (existingAttempt.rows.length > 0) {
        throw new ApiError(
          HTTP_STATUS.CONFLICT,
          'You already have an active attempt for this test'
        );
      }

      // Create new attempt
      let attempt;
      try {
        const attemptResult = await client.query(
          `INSERT INTO test_attempts (test_id, user_id, start_time, status)
           VALUES ($1, $2, CURRENT_TIMESTAMP, 'in_progress')
           RETURNING id, test_id, user_id, start_time, end_time, status, score, created_at, updated_at`,
          [testId, userId]
        );

        attempt = attemptResult.rows[0];
      } catch (dbError) {
        // Handle unique constraint violation (23505 = unique_violation in PostgreSQL)
        if (dbError.code === '23505') {
          throw new ApiError(
            HTTP_STATUS.CONFLICT,
            'You have already attempted this test'
          );
        }
        // Re-throw other database errors
        throw dbError;
      }

      // Fetch all questions for the test
      const questionsResult = await client.query(
        `SELECT id, test_id, type, question_text, marks, order_index
         FROM questions WHERE test_id = $1 ORDER BY order_index ASC`,
        [testId]
      );

      const questions = questionsResult.rows;

      // For each MCQ question, fetch its options
      for (let question of questions) {
        if (question.type === 'mcq') {
          const optionsResult = await client.query(
            `SELECT id, question_id, option_text, order_index
             FROM mcq_options WHERE question_id = $1 ORDER BY order_index`,
            [question.id]
          );
          question.options = optionsResult.rows;
        } else {
          question.options = [];
        }
      }

      await client.query('COMMIT');

      logger.info('Test attempt started', {
        attemptId: attempt.id,
        testId,
        userId,
      });

      return {
        attempt,
        questions,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('Error starting test attempt', { error: error.message });
    throw error;
  }
};

/**
 * Get attempt details
 * @param {string} attemptId - Attempt ID
 * @returns {Promise<Object>} Attempt with responses
 */
const getAttempt = async (attemptId) => {
  const attemptResult = await db.query(
    `SELECT id, test_id, user_id, start_time, end_time, status, score, created_at, updated_at
     FROM test_attempts WHERE id = $1`,
    [attemptId]
  );

  if (attemptResult.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.NOT_FOUND,
      'Attempt not found'
    );
  }

  const attempt = attemptResult.rows[0];

  // Get all responses for this attempt
  const responsesResult = await db.query(
    `SELECT id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, created_at, updated_at
     FROM question_responses WHERE attempt_id = $1 ORDER BY created_at ASC`,
    [attemptId]
  );

  attempt.responses = responsesResult.rows;

  return attempt;
};

/**
 * Submit an answer to a question
 * @param {string} attemptId - Attempt ID
 * @param {string} questionId - Question ID
 * @param {number} selectedOption - Selected MCQ option index (0-based, for MCQ)
 * @param {string} codeAnswer - Code submission (for Coding)
 * @returns {Promise<Object>} Saved response
 */
const submitResponse = async (attemptId, questionId, selectedOption = null, codeAnswer = null) => {
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    // Verify attempt exists and is in progress
    const attemptResult = await client.query(
      `SELECT id, test_id, user_id, start_time, status FROM test_attempts WHERE id = $1`,
      [attemptId]
    );

    if (attemptResult.rows.length === 0) {
      throw new ApiError(
        HTTP_STATUS.NOT_FOUND,
        'Attempt not found'
      );
    }

    const attempt = attemptResult.rows[0];

    if (attempt.status !== 'in_progress') {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'Cannot submit answers to a completed attempt'
      );
    }

    // Get question details
    const questionResult = await client.query(
      `SELECT id, test_id, type, marks FROM questions WHERE id = $1`,
      [questionId]
    );

    if (questionResult.rows.length === 0) {
      throw new ApiError(
        HTTP_STATUS.NOT_FOUND,
        'Question not found'
      );
    }

    const question = questionResult.rows[0];

    // Validate question belongs to this test
    if (question.test_id !== attempt.test_id) {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'Question does not belong to this test'
      );
    }

    let isCorrect = false;
    let marksObtained = 0;
    let selectedOptionId = null;

    // Auto-grade MCQ
    if (question.type === 'mcq' && selectedOption !== null && selectedOption !== undefined) {
      // Fetch all options for this question, ordered by index
      const optionsResult = await client.query(
        `SELECT id, is_correct, order_index FROM mcq_options 
         WHERE question_id = $1 
         ORDER BY order_index ASC`,
        [questionId]
      );

      const options = optionsResult.rows;

      // Validate selected_option is within bounds
      if (selectedOption < 0 || selectedOption >= options.length) {
        throw new ApiError(
          HTTP_STATUS.BAD_REQUEST,
          `Invalid option index. Valid range: 0-${options.length - 1}`
        );
      }

      // Get the selected option
      const selectedOpt = options[selectedOption];
      selectedOptionId = selectedOpt.id;
      isCorrect = selectedOpt.is_correct;
      marksObtained = isCorrect ? question.marks : 0;
    }

    // For coding questions, marks will be assigned during evaluation phase
    if (question.type === 'coding') {
      marksObtained = 0;
    }

    // Check if response already exists for this question
    const existingResponse = await client.query(
      `SELECT id FROM question_responses WHERE attempt_id = $1 AND question_id = $2`,
      [attemptId, questionId]
    );

    let response;

    if (existingResponse.rows.length > 0) {
      // Update existing response
      const updateResult = await client.query(
        `UPDATE question_responses
         SET selected_option_id = $1, code_answer = $2, is_correct = $3, marks_obtained = $4, updated_at = CURRENT_TIMESTAMP
         WHERE attempt_id = $5 AND question_id = $6
         RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, created_at, updated_at`,
        [selectedOptionId || null, codeAnswer || null, isCorrect, marksObtained, attemptId, questionId]
      );
      response = updateResult.rows[0];
    } else {
      // Insert new response
      const insertResult = await client.query(
        `INSERT INTO question_responses (attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, created_at, updated_at`,
        [attemptId, questionId, selectedOptionId || null, codeAnswer || null, isCorrect, marksObtained]
      );
      response = insertResult.rows[0];
    }

    await client.query('COMMIT');

    logger.info('Response submitted', {
      attemptId,
      questionId,
      isCorrect,
    });

    return response;
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error submitting response', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Submit entire test - mark attempt as submitted and calculate total score
 * @param {string} attemptId - Attempt ID
 * @returns {Promise<Object>} Completed attempt with final score
 */
const submitAttempt = async (attemptId) => {
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    // Get attempt
    const attemptResult = await client.query(
      `SELECT id, test_id, user_id, start_time, status FROM test_attempts WHERE id = $1`,
      [attemptId]
    );

    if (attemptResult.rows.length === 0) {
      throw new ApiError(
        HTTP_STATUS.NOT_FOUND,
        'Attempt not found'
      );
    }

    const attempt = attemptResult.rows[0];

    if (attempt.status !== 'in_progress') {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'Attempt is already submitted'
      );
    }

    // Calculate total score from all responses
    const scoreResult = await client.query(
      `SELECT COALESCE(SUM(marks_obtained), 0) as total_score
       FROM question_responses WHERE attempt_id = $1`,
      [attemptId]
    );

    const totalScore = parseInt(scoreResult.rows[0].total_score);

    // Update attempt: mark as submitted, set end time, calculate score
    const updateResult = await client.query(
      `UPDATE test_attempts
       SET status = 'submitted', end_time = CURRENT_TIMESTAMP, score = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2
       RETURNING id, test_id, user_id, start_time, end_time, status, score, created_at, updated_at`,
      [totalScore, attemptId]
    );

    const completedAttempt = updateResult.rows[0];

    // Get test info to calculate pass status
    const testResult = await client.query(
      `SELECT id, pass_percentage FROM tests WHERE id = $1`,
      [attempt.test_id]
    );

    if (testResult.rows.length === 0) {
      throw new ApiError(
        HTTP_STATUS.NOT_FOUND,
        'Test not found'
      );
    }

    const test = testResult.rows[0];

    // Get total marks for the test
    const totalMarksResult = await client.query(
      `SELECT COALESCE(SUM(marks), 0) as total_marks FROM questions WHERE test_id = $1`,
      [attempt.test_id]
    );

    const totalMarks = parseInt(totalMarksResult.rows[0].total_marks);

    // Calculate percentage
    const percentage = totalMarks > 0 ? Math.round((totalScore / totalMarks) * 100) : 0;
    const passed = percentage >= test.pass_percentage;

    await client.query('COMMIT');

    logger.info('Test attempt submitted', {
      attemptId,
      totalScore,
      percentage,
      passed,
    });

    return {
      attempt: completedAttempt,
      result: {
        totalScore,
        totalMarks,
        percentage,
        passed,
        passPercentage: test.pass_percentage,
      },
    };
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error submitting attempt', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Get all attempts for a user
 * @param {string} userId - User ID
 * @returns {Promise<Array>} User's attempts
 */
const getUserAttempts = async (userId) => {
  const result = await db.query(
    `SELECT a.id, a.test_id, a.user_id, a.start_time, a.end_time, a.status, a.score, a.created_at, a.updated_at,
            t.title as test_title, t.duration_minutes
     FROM test_attempts a
     JOIN tests t ON a.test_id = t.id
     WHERE a.user_id = $1
     ORDER BY a.start_time DESC`,
    [userId]
  );

  return result.rows;
};

/**
 * Get all attempts for a test (admin only)
 * @param {string} testId - Test ID
 * @returns {Promise<Array>} Test's attempts
 */
const getTestAttempts = async (testId) => {
  const result = await db.query(
    `SELECT a.id, a.test_id, a.user_id, a.start_time, a.end_time, a.status, a.score, a.created_at, a.updated_at,
            u.name as user_name, u.email as user_email
     FROM test_attempts a
     JOIN users u ON a.user_id = u.id
     WHERE a.test_id = $1
     ORDER BY a.start_time DESC`,
    [testId]
  );

  return result.rows;
};

module.exports = {
  startAttempt,
  getAttempt,
  submitResponse,
  submitAttempt,
  getUserAttempts,
  getTestAttempts,
};
