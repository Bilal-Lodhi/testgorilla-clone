const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS, TEST_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Create a new test
 * @param {Object} testData - Test data
 * @param {string} testData.title - Test title
 * @param {string} testData.description - Test description
 * @param {number} testData.duration_minutes - Duration in minutes
 * @param {string} testData.created_by - Admin user ID (UUID)
 * @param {string} testData.status - Test status (draft/published/archived)
 * @returns {Promise<Object>} Created test
 */
const createTest = async ({
  title,
  description,
  duration_minutes,
  created_by,
  access_code,
  status = TEST_STATUS.DRAFT,
  pass_percentage = 60,
}) => {
  // Validate input
  if (!title || !duration_minutes || !created_by) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Title, duration_minutes, and created_by are required'
    );
  }

  if (!access_code || access_code.trim() === '') {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Access code is required'
    );
  }

  if (duration_minutes <= 0) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Duration must be greater than 0'
    );
  }

  if (!Object.values(TEST_STATUS).includes(status)) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      `Invalid status. Must be one of: ${Object.values(TEST_STATUS).join(', ')}`
    );
  }

  if (status === TEST_STATUS.PUBLISHED) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'A test must have at least 1 question before it can be published'
    );
  }

  try {
    const result = await db.query(
      `INSERT INTO tests (title, description, duration_minutes, created_by, status, pass_percentage, access_code, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)
       RETURNING id, title, description, duration_minutes, created_by, status, pass_percentage, total_questions, created_at, updated_at`,
      [title, description, duration_minutes, created_by, status, pass_percentage, access_code.trim()]
    );

    const test = result.rows[0];

    logger.info('Test created successfully', {
      testId: test.id,
      title: test.title,
      createdBy: test.created_by,
    });

    return test;
  } catch (error) {
    logger.error('Error creating test', { error: error.message });
    throw error;
  }
};

/**
 * Get test by ID
 * @param {string} testId - Test ID (UUID)
 * @returns {Promise<Object>} Test object
 */
const getTestById = async (testId) => {
  const result = await db.query(
    `SELECT
       t.id,
       t.title,
       t.description,
       t.duration_minutes,
       t.created_by,
       t.status,
       t.pass_percentage,
       t.created_at,
       t.updated_at,
       COALESCE(question_counts.total_questions, 0) AS total_questions,
       u.name as created_by_name
     FROM tests t
     LEFT JOIN users u ON t.created_by = u.id
     LEFT JOIN (
       SELECT test_id, COUNT(*)::int AS total_questions
       FROM questions
       GROUP BY test_id
     ) question_counts ON question_counts.test_id = t.id
     WHERE t.id = $1`,
    [testId]
  );

  if (result.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.NOT_FOUND,
      'Test not found'
    );
  }

  return result.rows[0];
};

/**
 * Get all tests with pagination
 * @param {Object} filters - Filter options
 * @param {string} filters.status - Filter by status (optional)
 * @param {string} filters.created_by - Filter by creator (optional)
 * @param {number} filters.page - Page number (default: 1)
 * @param {number} filters.limit - Items per page (default: 10)
 * @returns {Promise<Object>} Tests and pagination info
 */
const getAllTests = async ({
  status = null,
  created_by = null,
  page = 1,
  limit = 10,
} = {}) => {
  try {
    let query = `SELECT
      t.id,
      t.title,
      t.description,
      t.duration_minutes,
      t.created_by,
      t.status,
      t.pass_percentage,
      t.created_at,
      t.updated_at,
      COALESCE(question_counts.total_questions, 0) AS total_questions,
      u.name as created_by_name
    FROM tests t
    LEFT JOIN users u ON t.created_by = u.id
    LEFT JOIN (
      SELECT test_id, COUNT(*)::int AS total_questions
      FROM questions
      GROUP BY test_id
    ) question_counts ON question_counts.test_id = t.id
    WHERE 1=1`;
    const params = [];
    let paramCount = 1;

    if (status) {
      query += ` AND t.status = $${paramCount}`;
      params.push(status);
      paramCount++;
    }

    if (created_by) {
      query += ` AND t.created_by = $${paramCount}`;
      params.push(created_by);
      paramCount++;
    }

    // Get total count
    let countQuery = `SELECT COUNT(*) FROM tests t WHERE 1=1`;
    const countParams = [];

    if (status) {
      countQuery += ` AND t.status = $${countParams.length + 1}`;
      countParams.push(status);
    }

    if (created_by) {
      countQuery += ` AND t.created_by = $${countParams.length + 1}`;
      countParams.push(created_by);
    }

    const countResult = await db.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].count);

    // Get paginated results
    const offset = (page - 1) * limit;
    query += ` ORDER BY t.created_at DESC LIMIT $${paramCount} OFFSET $${paramCount + 1}`;
    params.push(limit, offset);

    const result = await db.query(query, params);

    return {
      data: result.rows,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    };
  } catch (error) {
    logger.error('Error fetching tests', { error: error.message });
    throw error;
  }
};

/**
 * Get tests for admin (all tests they created)
 * @param {string} adminId - Admin user ID
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @returns {Promise<Object>} Admin's tests
 */
const getAdminTests = async (adminId, page = 1, limit = 10) => {
  return await getAllTests({ created_by: adminId, page, limit });
};

/**
 * Get published tests only (for candidates)
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @returns {Promise<Object>} Published tests
 */
const getPublishedTests = async (page = 1, limit = 10) => {
  return await getAllTests({ status: TEST_STATUS.PUBLISHED, page, limit });
};

/**
 * Update test
 * @param {string} testId - Test ID
 * @param {Object} updateData - Data to update
 * @returns {Promise<Object>} Updated test
 */
const updateTest = async (testId, updateData) => {
  // Validate input
  if (!testId) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Test ID is required'
    );
  }

  // Check test exists
  await getTestById(testId);

  // Build dynamic update query
  const allowedFields = ['title', 'description', 'duration_minutes', 'status', 'pass_percentage', 'access_code'];
  const updates = [];
  const values = [];
  let paramCount = 1;

  for (const field of allowedFields) {
    if (updateData.hasOwnProperty(field)) {
      const value = updateData[field];

      // Validate specific fields
      if (field === 'duration_minutes' && value <= 0) {
        throw new ApiError(
          HTTP_STATUS.BAD_REQUEST,
          'Duration must be greater than 0'
        );
      }

      if (field === 'status' && !Object.values(TEST_STATUS).includes(value)) {
        throw new ApiError(
          HTTP_STATUS.BAD_REQUEST,
          `Invalid status. Must be one of: ${Object.values(TEST_STATUS).join(', ')}`
        );
      }

      if (field === 'status' && value === TEST_STATUS.PUBLISHED) {
        const currentTest = await getTestById(testId);
        if ((currentTest.total_questions || 0) < 1) {
          throw new ApiError(
            HTTP_STATUS.BAD_REQUEST,
            'A test must have at least 1 question before it can be published'
          );
        }
      }

      updates.push(`${field} = $${paramCount}`);
      values.push(value);
      paramCount++;
    }
  }

  if (updates.length === 0) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'No valid fields to update'
    );
  }

  values.push(testId);

  try {
    const query = `
      UPDATE tests
      SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE id = $${paramCount}
      RETURNING id, title, description, duration_minutes, created_by, status, pass_percentage, total_questions, created_at, updated_at
    `;

    const result = await db.query(query, values);
    const test = result.rows[0];

    logger.info('Test updated successfully', {
      testId: test.id,
      title: test.title,
    });

    return test;
  } catch (error) {
    logger.error('Error updating test', { error: error.message });
    throw error;
  }
};

/**
 * Delete test
 * @param {string} testId - Test ID
 * @returns {Promise<Object>} Deleted test info
 */
const deleteTest = async (testId) => {
  if (!testId) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Test ID is required'
    );
  }

  // Check test exists before deleting
  const test = await getTestById(testId);

  try {
    await db.query('DELETE FROM tests WHERE id = $1', [testId]);

    logger.info('Test deleted successfully', {
      testId: test.id,
      title: test.title,
    });

    return { message: 'Test deleted successfully', testId };
  } catch (error) {
    logger.error('Error deleting test', { error: error.message });
    throw error;
  }
};

/**
 * Publish test
 * @param {string} testId - Test ID
 * @returns {Promise<Object>} Updated test
 */
const publishTest = async (testId) => {
  return await updateTest(testId, { status: TEST_STATUS.PUBLISHED });
};

/**
 * Archive test
 * @param {string} testId - Test ID
 * @returns {Promise<Object>} Updated test
 */
const archiveTest = async (testId) => {
  return await updateTest(testId, { status: TEST_STATUS.ARCHIVED });
};

/**
 * Verify test access code
 * @param {string} testId - Test ID
 * @param {string} code - Access code submitted by candidate
 * @returns {Promise<boolean>} True if code matches
 */
const verifyAccessCode = async (testId, code) => {
  if (!testId || !code || code.trim() === '') {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Test ID and access code are required'
    );
  }

  const result = await db.query(
    'SELECT access_code FROM tests WHERE id = $1',
    [testId]
  );

  if (result.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.NOT_FOUND,
      'Test not found'
    );
  }

  const storedCode = result.rows[0].access_code;

  if (storedCode !== code.trim()) {
    throw new ApiError(
      HTTP_STATUS.FORBIDDEN,
      'Invalid access code'
    );
  }

  return true;
};

module.exports = {
  createTest,
  getTestById,
  getAllTests,
  getAdminTests,
  getPublishedTests,
  updateTest,
  deleteTest,
  publishTest,
  archiveTest,
  verifyAccessCode,
};
