const express = require('express');
const attemptController = require('../controllers/attemptController');
const { authenticateToken, adminOnly, candidateOnly } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');
const { checkActiveAttempt, preventMultipleAttempts } = require('../middleware/attemptMiddleware');

const router = express.Router({ mergeParams: true });

/**
 * POST /api/v1/tests/:testId/attempts
 * Start a test attempt (Candidate only)
 * Mounted with mergeParams to inherit :testId from parent route
 */
router.post(
  '/',
  authenticateToken,
  candidateOnly,
  preventMultipleAttempts,
  asyncHandler(attemptController.startAttempt)
);

/**
 * GET /api/v1/attempts/:attemptId
 * Get attempt details
 * Works with both standalone and nested mounting
 */
router.get(
  '/:attemptId',
  authenticateToken,
  checkActiveAttempt,
  asyncHandler(attemptController.getAttempt)
);

/**
 * POST /api/v1/attempts/:attemptId/responses
 * Submit answer to a question
 */
router.post(
  '/:attemptId/responses',
  authenticateToken,
  candidateOnly,
  checkActiveAttempt,
  asyncHandler(attemptController.submitResponse)
);

/**
 * POST /api/v1/attempts/:attemptId/submit
 * Submit entire test attempt
 */
router.post(
  '/:attemptId/submit',
  authenticateToken,
  candidateOnly,
  checkActiveAttempt,
  asyncHandler(attemptController.submitAttempt)
);

/**
 * GET /api/v1/candidates/attempts
 * Get all attempts by a candidate
 * Works when mounted at /api/v1/candidates/attempts
 */
router.get(
  '/',
  authenticateToken,
  asyncHandler(attemptController.getCandidateAttempts)
);

module.exports = router;
