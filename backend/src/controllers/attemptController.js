const attemptService = require('../services/attemptService');
const testService = require('../services/testService');
const { HTTP_STATUS } = require('../utils/constants');
const { ApiError } = require('../middleware/errorHandler');

/**
 * Start a test attempt (idempotent – resumes if active)
 * POST /api/v1/tests/:testId/attempts
 * Candidate only
 */
const startAttempt = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const userId = req.user.id;

    if (req.user.role !== 'candidate') {
      throw new ApiError(HTTP_STATUS.FORBIDDEN, 'Only candidates can take tests');
    }

    const test = await testService.getTestById(testId);
    if (test.status !== 'published') {
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'Test is not published. Cannot start attempt.');
    }

    await testService.verifyAccessCode(testId, req.body.access_code);

    const result = await attemptService.startAttempt(testId, userId);

    const message = result.resumed
      ? 'Resumed existing test attempt'
      : result.expired
        ? 'Previous attempt has expired'
        : 'Test attempt started successfully';

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get active attempt for current user (resume endpoint)
 * GET /api/v1/attempts/active
 * Candidate only
 *
 * Returns null data.attempt if no active attempt exists.
 * If active attempt is expired, auto-submits and returns expired=true.
 */
const getActiveAttempt = async (req, res, next) => {
  try {
    const userId = req.user.id;

    const result = await attemptService.getActiveAttempt(userId);

    if (!result) {
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        message: 'No active attempt found',
        data: { attempt: null },
      });
    }

    if (result.expired) {
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        message: 'Previous attempt has expired',
        data: { attempt: result.attempt, expired: true },
      });
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Active attempt found',
      data: {
        attempt: result.attempt,
        questions: result.questions,
        responses: result.responses,
      },
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

    const data = await attemptService.getAttemptWithResponses(attemptId);

    if (req.user.role === 'candidate' && data.attempt.user_id !== req.user.id) {
      throw new ApiError(HTTP_STATUS.FORBIDDEN, 'Unauthorized: You can only view your own attempts');
    }

    // If expired, auto-submit happened — return completed state
    if (data.expired) {
      return res.status(HTTP_STATUS.OK).json({
        success: true,
        message: 'Attempt has expired',
        data: { attempt: data.attempt, expired: true },
      });
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Attempt retrieved successfully',
      data: {
        attempt: data.attempt,
        responses: data.responses,
        start_time: data.attempt.start_time,
        duration: data.attempt.duration_minutes,
        current_question_index: data.attempt.current_question_index,
      },
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
    const {
      questionId,
      selected_option,
      selectedOptionId,
      selected_option_id,
      codeAnswer,
      writtenAnswer,
      answer,
    } = req.body;

    if (!questionId) {
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'questionId is required');
    }

    const attempt = await attemptService.getAttempt(attemptId);
    if (attempt.user_id !== req.user.id) {
      throw new ApiError(HTTP_STATUS.FORBIDDEN, 'Unauthorized: You can only submit answers to your own attempts');
    }

    const response = await attemptService.submitResponse(
      attemptId,
      questionId,
      selected_option ?? selectedOptionId ?? selected_option_id ?? null,
      codeAnswer ?? writtenAnswer ?? answer ?? null
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
 * Review a coding or essay response
 * PATCH /api/v1/attempts/:attemptId/responses/:responseId/review
 * Admin only
 */
const reviewResponse = async (req, res, next) => {
  try {
    if (req.user.role !== 'admin') {
      throw new ApiError(HTTP_STATUS.FORBIDDEN, 'Only admins can review responses');
    }

    const { attemptId, responseId } = req.params;
    const { marksObtained, reviewNotes } = req.body;

    if (marksObtained === undefined || marksObtained === null) {
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'marksObtained is required');
    }

    const result = await attemptService.reviewResponse(
      attemptId, responseId, marksObtained, req.user.id, reviewNotes || null
    );

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: result.refreshedResult
        ? 'Response reviewed and result refreshed successfully'
        : 'Response reviewed successfully',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Submit entire test attempt
 * POST /api/v1/attempts/:attemptId/submit
 * Candidate (own attempt)
 * Idempotent: Multiple submissions return same result
 */
const submitAttempt = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    const result = await attemptService.submitAttempt(attemptId);

    const message = result.isRetry
      ? 'Test already submitted. Returning previous result.'
      : 'Test submitted and evaluated successfully';

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message,
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

    const test = await testService.getTestById(testId);

    if (req.user.role !== 'admin' && test.created_by !== req.user.id) {
      throw new ApiError(HTTP_STATUS.FORBIDDEN, 'Unauthorized: You can only view attempts for your own tests');
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

/**
 * Get all pending coding/essay evaluations
 * GET /api/v1/attempts/pending-evaluations
 * Admin only
 */
const getPendingEvaluations = async (req, res, next) => {
  try {
    if (req.user.role !== 'admin') {
      throw new ApiError(HTTP_STATUS.FORBIDDEN, 'Only admins can access pending evaluations');
    }

    const data = await attemptService.getPendingEvaluations();

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Pending evaluations retrieved successfully',
      data,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  startAttempt,
  getActiveAttempt,
  getAttempt,
  submitResponse,
  reviewResponse,
  submitAttempt,
  getCandidateAttempts,
  getTestAttempts,
  getPendingEvaluations,
};