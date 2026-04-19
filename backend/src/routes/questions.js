const express = require('express');
const questionController = require('../controllers/questionController');
const { authenticateToken, adminOnly } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router({ mergeParams: true });

/**
 * POST /api/v1/tests/:testId/questions
 * Create a new question (Admin only)
 */
router.post(
  '/',
  authenticateToken,
  adminOnly,
  asyncHandler(questionController.createQuestion)
);

/**
 * GET /api/v1/tests/:testId/questions
 * Get all questions for a test
 */
router.get(
  '/',
  authenticateToken,
  asyncHandler(questionController.getTestQuestions)
);

/**
 * GET /api/v1/tests/:testId/questions/:questionId
 * Get single question
 */
router.get(
  '/:questionId',
  authenticateToken,
  asyncHandler(questionController.getQuestion)
);

/**
 * PUT /api/v1/tests/:testId/questions/:questionId
 * Update question (Admin only)
 */
router.put(
  '/:questionId',
  authenticateToken,
  adminOnly,
  asyncHandler(questionController.updateQuestion)
);

/**
 * DELETE /api/v1/tests/:testId/questions/:questionId
 * Delete question (Admin only)
 */
router.delete(
  '/:questionId',
  authenticateToken,
  adminOnly,
  asyncHandler(questionController.deleteQuestion)
);

module.exports = router;
