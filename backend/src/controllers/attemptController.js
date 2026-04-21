const attemptService = require('../services/attemptService');
const testService = require('../services/testService');
const { HTTP_STATUS } = require('../utils/constants');

/**
 * Start a test attempt
 * POST /api/v1/tests/:testId/attempts
 * Candidate only
 */
const startAttempt = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const userId = req.user.id;

    if (req.user.role !== 'candidate') {
      throw new Error('Only candidates can take tests');
    }

    // Verify test exists and is published
    const test = await testService.getTestById(testId);

    if (test.status !== 'published') {
      throw new Error('Test is not published. Cannot start attempt.');
    }

    const result = await attemptService.startAttempt(testId, userId);

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message: 'Test attempt started successfully',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get attempt details
 * GET /api/v1/attempts/:attemptId
 * Candidate (own attempt) or Admin
 */
const getAttempt = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    const attempt = await attemptService.getAttempt(attemptId);

    // Verify user owns this attempt (candidate) or is admin
    if (req.user.role === 'candidate' && attempt.user_id !== req.user.id) {
      throw new Error('Unauthorized: You can only view your own attempts');
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Attempt retrieved successfully',
      data: { attempt },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Submit answer to a question
 * POST /api/v1/attempts/:attemptId/responses
 * Candidate (own attempt)
 */
const submitResponse = async (req, res, next) => {
  try {
    const { attemptId } = req.params;
    const { questionId, selected_option, codeAnswer } = req.body;

    // Validate input
    if (!questionId) {
      throw new Error('questionId is required');
    }

    // Verify user owns this attempt
    const attempt = await attemptService.getAttempt(attemptId);
    if (attempt.user_id !== req.user.id) {
      throw new Error('Unauthorized: You can only submit answers to your own attempts');
    }

    const response = await attemptService.submitResponse(
      attemptId,
      questionId,
      selected_option !== undefined ? selected_option : null,
      codeAnswer || null
    );

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message: 'Response submitted successfully',
      data: { response },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Submit entire test attempt
 * POST /api/v1/attempts/:attemptId/submit
 * Candidate (own attempt)
 */
const submitAttempt = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    // Verify user owns this attempt
    const attempt = await attemptService.getAttempt(attemptId);
    if (attempt.user_id !== req.user.id) {
      throw new Error('Unauthorized: You can only submit your own attempts');
    }

    const result = await attemptService.submitAttempt(attemptId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test submitted successfully',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all attempts by a candidate
 * GET /api/v1/candidates/attempts
 * Candidate (own) or Admin
 */
const getCandidateAttempts = async (req, res, next) => {
  try {
    let userId = req.user.id;

    // Admin can view other users' attempts if userId provided in query
    if (req.user.role === 'admin' && req.query.userId) {
      userId = req.query.userId;
    }

    const attempts = await attemptService.getUserAttempts(userId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Attempts retrieved successfully',
      data: { attempts },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all attempts for a test
 * GET /api/v1/tests/:id/attempts
 * Admin (all tests) or test creator (own tests)
 */
const getTestAttempts = async (req, res, next) => {
  try {
    const testId = req.params.testId || req.params.id;

    // Verify test exists
    const test = await testService.getTestById(testId);
    
    // Allow admins to view all test attempts, or enforce ownership for non-admins
    if (req.user.role !== 'admin' && test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only view attempts for your own tests');
    }

    const attempts = await attemptService.getTestAttempts(testId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test attempts retrieved successfully',
      data: { attempts },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  startAttempt,
  getAttempt,
  submitResponse,
  submitAttempt,
  getCandidateAttempts,
  getTestAttempts,
};
