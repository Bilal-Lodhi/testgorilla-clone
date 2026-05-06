const attemptService = require('../services/attemptService');
const { ApiError } = require('./errorHandler');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Middleware to verify ownership of attempt.
 * Also enforces expiry via attemptService.enforceExpiry().
 * Attaches attempt info to req.attempt.
 */
const verifyAttemptOwnership = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    if (!attemptId) {
      return next();
    }

    const attempt = await attemptService.getAttempt(attemptId);

    if (!attempt) {
      return next(new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found'));
    }

    // Verify ownership: user must own this attempt
    if (attempt.user_id !== req.user.id) {
      return next(new ApiError(
        HTTP_STATUS.FORBIDDEN,
        'Unauthorized: You can only access your own attempts'
      ));
    }

    // Attach to request (expiry already enforced by getAttempt)
    req.attempt = attempt;

    next();
  } catch (error) {
    logger.error('Error in verifyAttemptOwnership middleware', { error: error.message });
    next(error);
  }
};

/**
 * Middleware to check active attempt.
 * Delegates expiry enforcement to attemptService.getAttempt().
 */
const checkActiveAttempt = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    if (!attemptId) {
      return next();
    }

    const attempt = await attemptService.getAttempt(attemptId);

    if (!attempt) {
      return next(new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found'));
    }

    // After getAttempt, if status changed to 'submitted' due to expiry,
    // the service auto-handled it. Let the caller decide how to handle.
    if (attempt.status !== 'in_progress') {
      return next(new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        attempt.expired ? 'This test attempt has expired' : 'This test attempt is no longer in progress'
      ));
    }

    // Attach to request with timing info from the service
    req.attempt = attempt;

    next();
  } catch (error) {
    logger.error('Error in checkActiveAttempt middleware', { error: error.message });
    next(error);
  }
};

/**
 * Middleware to check if user already has an active attempt for this test.
 * Now permissive: returns existing attempt instead of blocking,
 * allowing idempotent startAttempt.
 */
const preventMultipleAttempts = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const userId = req.user.id;

    if (!testId || !userId) {
      return next();
    }

    // Check for existing active attempt
    const activeAttempt = await attemptService.getActiveAttempt(userId);

    if (activeAttempt && activeAttempt.attempt && activeAttempt.attempt.test_id === testId) {
      // Attach to req for controller to use
      req.existingActiveAttempt = activeAttempt;
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