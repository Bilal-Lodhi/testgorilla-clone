const questionService = require('../services/questionService');
const testService = require('../services/testService');
const { HTTP_STATUS } = require('../utils/constants');

/**
 * Create a new question
 * POST /api/v1/tests/:testId/questions
 * Admin only
 */
const createQuestion = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const { type, question_text, marks, order_index, options, correct_option } = req.body;

    // Validate MCQ specific requirements
    if (type === 'mcq') {
      if (!Array.isArray(options) || options.length < 2) {
        throw new Error('MCQ questions must have at least 2 options');
      }

      if (typeof correct_option !== 'number') {
        throw new Error('correct_option must be a valid number');
      }

      if (correct_option < 0 || correct_option >= options.length) {
        throw new Error('correct_option must be a valid index within options array');
      }
    }

    // Verify test exists and belongs to this admin
    const test = await testService.getTestById(testId);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only add questions to your own tests');
    }

    const question = await questionService.createQuestion({
      test_id: testId,
      type,
      question_text,
      marks,
      order_index: order_index || 0,
      options: options || [],
      correct_option: type === 'mcq' ? correct_option : null,
    });

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message: 'Question created successfully',
      data: { question },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get all questions for a test
 * GET /api/v1/tests/:testId/questions
 * Authenticated users (admin: own test, candidate: published test only)
 */
const getTestQuestions = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 50;

    // Verify test exists
    const test = await testService.getTestById(testId);

    // Candidates can only view questions if test is published
    if (req.user.role === 'candidate' && test.status !== 'published') {
      throw new Error('Unauthorized: Cannot view questions for unpublished tests');
    }

    const result = await questionService.getTestQuestions(testId, pageNum, limitNum);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Questions retrieved successfully',
      data: result.data,
      pagination: result.pagination,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get single question
 * GET /api/v1/tests/:testId/questions/:questionId
 * Authenticated users
 */
const getQuestion = async (req, res, next) => {
  try {
    const { testId, questionId } = req.params;

    // Verify test exists
    const test = await testService.getTestById(testId);

    // Candidates can only view questions if test is published
    if (req.user.role === 'candidate' && test.status !== 'published') {
      throw new Error('Unauthorized: Cannot view questions for unpublished tests');
    }

    const question = await questionService.getQuestionById(questionId);

    // Verify question belongs to this test
    if (question.test_id !== testId) {
      throw new Error('Question does not belong to this test');
    }

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Question retrieved successfully',
      data: { question },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update question
 * PUT /api/v1/tests/:testId/questions/:questionId
 * Admin only (own test)
 */
const updateQuestion = async (req, res, next) => {
  try {
    const { testId, questionId } = req.params;
    const updateData = req.body;

    // Verify test exists and belongs to this admin
    const test = await testService.getTestById(testId);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only edit questions in your own tests');
    }

    // Verify question belongs to this test
    const question = await questionService.getQuestionById(questionId);
    if (question.test_id !== testId) {
      throw new Error('Question does not belong to this test');
    }

    const updatedQuestion = await questionService.updateQuestion(questionId, updateData);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Question updated successfully',
      data: { question: updatedQuestion },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete question
 * DELETE /api/v1/tests/:testId/questions/:questionId
 * Admin only (own test)
 */
const deleteQuestion = async (req, res, next) => {
  try {
    const { testId, questionId } = req.params;

    // Verify test exists and belongs to this admin
    const test = await testService.getTestById(testId);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only delete questions from your own tests');
    }

    // Verify question belongs to this test
    const question = await questionService.getQuestionById(questionId);
    if (question.test_id !== testId) {
      throw new Error('Question does not belong to this test');
    }

    const result = await questionService.deleteQuestion(questionId);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Question deleted successfully',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createQuestion,
  getTestQuestions,
  getQuestion,
  updateQuestion,
  deleteQuestion,
};
