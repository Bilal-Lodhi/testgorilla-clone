const express = require('express');
const testController = require('../controllers/testController');
const attemptController = require('../controllers/attemptController');
const { authenticateToken, adminOnly } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router();

/**
 * POST /api/v1/tests
 * Create a new test (Admin only)
 */
router.post(
  '/',
  authenticateToken,
  adminOnly,
  asyncHandler(testController.createTest)
);

/**
 * GET /api/v1/tests
 * Get all tests
 * - Admin: sees their own tests
 * - Candidate: sees published tests
 */
router.get(
  '/',
  authenticateToken,
  asyncHandler(testController.getAllTests)
);

/**
 * GET /api/v1/tests/:id
 * Get single test by ID
 */
router.get(
  '/:id',
  authenticateToken,
  asyncHandler(testController.getTestById)
);

/**
 * PUT /api/v1/tests/:id
 * Update test (Admin only, only their own tests)
 */
router.put(
  '/:id',
  authenticateToken,
  adminOnly,
  asyncHandler(testController.updateTest)
);

/**
 * DELETE /api/v1/tests/:id
 * Delete test (Admin only, only their own tests)
 */
router.delete(
  '/:id',
  authenticateToken,
  adminOnly,
  asyncHandler(testController.deleteTest)
);

/**
 * PATCH /api/v1/tests/:id/publish
 * Publish test (Admin only)
 */
router.patch(
  '/:id/publish',
  authenticateToken,
  adminOnly,
  asyncHandler(testController.publishTest)
);

/**
 * PATCH /api/v1/tests/:id/archive
 * Archive test (Admin only)
 */
router.patch(
  '/:id/archive',
  authenticateToken,
  adminOnly,
  asyncHandler(testController.archiveTest)
);

/**
 * GET /api/v1/tests/:id/attempts
 * Get all attempts for a test (Admin only - test creator)
 */
router.get(
  '/:id/attempts',
  authenticateToken,
  adminOnly,
  asyncHandler(attemptController.getTestAttempts)
);

module.exports = router;
