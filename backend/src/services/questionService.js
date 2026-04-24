const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS, QUESTION_TYPES } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Create a new question (MCQ or Coding)
 * @param {Object} questionData - Question data
 * @param {string} questionData.test_id - Test ID
 * @param {string} questionData.type - Question type (mcq | coding)
 * @param {string} questionData.question_text - Question text
 * @param {number} questionData.marks - Question marks
 * @param {number} questionData.order_index - Question order
 * @param {Array} questionData.options - MCQ options (for MCQ type only)
 * @returns {Promise<Object>} Created question with options
 */
const createQuestion = async ({
  test_id,
  type,
  question_text,
  marks = 1,
  order_index = 0,
  options = [],
  correct_option = null,
}) => {
  // Validate input
  if (!test_id || !type || !question_text) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'test_id, type, and question_text are required'
    );
  }

  if (!Object.values(QUESTION_TYPES).includes(type)) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      `Invalid type. Must be one of: ${Object.values(QUESTION_TYPES).join(', ')}`
    );
  }

  if (marks <= 0) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Marks must be greater than 0'
    );
  }

  // MCQ validation: must have at least 2 options and valid correct_option index
  if (type === QUESTION_TYPES.MCQ) {
    if (!options || options.length < 2) {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'MCQ questions must have at least 2 options'
      );
    }

    // Note: correct_option is passed separately in the request body
    // This validation happens in the controller before calling createQuestion
  }

  try {
    // Get client for transaction
    const client = await db.getClient();

    try {
      await client.query('BEGIN');

      // Create question
      const questionResult = await client.query(
        `INSERT INTO questions (test_id, type, question_text, marks, order_index, created_at)
         VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
         RETURNING id, test_id, type, question_text, marks, order_index, created_at, updated_at`,
        [test_id, type, question_text, marks, order_index]
      );

      const question = questionResult.rows[0];
      let questionWithOptions = { ...question, options: [] };

      // Insert MCQ options if MCQ type
      if (type === QUESTION_TYPES.MCQ && options.length > 0) {
        for (let i = 0; i < options.length; i++) {
          const isCorrect = i === correct_option;
          const optionValue = options[i];
          const optionText =
            typeof optionValue === 'string'
              ? optionValue
              : optionValue?.option_text || optionValue?.text || '';

          if (!optionText) {
            throw new ApiError(
              HTTP_STATUS.BAD_REQUEST,
              `Option text is required for option at index ${i}`
            );
          }

          const optionResult = await client.query(
            `INSERT INTO mcq_options (question_id, option_text, is_correct, order_index, created_at)
             VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
             RETURNING id, question_id, option_text, is_correct, order_index`,
            [question.id, optionText, isCorrect, i]
          );
          questionWithOptions.options.push(optionResult.rows[0]);
        }
      }

      await client.query('COMMIT');

      logger.info('Question created successfully', {
        questionId: question.id,
        testId: test_id,
        type,
      });

      return questionWithOptions;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('Error creating question', { error: error.message });
    throw error;
  }
};

/**
 * Get single question by ID with options
 * @param {string} questionId - Question ID
 * @returns {Promise<Object>} Question with options
 */
const getQuestionById = async (questionId) => {
  const result = await db.query(
    `SELECT id, test_id, type, question_text, marks, order_index, created_at, updated_at
     FROM questions WHERE id = $1`,
    [questionId]
  );

  if (result.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.NOT_FOUND,
      'Question not found'
    );
  }

  const question = result.rows[0];

  // Get options if MCQ
  if (question.type === QUESTION_TYPES.MCQ) {
    const optionsResult = await db.query(
      `SELECT id, question_id, option_text, is_correct, order_index
       FROM mcq_options WHERE question_id = $1 ORDER BY order_index`,
      [questionId]
    );
    question.options = optionsResult.rows;
  } else {
    question.options = [];
  }

  return question;
};

/**
 * Get all questions for a test
 * @param {string} testId - Test ID
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @returns {Promise<Object>} Questions with pagination
 */
const getTestQuestions = async (testId, page = 1, limit = 50) => {
  try {
    // Get total count
    const countResult = await db.query(
      'SELECT COUNT(*) FROM questions WHERE test_id = $1',
      [testId]
    );
    const total = parseInt(countResult.rows[0].count);

    // Get paginated questions
    const offset = (page - 1) * limit;
    const result = await db.query(
      `SELECT id, test_id, type, question_text, marks, order_index, created_at, updated_at
       FROM questions WHERE test_id = $1 ORDER BY order_index ASC LIMIT $2 OFFSET $3`,
      [testId, limit, offset]
    );

    const questions = result.rows;

    // Get options for all MCQ questions
    for (let question of questions) {
      if (question.type === QUESTION_TYPES.MCQ) {
        const optionsResult = await db.query(
          `SELECT id, question_id, option_text, is_correct, order_index
           FROM mcq_options WHERE question_id = $1 ORDER BY order_index`,
          [question.id]
        );
        question.options = optionsResult.rows;
      } else {
        question.options = [];
      }
    }

    return {
      data: questions,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    };
  } catch (error) {
    logger.error('Error fetching test questions', { error: error.message });
    throw error;
  }
};

/**
 * Update question
 * @param {string} questionId - Question ID
 * @param {Object} updateData - Data to update
 * @returns {Promise<Object>} Updated question with options
 */
const updateQuestion = async (questionId, updateData) => {
  if (!questionId) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Question ID is required'
    );
  }

  const question = await getQuestionById(questionId);

  const allowedFields = ['question_text', 'marks', 'order_index'];
  const updates = [];
  const values = [];
  let paramCount = 1;

  for (const field of allowedFields) {
    if (updateData.hasOwnProperty(field)) {
      const value = updateData[field];

      if (field === 'marks' && value <= 0) {
        throw new ApiError(
          HTTP_STATUS.BAD_REQUEST,
          'Marks must be greater than 0'
        );
      }

      updates.push(`${field} = $${paramCount}`);
      values.push(value);
      paramCount++;
    }
  }

  // Handle MCQ options update
  if (updateData.hasOwnProperty('options') && question.type === QUESTION_TYPES.MCQ) {
    const options = updateData.options;

    if (!options || options.length < 2) {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'MCQ questions must have at least 2 options'
      );
    }

    const correctCount = options.filter(opt => opt.is_correct).length;
    if (correctCount !== 1) {
      throw new ApiError(
        HTTP_STATUS.BAD_REQUEST,
        'MCQ questions must have exactly 1 correct option'
      );
    }
  }

  if (updates.length === 0 && !updateData.hasOwnProperty('options')) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'No valid fields to update'
    );
  }

  try {
    const client = await db.getClient();

    try {
      await client.query('BEGIN');

      // Update question fields
      if (updates.length > 0) {
        values.push(questionId);
        const query = `
          UPDATE questions
          SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP
          WHERE id = $${paramCount}
          RETURNING id, test_id, type, question_text, marks, order_index, created_at, updated_at
        `;
        await client.query(query, values);
      }

      // Update MCQ options if provided
      if (updateData.hasOwnProperty('options') && question.type === QUESTION_TYPES.MCQ) {
        const options = updateData.options;

        // Delete existing options
        await client.query('DELETE FROM mcq_options WHERE question_id = $1', [questionId]);

        // Insert new options
        for (let i = 0; i < options.length; i++) {
          await client.query(
            `INSERT INTO mcq_options (question_id, option_text, is_correct, order_index, created_at)
             VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)`,
            [questionId, options[i].option_text, options[i].is_correct, i]
          );
        }
      }

      await client.query('COMMIT');

      logger.info('Question updated successfully', { questionId });

      // Return updated question
      return await getQuestionById(questionId);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('Error updating question', { error: error.message });
    throw error;
  }
};

/**
 * Delete question
 * @param {string} questionId - Question ID
 * @returns {Promise<Object>} Deletion result
 */
const deleteQuestion = async (questionId) => {
  if (!questionId) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Question ID is required'
    );
  }

  const question = await getQuestionById(questionId);

  try {
    // Options will be deleted automatically due to CASCADE
    await db.query('DELETE FROM questions WHERE id = $1', [questionId]);

    logger.info('Question deleted successfully', { questionId });

    return { message: 'Question deleted successfully', questionId };
  } catch (error) {
    logger.error('Error deleting question', { error: error.message });
    throw error;
  }
};

module.exports = {
  createQuestion,
  getQuestionById,
  getTestQuestions,
  updateQuestion,
  deleteQuestion,
};
