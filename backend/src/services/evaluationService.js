const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

const calculateAttemptMetrics = async (client, attemptId) => {
  const attemptResult = await client.query(
    `SELECT id, test_id, user_id, status FROM test_attempts WHERE id = $1`,
    [attemptId]
  );

  if (attemptResult.rows.length === 0) {
    throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found');
  }

  const attempt = attemptResult.rows[0];

  const testResult = await client.query(
    `SELECT id, pass_percentage FROM tests WHERE id = $1`,
    [attempt.test_id]
  );

  if (testResult.rows.length === 0) {
    throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Test not found');
  }

  const test = testResult.rows[0];

  const questionsResult = await client.query(
    `SELECT id, marks, type FROM questions WHERE test_id = $1`,
    [attempt.test_id]
  );

  const responsesResult = await client.query(
    `SELECT id, question_id, is_correct, marks_obtained, grading_status
     FROM question_responses
     WHERE attempt_id = $1`,
    [attemptId]
  );

  const totalMarks = questionsResult.rows.reduce((sum, question) => sum + question.marks, 0);
  const obtainedMarks = responsesResult.rows.reduce(
    (sum, response) => sum + (response.marks_obtained || 0),
    0
  );
  const percentage = totalMarks > 0 ? Math.round((obtainedMarks / totalMarks) * 100) : 0;
  const passed = percentage >= test.pass_percentage;

  return {
    attempt,
    test,
    questions: questionsResult.rows,
    responses: responsesResult.rows,
    totalMarks,
    obtainedMarks,
    percentage,
    passed,
  };
};

/**
 * Evaluate all responses for an attempt and create result record
 * Idempotent: Returns existing result if attempt already submitted
 * @param {string} attemptId - Attempt ID
 * @returns {Promise<Object>} Result with scoring details
 */
const evaluateAttempt = async (attemptId) => {
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    const attemptResult = await client.query(
      `SELECT id, test_id, user_id, status FROM test_attempts WHERE id = $1`,
      [attemptId]
    );

    if (attemptResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found');
    }

    const attempt = attemptResult.rows[0];

    const existingResultQuery = await client.query(
      `SELECT id, total_marks, obtained_marks, percentage, passed FROM results WHERE attempt_id = $1`,
      [attemptId]
    );

    if (existingResultQuery.rows.length > 0) {
      const existingResult = existingResultQuery.rows[0];
      await client.query('ROLLBACK');

      logger.info('Attempt already evaluated, returning existing result', { attemptId });

      return {
        result: existingResult,
        evaluation: {
          totalMarks: existingResult.total_marks,
          obtainedMarks: existingResult.obtained_marks,
          percentage: existingResult.percentage,
          passed: existingResult.passed,
          passPercentage: null,
        },
        isRetry: true,
      };
    }

    if (attempt.status !== 'in_progress') {
      await client.query('ROLLBACK');
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'Attempt cannot be evaluated. Status must be "in_progress".'
      );
    }

    const evaluation = await calculateAttemptMetrics(client, attemptId);

    const resultInsertResult = await client.query(
      `INSERT INTO results (attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed, created_at, updated_at`,
      [
        attemptId,
        attempt.test_id,
        attempt.user_id,
        evaluation.totalMarks,
        evaluation.obtainedMarks,
        evaluation.percentage,
        evaluation.passed,
      ]
    );

    const result = resultInsertResult.rows[0];

    await client.query(
      `UPDATE test_attempts
       SET status = 'submitted', end_time = CURRENT_TIMESTAMP, score = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [evaluation.obtainedMarks, attemptId]
    );

    await client.query('COMMIT');

    logger.info('Attempt evaluated successfully', {
      attemptId,
      totalMarks: evaluation.totalMarks,
      obtainedMarks: evaluation.obtainedMarks,
      percentage: evaluation.percentage,
      passed: evaluation.passed,
    });

    return {
      result,
      evaluation: {
        totalMarks: evaluation.totalMarks,
        obtainedMarks: evaluation.obtainedMarks,
        percentage: evaluation.percentage,
        passed: evaluation.passed,
        passPercentage: evaluation.test.pass_percentage,
      },
      isRetry: false,
    };
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      logger.warn('Error rolling back transaction', { error: rollbackError.message });
    }
    logger.error('Error evaluating attempt', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Refresh an already submitted attempt result after manual review changes
 * @param {string} attemptId - Attempt ID
 * @returns {Promise<Object|null>} Updated result details or null if not submitted yet
 */
const refreshSubmittedAttemptResult = async (attemptId) => {
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    const attemptResult = await client.query(
      `SELECT id, status FROM test_attempts WHERE id = $1`,
      [attemptId]
    );

    if (attemptResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found');
    }

    const resultResult = await client.query(
      `SELECT id FROM results WHERE attempt_id = $1`,
      [attemptId]
    );

    if (resultResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return null;
    }

    const evaluation = await calculateAttemptMetrics(client, attemptId);

    const updatedResult = await client.query(
      `UPDATE results
       SET total_marks = $1,
           obtained_marks = $2,
           percentage = $3,
           passed = $4,
           updated_at = CURRENT_TIMESTAMP
       WHERE attempt_id = $5
       RETURNING id, attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed, created_at, updated_at`,
      [
        evaluation.totalMarks,
        evaluation.obtainedMarks,
        evaluation.percentage,
        evaluation.passed,
        attemptId,
      ]
    );

    await client.query(
      `UPDATE test_attempts
       SET score = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [evaluation.obtainedMarks, attemptId]
    );

    await client.query('COMMIT');

    return {
      result: updatedResult.rows[0],
      evaluation,
      isRetry: false,
      attemptStatus: attemptResult.rows[0].status,
    };
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch (rollbackError) {
      logger.warn('Error rolling back transaction', { error: rollbackError.message });
    }
    logger.error('Error refreshing submitted attempt result', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

/**
 * Get result for an attempt
 * @param {string} attemptId - Attempt ID
 * @returns {Promise<Object>} Result record with evaluation details
 */
const getResult = async (attemptId) => {
  const resultResult = await db.query(
    `SELECT id, attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed, created_at, updated_at
     FROM results WHERE attempt_id = $1`,
    [attemptId]
  );

  if (resultResult.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.NOT_FOUND,
      'Result not found'
    );
  }

  const result = resultResult.rows[0];

  // Get attempt details
  const attemptResult = await db.query(
    `SELECT id, test_id, user_id, start_time, end_time, status, score 
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

  // Get test details
  const testResult = await db.query(
    `SELECT id, title, description, pass_percentage 
     FROM tests WHERE id = $1`,
    [result.test_id]
  );

  const test = testResult.rows.length > 0 ? testResult.rows[0] : null;

  const breakdownResult = await db.query(
    `SELECT COUNT(*)::int AS total_questions,
            COUNT(*) FILTER (WHERE q.type = 'mcq')::int AS total_mcq_questions,
            COUNT(*) FILTER (WHERE q.type = 'coding')::int AS total_coding_questions,
            COUNT(*) FILTER (WHERE q.type IN ('coding', 'essay'))::int AS total_manual_questions,
            COALESCE(SUM(CASE WHEN q.type = 'mcq' THEN q.marks ELSE 0 END), 0)::int AS total_mcq_marks,
            COALESCE(SUM(CASE WHEN q.type = 'mcq' THEN COALESCE(qr.marks_obtained, 0) ELSE 0 END), 0)::int AS obtained_mcq_marks,
            COUNT(*) FILTER (WHERE q.type = 'mcq' AND qr.is_correct = true)::int AS correct_mcq_count,
            COUNT(*) FILTER (WHERE q.type = 'mcq' AND qr.id IS NOT NULL AND qr.is_correct = false)::int AS wrong_mcq_count,
            COUNT(*) FILTER (WHERE q.type = 'coding' AND COALESCE(qr.marks_obtained, 0) >= q.marks)::int AS correct_coding_count,
            COUNT(*) FILTER (WHERE q.type IN ('coding', 'essay') AND qr.grading_status = 'pending_review')::int AS pending_manual_count,
            COUNT(*) FILTER (WHERE q.type IN ('coding', 'essay') AND qr.grading_status = 'reviewed')::int AS reviewed_manual_count
     FROM questions q
     LEFT JOIN question_responses qr
       ON qr.question_id = q.id AND qr.attempt_id = $1
     WHERE q.test_id = $2`,
    [attemptId, attempt.test_id]
  );

  const breakdown = breakdownResult.rows[0] || {};

  // Get individual question responses with review data for the candidate
  const responsesResult = await db.query(
    `SELECT q.id AS question_id, q.question_text, q.type, q.marks AS max_marks,
            qr.id AS response_id, qr.code_answer, qr.selected_option_id,
            qr.is_correct, qr.marks_obtained, qr.grading_status,
            qr.review_notes, qr.reviewed_by, qr.reviewed_at,
            mo.option_text AS selected_option_text
     FROM questions q
     LEFT JOIN question_responses qr
       ON qr.question_id = q.id AND qr.attempt_id = $1
     LEFT JOIN mcq_options mo ON mo.id = qr.selected_option_id
     WHERE q.test_id = $2
     ORDER BY q.order_index`,
    [attemptId, attempt.test_id]
  );

  const responses = responsesResult.rows;

  return {
    result,
    attempt,
    test,
    breakdown,
    responses,
  };
};

/**
 * Get all results for a test
 * @param {string} testId - Test ID
 * @returns {Promise<Array>} Array of results for the test
 */
const getTestResults = async (testId) => {
  const resultsResult = await db.query(
    `SELECT r.id, r.attempt_id, r.test_id, r.user_id, r.total_marks, r.obtained_marks, r.percentage, r.passed, r.created_at, r.updated_at,
            u.name as user_name, u.email as user_email,
            a.start_time, a.end_time, a.status as attempt_status
     FROM results r
     JOIN users u ON r.user_id = u.id
     JOIN test_attempts a ON r.attempt_id = a.id
     WHERE r.test_id = $1
     ORDER BY r.created_at DESC`,
    [testId]
  );

  return resultsResult.rows;
};

/**
 * Get all results for a candidate
 * @param {string} userId - User ID
 * @returns {Promise<Array>} Array of results for the candidate
 */
const getCandidateResults = async (userId) => {
  const resultsResult = await db.query(
    `SELECT r.id, r.attempt_id, r.test_id, r.user_id, r.total_marks, r.obtained_marks, r.percentage, r.passed, r.created_at, r.updated_at,
            t.title as test_title, t.pass_percentage,
            a.start_time, a.end_time
     FROM results r
     JOIN tests t ON r.test_id = t.id
     JOIN test_attempts a ON r.attempt_id = a.id
     WHERE r.user_id = $1
     ORDER BY r.created_at DESC`,
    [userId]
  );

  return resultsResult.rows;
};

/**
 * Get result statistics for a test
 * @param {string} testId - Test ID
 * @returns {Promise<Object>} Statistics about test attempts and results
 */
const getTestStatistics = async (testId) => {
  const statsResult = await db.query(
    `SELECT 
       COUNT(*) as total_attempts,
       COUNT(CASE WHEN passed = true THEN 1 END) as passed_count,
       COUNT(CASE WHEN passed = false THEN 1 END) as failed_count,
       ROUND(AVG(percentage)::numeric, 2) as average_percentage,
       MAX(obtained_marks) as highest_score,
       MIN(obtained_marks) as lowest_score,
       ROUND(AVG(obtained_marks)::numeric, 2) as average_score
     FROM results
     WHERE test_id = $1`,
    [testId]
  );

  if (statsResult.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.NOT_FOUND,
      'No results found for this test'
    );
  }

  const stats = statsResult.rows[0];

  return {
    totalAttempts: parseInt(stats.total_attempts),
    passedCount: parseInt(stats.passed_count),
    failedCount: parseInt(stats.failed_count),
    averagePercentage: parseFloat(stats.average_percentage) || 0,
    highestScore: parseInt(stats.highest_score) || 0,
    lowestScore: parseInt(stats.lowest_score) || 0,
    averageScore: parseFloat(stats.average_score) || 0,
    passRate: stats.total_attempts > 0 
      ? Math.round((parseInt(stats.passed_count) / parseInt(stats.total_attempts)) * 100)
      : 0,
  };
};

module.exports = {
  evaluateAttempt,
  calculateAttemptMetrics,
  refreshSubmittedAttemptResult,
  getResult,
  getTestResults,
  getCandidateResults,
  getTestStatistics,
};
