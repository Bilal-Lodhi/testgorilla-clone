const express = require('express');
const resultController = require('../controllers/resultController');
const { authenticateToken, adminOnly } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router({ mergeParams: true });

/**
 * GET /api/v1/results/:attemptId
 * Get result for a specific attempt
 * Candidate (own) or Admin
 */
router.get(
  '/:attemptId',
  authenticateToken,
  asyncHandler(resultController.getResult)
);

/**
 * GET /api/v1/tests/:testId/results
 * Get all results for a test
 * Admin (test creator)
 */
router.get(
  '/test/:testId',
  authenticateToken,
  asyncHandler(resultController.getTestResults)
);

/**
 * GET /api/v1/tests/:testId/results/statistics
 * Get test statistics (pass rate, average score, etc.)
 * Admin (test creator)
 */
router.get(
  '/test/:testId/statistics',
  authenticateToken,
  asyncHandler(resultController.getTestStatistics)
);

/**
 * GET /api/v1/candidates/:userId/results
 * Get all results for a candidate
 * Candidate (own) or Admin
 */
router.get(
  '/candidate/:userId',
  authenticateToken,
  asyncHandler(resultController.getCandidateResults)
);

module.exports = router;
