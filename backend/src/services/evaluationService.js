const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Evaluate all responses for an attempt and create result record
 * @param {string} attemptId - Attempt ID
 * @returns {Promise<Object>} Result with scoring details
 */
const evaluateAttempt = async (attemptId) => {
  const client = await db.getClient();

  try {
    await client.query('BEGIN');

    // Get attempt details
    const attemptResult = await client.query(
      `SELECT id, test_id, user_id, status FROM test_attempts WHERE id = $1`,
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
        'Attempt is not in progress. Cannot evaluate.'
      );
    }

    // Get test details
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

    // Get all questions for the test with their marks
    const questionsResult = await client.query(
      `SELECT id, marks, type FROM questions WHERE test_id = $1`,
      [attempt.test_id]
    );

    const questions = questionsResult.rows;
    const questionMarksMap = {};
    let totalMarks = 0;

    questions.forEach(q => {
      questionMarksMap[q.id] = q.marks;
      totalMarks += q.marks;
    });

    // Get all responses for this attempt
    const responsesResult = await client.query(
      `SELECT id, question_id, is_correct, marks_obtained 
       FROM question_responses 
       WHERE attempt_id = $1`,
      [attemptId]
    );

    const responses = responsesResult.rows;

    // Calculate obtained marks
    let obtainedMarks = 0;
    responses.forEach(response => {
      obtainedMarks += response.marks_obtained || 0;
    });

    // Calculate percentage
    const percentage = totalMarks > 0 ? Math.round((obtainedMarks / totalMarks) * 100) : 0;
    const passed = percentage >= test.pass_percentage;

    // Create result record
    const resultInsertResult = await client.query(
      `INSERT INTO results (attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed, created_at, updated_at`,
      [attemptId, attempt.test_id, attempt.user_id, totalMarks, obtainedMarks, percentage, passed]
    );

    const result = resultInsertResult.rows[0];

    // Update attempt: mark as submitted, set end_time, set score
    await client.query(
      `UPDATE test_attempts 
       SET status = 'submitted', end_time = CURRENT_TIMESTAMP, score = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2`,
      [obtainedMarks, attemptId]
    );

    await client.query('COMMIT');

    logger.info('Attempt evaluated successfully', {
      attemptId,
      totalMarks,
      obtainedMarks,
      percentage,
      passed,
    });

    return {
      result,
      evaluation: {
        totalMarks,
        obtainedMarks,
        percentage,
        passed,
        passPercentage: test.pass_percentage,
      },
    };
  } catch (error) {
    await client.query('ROLLBACK');
    logger.error('Error evaluating attempt', { error: error.message });
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

  return {
    result,
    attempt,
    test,
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
  getResult,
  getTestResults,
  getCandidateResults,
  getTestStatistics,
};
