const evaluationService = require('../services/evaluationService');
const testService = require('../services/testService');
const { HTTP_STATUS } = require('../utils/constants');
const { ApiError } = require('../middleware/errorHandler');

/**
 * Get result for a specific attempt
 * GET /api/v1/results/:attemptId
 * Candidate (own result) or Admin
 */
const getResult = async (req, res, next) => {
  try {
    const { attemptId } = req.params;

    const result = await evaluationService.getResult(attemptId);

    // Verify user owns this result (candidate) or is admin
    if (req.user.role === 'candidate' && result.result.user_id !== req.user.id) {
      throw new ApiError(
        HTTP_STATUS.FORBIDDEN,
        'Unauthorized: You can only view your own results'
      );
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Result retrieved successfully',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all results for a test
 * GET /api/v1/tests/:testId/results
 * Admin (test creator)
 */
const getTestResults = async (req, res, next) => {
  try {
    const testId = req.params.testId || req.params.id;

    // Verify test exists and user created it (unless admin role allows all)
    const test = await testService.getTestById(testId);
    if (req.user.role !== 'admin' && test.created_by !== req.user.id) {
      throw new ApiError(
        HTTP_STATUS.FORBIDDEN,
        'Unauthorized: You can only view results for your own tests'
      );
    }

    const results = await evaluationService.getTestResults(testId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test results retrieved successfully',
      data: { results },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get test statistics (pass rate, average score, etc.)
 * GET /api/v1/tests/:testId/results/statistics
 * Admin (test creator)
 */
const getTestStatistics = async (req, res, next) => {
  try {
    const testId = req.params.testId || req.params.id;

    // Verify test exists and user created it (unless admin role allows all)
    const test = await testService.getTestById(testId);
    if (req.user.role !== 'admin' && test.created_by !== req.user.id) {
      throw new ApiError(
        HTTP_STATUS.FORBIDDEN,
        'Unauthorized: You can only view statistics for your own tests'
      );
    }

    const statistics = await evaluationService.getTestStatistics(testId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test statistics retrieved successfully',
      data: { statistics },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all results for a candidate
 * GET /api/v1/candidates/:userId/results
 * Candidate (own) or Admin
 */
const getCandidateResults = async (req, res, next) => {
  try {
    let userId = req.user.id;

    // Admin can view other users' results if userId provided in params
    if (req.user.role === 'admin' && req.params.userId) {
      userId = req.params.userId;
    } else if (req.user.role !== 'admin' && req.params.userId && req.params.userId !== req.user.id) {
      throw new ApiError(
        HTTP_STATUS.FORBIDDEN,
        'Unauthorized: You can only view your own results'
      );
    }

    const results = await evaluationService.getCandidateResults(userId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Candidate results retrieved successfully',
      data: { results },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  getResult,
  getTestResults,
  getTestStatistics,
  getCandidateResults,
};
