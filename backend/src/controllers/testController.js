const testService = require('../services/testService');
const { HTTP_STATUS } = require('../utils/constants');

/**
 * Create a new test
 * POST /api/v1/tests
 * Admin only
 */
const createTest = async (req, res, next) => {
  try {
    const { title, description, duration_minutes, status, pass_percentage } = req.body;

    const test = await testService.createTest({
      title,
      description,
      duration_minutes,
      status,
      pass_percentage,
      created_by: req.user.id, // From JWT token
    });

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message: 'Test created successfully',
      data: { test },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all tests
 * GET /api/v1/tests
 * Admin: sees all tests they created
 * Candidate: sees only published tests
 */
const getAllTests = async (req, res, next) => {
  try {
    const { page = 1, limit = 10, status } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 10;

    let result;

    // Admins see their own tests, candidates see published tests
    if (req.user.role === 'admin') {
      result = await testService.getAdminTests(req.user.id, pageNum, limitNum);
    } else {
      result = await testService.getPublishedTests(pageNum, limitNum);
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Tests retrieved successfully',
      data: result.data,
      pagination: result.pagination,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get single test by ID
 * GET /api/v1/tests/:id
 * Protected: requires authentication
 */
const getTestById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const test = await testService.getTestById(id);

    // Candidates can only view published tests
    if (req.user.role === 'candidate' && test.status !== 'published') {
      throw new Error('Unauthorized: Cannot view unpublished tests');
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test retrieved successfully',
      data: { test },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update test
 * PUT /api/v1/tests/:id
 * Admin only
 */
const updateTest = async (req, res, next) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Check if test is created by this admin
    const test = await testService.getTestById(id);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only update your own tests');
    }

    const updatedTest = await testService.updateTest(id, updateData);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test updated successfully',
      data: { test: updatedTest },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete test
 * DELETE /api/v1/tests/:id
 * Admin only
 */
const deleteTest = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check if test is created by this admin
    const test = await testService.getTestById(id);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only delete your own tests');
    }

    const result = await testService.deleteTest(id);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test deleted successfully',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Publish test
 * PATCH /api/v1/tests/:id/publish
 * Admin only
 */
const publishTest = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check if test is created by this admin
    const test = await testService.getTestById(id);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only publish your own tests');
    }

    const updatedTest = await testService.publishTest(id);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test published successfully',
      data: { test: updatedTest },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Archive test
 * PATCH /api/v1/tests/:id/archive
 * Admin only
 */
const archiveTest = async (req, res, next) => {
  try {
    const { id } = req.params;

    // Check if test is created by this admin
    const test = await testService.getTestById(id);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only archive your own tests');
    }

    const updatedTest = await testService.archiveTest(id);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Test archived successfully',
      data: { test: updatedTest },
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createTest,
  getAllTests,
  getTestById,
  updateTest,
  deleteTest,
  publishTest,
  archiveTest,
};
