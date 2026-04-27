## Question Management Module - Complete Code Reference

All files with full working code for copy-paste.

---

## 1️⃣ migrations/003_create_questions.sql

Database tables for questions and MCQ options.

```sql
-- Create questions table
CREATE TABLE IF NOT EXISTS questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL CHECK (type IN ('mcq', 'coding')),
  question_text TEXT NOT NULL,
  marks INT NOT NULL DEFAULT 1 CHECK (marks > 0),
  order_index INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(test_id, order_index)
);

-- Create mcq_options table (for MCQ question options)
CREATE TABLE IF NOT EXISTS mcq_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
  option_text TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL DEFAULT false,
  order_index INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(question_id, order_index)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_questions_test_id ON questions(test_id);
CREATE INDEX IF NOT EXISTS idx_questions_type ON questions(type);
CREATE INDEX IF NOT EXISTS idx_mcq_options_question_id ON mcq_options(question_id);

-- Create trigger to update questions updated_at
CREATE OR REPLACE FUNCTION update_questions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_questions_updated_at ON questions;
CREATE TRIGGER trigger_questions_updated_at
  BEFORE UPDATE ON questions
  FOR EACH ROW
  EXECUTE FUNCTION update_questions_updated_at();
```

---

## 2️⃣ src/services/questionService.js

Business logic for all question operations with MCQ option handling.

```javascript
const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS, QUESTION_TYPES } = require('../utils/constants');
const logger = require('../utils/logger');

const createQuestion = async ({
  test_id,
  type,
  question_text,
  marks = 1,
  order_index = 0,
  options = [],
}) => {
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

  if (type === QUESTION_TYPES.MCQ) {
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

  try {
    const client = await db.getClient();

    try {
      await client.query('BEGIN');

      const questionResult = await client.query(
        `INSERT INTO questions (test_id, type, question_text, marks, order_index, created_at)
         VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
         RETURNING id, test_id, type, question_text, marks, order_index, created_at, updated_at`,
        [test_id, type, question_text, marks, order_index]
      );

      const question = questionResult.rows[0];
      let questionWithOptions = { ...question, options: [] };

      if (type === QUESTION_TYPES.MCQ && options.length > 0) {
        for (let i = 0; i < options.length; i++) {
          const optionResult = await client.query(
            `INSERT INTO mcq_options (question_id, option_text, is_correct, order_index, created_at)
             VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
             RETURNING id, question_id, option_text, is_correct, order_index`,
            [question.id, options[i].option_text, options[i].is_correct, i]
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

const getTestQuestions = async (testId, page = 1, limit = 50) => {
  try {
    const countResult = await db.query(
      'SELECT COUNT(*) FROM questions WHERE test_id = $1',
      [testId]
    );
    const total = parseInt(countResult.rows[0].count);

    const offset = (page - 1) * limit;
    const result = await db.query(
      `SELECT id, test_id, type, question_text, marks, order_index, created_at, updated_at
       FROM questions WHERE test_id = $1 ORDER BY order_index ASC LIMIT $2 OFFSET $3`,
      [testId, limit, offset]
    );

    const questions = result.rows;

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

      if (updateData.hasOwnProperty('options') && question.type === QUESTION_TYPES.MCQ) {
        const options = updateData.options;

        await client.query('DELETE FROM mcq_options WHERE question_id = $1', [questionId]);

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

const deleteQuestion = async (questionId) => {
  if (!questionId) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Question ID is required'
    );
  }

  const question = await getQuestionById(questionId);

  try {
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
```

---

## 3️⃣ src/controllers/questionController.js

Request handlers with auth checks and response formatting.

```javascript
const questionService = require('../services/questionService');
const testService = require('../services/testService');
const { HTTP_STATUS } = require('../utils/constants');

const createQuestion = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const { type, question_text, marks, order_index, options } = req.body;

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

const getTestQuestions = async (req, res, next) => {
  try {
    const { testId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const pageNum = parseInt(page) || 1;
    const limitNum = parseInt(limit) || 50;

    const test = await testService.getTestById(testId);

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

const getQuestion = async (req, res, next) => {
  try {
    const { testId, questionId } = req.params;

    const test = await testService.getTestById(testId);

    if (req.user.role === 'candidate' && test.status !== 'published') {
      throw new Error('Unauthorized: Cannot view questions for unpublished tests');
    }

    const question = await questionService.getQuestionById(questionId);

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

const updateQuestion = async (req, res, next) => {
  try {
    const { testId, questionId } = req.params;
    const updateData = req.body;

    const test = await testService.getTestById(testId);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only edit questions in your own tests');
    }

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

const deleteQuestion = async (req, res, next) => {
  try {
    const { testId, questionId } = req.params;

    const test = await testService.getTestById(testId);
    if (test.created_by !== req.user.id) {
      throw new Error('Unauthorized: You can only delete questions from your own tests');
    }

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
```

---

## 4️⃣ src/routes/questions.js

API route definitions for all question endpoints.

```javascript
const express = require('express');
const questionController = require('../controllers/questionController');
const { authenticateToken, adminOnly } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router({ mergeParams: true });

router.post(
  '/',
  authenticateToken,
  adminOnly,
  asyncHandler(questionController.createQuestion)
);

router.get(
  '/',
  authenticateToken,
  asyncHandler(questionController.getTestQuestions)
);

router.get(
  '/:questionId',
  authenticateToken,
  asyncHandler(questionController.getQuestion)
);

router.put(
  '/:questionId',
  authenticateToken,
  adminOnly,
  asyncHandler(questionController.updateQuestion)
);

router.delete(
  '/:questionId',
  authenticateToken,
  adminOnly,
  asyncHandler(questionController.deleteQuestion)
);

module.exports = router;
```

---

## 5️⃣ src/routes/tests.js (Updated)

Integration of questions routes as nested routes.

Key addition:
```javascript
const questionRoutes = require('./questions');

// Mount questions router for nested routes
router.use('/:testId/questions', questionRoutes);
```

---

## 📋 Setup Commands

```bash
# 1. Run migration
psql -U postgres -h localhost -p 5433 -d testgorilla -f migrations/003_create_questions.sql

# 2. Restart server
npm run dev

# 3. Test with Insomnia (see QUESTIONS_MANAGEMENT.md for examples)
```

---

## 📡 API Endpoints Summary

| Method | Endpoint | Auth | Role | Purpose |
|--------|----------|------|------|---------|
| POST | /tests/:testId/questions | ✅ | admin | Create question |
| GET | /tests/:testId/questions | ✅ | any | List questions |
| GET | /tests/:testId/questions/:id | ✅ | any | Get question |
| PUT | /tests/:testId/questions/:id | ✅ | admin | Update question |
| DELETE | /tests/:testId/questions/:id | ✅ | admin | Delete question |

---

## ✨ Features

✅ **MCQ questions** - With multiple options and single correct answer  
✅ **Coding questions** - Basic structure (evaluation later)  
✅ **Full CRUD** - Create, read, update, delete operations  
✅ **Role-based access** - Admin-only write, candidate read (published only)  
✅ **Test ownership** - Can only modify questions in own tests  
✅ **Transactions** - Atomic operations for complex updates  
✅ **Pagination** - List with page/limit support  
✅ **Validation** - Comprehensive input checking  
✅ **Error handling** - Detailed error messages  
✅ **Database constraints** - Integrity and ordering  

---

All code is **production-ready**! 🚀
