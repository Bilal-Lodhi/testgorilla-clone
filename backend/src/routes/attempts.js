const express = require('express');
const attemptController = require('../controllers/attemptController');
const { authenticateToken, adminOnly, candidateOnly } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');
const { checkActiveAttempt, verifyAttemptOwnership, preventMultipleAttempts } = require('../middleware/attemptMiddleware');

const router = express.Router({ mergeParams: true });

/**
 * GET /api/v1/attempts/pending-evaluations
 * Get all pending coding/essay evaluations (Admin only)
 */
router.get(
  '/pending-evaluations',
  authenticateToken,
  adminOnly,
  asyncHandler(attemptController.getPendingEvaluations)
);

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
 * PATCH /api/v1/attempts/:attemptId/responses/:responseId/review
 * Review a coding or essay response (Admin only)
 */
router.patch(
  '/:attemptId/responses/:responseId/review',
  authenticateToken,
  adminOnly,
  asyncHandler(attemptController.reviewResponse)
);

/**
 * POST /api/v1/attempts/:attemptId/submit
 * Submit entire test attempt
 * Uses verifyAttemptOwnership instead of checkActiveAttempt to allow idempotent retries
 * Status checks and idempotency logic handled in service layer
 */
router.post(
  '/:attemptId/submit',
  authenticateToken,
  candidateOnly,
  verifyAttemptOwnership,
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
