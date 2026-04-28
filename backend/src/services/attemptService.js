const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS, QUESTION_TYPES } = require('../utils/constants');
const logger = require('../utils/logger');
const evaluationService = require('./evaluationService');

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
    `SELECT id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status, reviewed_by, reviewed_at, review_notes, created_at, updated_at
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
 * @param {string} codeAnswer - Code submission (for Coding or Essay)
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

    let isCorrect = null;
    let marksObtained = 0;
    let selectedOptionId = null;
    let gradingStatus = 'auto_graded';

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

      const isNumericString =
        typeof selectedOption === 'string' && /^\d+$/.test(selectedOption);
      const selectedOptionIndex =
        typeof selectedOption === 'number'
          ? selectedOption
          : isNumericString
            ? Number.parseInt(selectedOption, 10)
            : null;

      const selectedOptionRecord = Number.isInteger(selectedOptionIndex)
        ? options[selectedOptionIndex]
        : options.find((option) => option.id === selectedOption);

      if (!selectedOptionRecord) {
        throw new ApiError(
          HTTP_STATUS.BAD_REQUEST,
          'Invalid selected option. Provide a valid option id or index.'
        );
      }

      selectedOptionId = selectedOptionRecord.id;
      isCorrect = selectedOptionRecord.is_correct;
      marksObtained = isCorrect ? question.marks : 0;
    }

    // For coding and essay questions, marks will be assigned during review/evaluation
    if (question.type === QUESTION_TYPES.CODING || question.type === QUESTION_TYPES.ESSAY) {
      marksObtained = 0;
      gradingStatus = 'pending_review';
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
         SET selected_option_id = $1, code_answer = $2, is_correct = $3, marks_obtained = $4, grading_status = $5, updated_at = CURRENT_TIMESTAMP
         WHERE attempt_id = $6 AND question_id = $7
         RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status, reviewed_by, reviewed_at, review_notes, created_at, updated_at`,
        [selectedOptionId || null, codeAnswer || null, isCorrect, marksObtained, gradingStatus, attemptId, questionId]
      );
      response = updateResult.rows[0];
    } else {
      // Insert new response
      const insertResult = await client.query(
        `INSERT INTO question_responses (attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status, reviewed_by, reviewed_at, review_notes, created_at, updated_at`,
        [attemptId, questionId, selectedOptionId || null, codeAnswer || null, isCorrect, marksObtained, gradingStatus]
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
 * Manually review a coding or essay response
 * @param {string} attemptId - Attempt ID
 * @param {string} responseId - Response ID
 * @param {number} marksObtained - Final marks awarded
 * @param {string} reviewerId - Admin user ID reviewing the response
 * @param {string} reviewNotes - Optional review notes
 * @returns {Promise<Object>} Reviewed response and refreshed result if available
 */
const reviewResponse = async (attemptId, responseId, marksObtained, reviewerId, reviewNotes = null) => {
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    const attemptResult = await client.query(
      `SELECT id, test_id, user_id, status FROM test_attempts WHERE id = $1`,
      [attemptId]
    );

    if (attemptResult.rows.length === 0) {
      throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found');
    }

    const responseResult = await client.query(
      `SELECT qr.id, qr.question_id, qr.marks_obtained, qr.grading_status, q.type, q.marks
       FROM question_responses qr
       JOIN questions q ON q.id = qr.question_id
       WHERE qr.id = $1 AND qr.attempt_id = $2`,
      [responseId, attemptId]
    );

    if (responseResult.rows.length === 0) {
      throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Response not found');
    }

    const response = responseResult.rows[0];

    if (response.type === QUESTION_TYPES.MCQ) {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'MCQ responses are auto-graded and cannot be manually reviewed'
      );
    }

    const finalMarks = Number(marksObtained);

    if (!Number.isFinite(finalMarks) || finalMarks < 0 || finalMarks > response.marks) {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        `marksObtained must be a number between 0 and ${response.marks}`
      );
    }

    const updateResult = await client.query(
      `UPDATE question_responses
       SET marks_obtained = $1,
           grading_status = 'reviewed',
           reviewed_by = $2,
           reviewed_at = CURRENT_TIMESTAMP,
           review_notes = $3,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $4 AND attempt_id = $5
       RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status, reviewed_by, reviewed_at, review_notes, created_at, updated_at`,
      [finalMarks, reviewerId, reviewNotes, responseId, attemptId]
    );

    let refreshedResult = null;

    const existingResult = await client.query(
      `SELECT id FROM results WHERE attempt_id = $1`,
      [attemptId]
    );

    if (existingResult.rows.length > 0) {
      const refreshedMetrics = await evaluationService.calculateAttemptMetrics(client, attemptId);

      const resultUpdate = await client.query(
        `UPDATE results
         SET total_marks = $1,
             obtained_marks = $2,
             percentage = $3,
             passed = $4,
             updated_at = CURRENT_TIMESTAMP
         WHERE attempt_id = $5
         RETURNING id, attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed, created_at, updated_at`,
        [
          refreshedMetrics.totalMarks,
          refreshedMetrics.obtainedMarks,
          refreshedMetrics.percentage,
          refreshedMetrics.passed,
          attemptId,
        ]
      );

      await client.query(
        `UPDATE test_attempts
         SET score = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [refreshedMetrics.obtainedMarks, attemptId]
      );

      refreshedResult = {
        result: resultUpdate.rows[0],
        evaluation: refreshedMetrics,
      };
    }

    await client.query('COMMIT');

    return {
      response: updateResult.rows[0],
      refreshedResult,
    };
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      logger.warn('Error rolling back transaction', { error: rollbackError.message });
    }
    logger.error('Error reviewing response', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Submit entire test - delegate to evaluation service for scoring
 * Idempotent: Multiple submissions return same result instead of erroring
 * @param {string} attemptId - Attempt ID
 * @returns {Promise<Object>} Completed attempt with result details
 */
const submitAttempt = async (attemptId) => {
  try {
    // Use evaluation service to evaluate and create result record
    const evaluationResult = await evaluationService.evaluateAttempt(attemptId);

    // Get the updated attempt details
    const attemptResult = await db.query(
      `SELECT id, test_id, user_id, start_time, end_time, status, score, created_at, updated_at
       FROM test_attempts WHERE id = $1`,
      [attemptId]
    );

    const attempt = attemptResult.rows[0];

    const logMessage = evaluationResult.isRetry 
      ? 'Test attempt resubmitted (idempotent - returning cached result)'
      : 'Test attempt submitted and evaluated';

    logger.info(logMessage, {
      attemptId,
      obtained: evaluationResult.evaluation.obtainedMarks,
      total: evaluationResult.evaluation.totalMarks,
      percentage: evaluationResult.evaluation.percentage,
      passed: evaluationResult.evaluation.passed,
      isRetry: evaluationResult.isRetry,
    });

    return {
      attempt,
      result: evaluationResult.evaluation,
      resultRecord: evaluationResult.result,
      isRetry: evaluationResult.isRetry,
    };
  } catch (error) {
    logger.error('Error submitting attempt', { error: error.message });
    throw error;
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

/**
 * Get all pending coding/essay evaluations for admin review
 * @returns {Promise<Object>} Pending evaluations grouped by attempt
 */
const getPendingEvaluations = async () => {
  const result = await db.query(
    `SELECT qr.id AS response_id,
            qr.attempt_id,
            qr.question_id,
            qr.code_answer,
            qr.grading_status,
            qr.created_at AS response_created_at,
            q.question_text,
            q.marks AS question_marks,
            q.type AS question_type,
            a.test_id,
            a.user_id,
            a.end_time,
            a.status AS attempt_status,
            t.title AS test_title,
            u.name AS candidate_name,
            u.email AS candidate_email
     FROM question_responses qr
     JOIN questions q ON q.id = qr.question_id
     JOIN test_attempts a ON a.id = qr.attempt_id
     JOIN tests t ON t.id = a.test_id
     JOIN users u ON u.id = a.user_id
     WHERE qr.grading_status = 'pending_review'
       AND q.type IN ('coding', 'essay')
       AND a.status = 'submitted'
     ORDER BY a.end_time DESC NULLS LAST, qr.created_at ASC`
  );

  const grouped = new Map();

  result.rows.forEach((row) => {
    if (!grouped.has(row.attempt_id)) {
      grouped.set(row.attempt_id, {
        attemptId: row.attempt_id,
        testId: row.test_id,
        testTitle: row.test_title,
        candidateId: row.user_id,
        candidateName: row.candidate_name,
        candidateEmail: row.candidate_email,
        submittedAt: row.end_time,
        pendingCount: 0,
        pendingResponses: [],
      });
    }

    const attempt = grouped.get(row.attempt_id);
    attempt.pendingCount += 1;
    attempt.pendingResponses.push({
      responseId: row.response_id,
      questionId: row.question_id,
      questionType: row.question_type,
      questionText: row.question_text,
      questionMarks: row.question_marks,
      answer: row.code_answer,
      gradingStatus: row.grading_status,
      submittedAt: row.response_created_at,
    });
  });

  const pendingEvaluations = Array.from(grouped.values());

  return {
    pendingEvaluations,
    summary: {
      attempts: pendingEvaluations.length,
      responses: result.rows.length,
    },
  };
};

module.exports = {
  startAttempt,
  getAttempt,
  submitResponse,
  reviewResponse,
  submitAttempt,
  getUserAttempts,
  getTestAttempts,
  getPendingEvaluations,
};
