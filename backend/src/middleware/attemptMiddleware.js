const db = require('../config/db');
const { ApiError } = require('./errorHandler');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Middleware to verify ownership of attempt (auth only, no status checks)
 * Attach attempt info to req.attempt
 * Used by submitAttempt to allow idempotent retries
 */
const verifyAttemptOwnership = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    if (!attemptId) {
      return next();
    }

    // Get attempt details
    const result = await db.query(
      `SELECT id, test_id, user_id, status FROM test_attempts WHERE id = $1`,
      [attemptId]
    );

    if (result.rows.length === 0) {
      return next(new ApiError(
        HTTP_STATUS.NOT_FOUND,
        'Attempt not found'
      ));
    }

    const attempt = result.rows[0];

    // Verify ownership: user must own this attempt
    if (attempt.user_id !== req.user.id) {
      return next(new ApiError(
        HTTP_STATUS.FORBIDDEN,
        'Unauthorized: You can only access your own attempts'
      ));
    }

    // Attach to request
    req.attempt = attempt;

    next();
  } catch (error) {
    logger.error('Error in verifyAttemptOwnership middleware', { error: error.message });
    next(error);
  }
};

/**
 * Middleware to check active attempt and enforce duration limits
 * Attach attempt info to req.attempt if exists
 * Used by getAttempt and submitResponse routes
 * NOT used by submitAttempt to allow idempotent retries
 */
const checkActiveAttempt = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    if (!attemptId) {
      return next();
    }

    // Get attempt details
    const result = await db.query(
      `SELECT a.id, a.test_id, a.user_id, a.start_time, a.status, t.duration_minutes
       FROM test_attempts a
       JOIN tests t ON a.test_id = t.id
       WHERE a.id = $1`,
      [attemptId]
    );

    if (result.rows.length === 0) {
      return next();
    }

    const attempt = result.rows[0];

    // Check if attempt is still in progress
    if (attempt.status !== 'in_progress') {
      return next(new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'This test attempt is no longer in progress'
      ));
    }

    // Check if time limit exceeded
    const startTime = new Date(attempt.start_time);
    const currentTime = new Date();
    const elapsedMinutes = (currentTime - startTime) / (1000 * 60);
    const durationMinutes = attempt.duration_minutes;

    if (elapsedMinutes > durationMinutes) {
      return next(new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        `Test duration exceeded. Time limit: ${durationMinutes} minutes`
      ));
    }

    // Attach to request
    req.attempt = {
      ...attempt,
      timeRemaining: Math.ceil(durationMinutes - elapsedMinutes),
      elapsedTime: Math.floor(elapsedMinutes),
    };

    next();
  } catch (error) {
    logger.error('Error in checkActiveAttempt middleware', { error: error.message });
    next(error);
  }
};

/**
 * Middleware to check if user has only one active attempt per test
 */
const preventMultipleAttempts = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const userId = req.user.id;

    if (!testId || !userId) {
      return next();
    }

    const result = await db.query(
      `SELECT id FROM test_attempts 
       WHERE test_id = $1 AND user_id = $2 AND status = 'in_progress'`,
      [testId, userId]
    );

    if (result.rows.length > 0) {
      return next(new ApiError(
        HTTP_STATUS.CONFLICT,
        'You already have an active attempt for this test'
      ));
    }

    next();
  } catch (error) {
    logger.error('Error in preventMultipleAttempts middleware', { error: error.message });
    next(error);
  }
};

module.exports = {
  verifyAttemptOwnership,
  checkActiveAttempt,
  preventMultipleAttempts,
};
