const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS, QUESTION_TYPES } = require('../utils/constants');
const logger = require('../utils/logger');
const evaluationService = require('./evaluationService');

// ═══════════════════════════════════════════════════════════
// BACKEND IS SOURCE OF TRUTH FOR:
//   - attempt state (in_progress / submitted / expired)
//   - current_question_index (resume position)
//   - start_time + duration = endTime (timing)
//
// Expiry enforcement:
//   On EVERY attempt-related request, check now vs endTime.
//   If expired → auto-submit → return completed state.
// ═══════════════════════════════════════════════════════════

// ──────────────────────────────────────────────
// EXPIRY ENFORCEMENT
// ──────────────────────────────────────────────

/**
 * Check if an in-progress attempt has expired.
 * If expired, auto-submit (evaluate) and return updated state.
 *
 * @param {Object} client - DB client (if inside a transaction)
 * @param {Object} attempt - Attempt row with t.duration_minutes
 * @returns {{ expired: boolean, attempt: Object }}
 */
const enforceExpiry = async (client, attempt) => {
  if (attempt.status !== 'in_progress') {
    return { expired: false, attempt };
  }

  const startTime = new Date(attempt.start_time);
  const now = new Date();
  const durationMinutes = attempt.duration_minutes || 60;
  const endTime = new Date(startTime.getTime() + durationMinutes * 60 * 1000);

  if (now < endTime) {
    // Not expired: attach computed timing fields
    const remainingMs = endTime.getTime() - now.getTime();
    return {
      expired: false,
      attempt: {
        ...attempt,
        remainingSeconds: Math.max(0, Math.floor(remainingMs / 1000)),
        endTime: endTime.toISOString(),
        serverNow: now.toISOString(),
      },
    };
  }

  // ── EXPIRED → auto-submit ──
  logger.warn('Attempt expired – auto-submitting', {
    attemptId: attempt.id,
    startTime: attempt.start_time,
    durationMinutes,
  });

  const pool = client || db;
  const hasExternalTx = !!client;

  if (!hasExternalTx) {
    const ac = await db.getClient();
    try {
      await ac.query('BEGIN');

      await ac.query(
        `UPDATE test_attempts
         SET status = 'submitted', end_time = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
         WHERE id = $1 AND status = 'in_progress'`,
        [attempt.id]
      );

      const metrics = await evaluationService.calculateAttemptMetrics(ac, attempt.id);
      await ac.query(
        `INSERT INTO results (attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT DO NOTHING`,
        [attempt.id, attempt.test_id, attempt.user_id, metrics.totalMarks, metrics.obtainedMarks, metrics.percentage, metrics.passed]
      );

      await ac.query('COMMIT');

      attempt.status = 'submitted';
      attempt.end_time = new Date().toISOString();
      attempt.remainingSeconds = 0;
      attempt.serverNow = new Date().toISOString();
      return { expired: true, attempt: { ...attempt, expired: true } };
    } catch (err) {
      await ac.query('ROLLBACK');
      logger.error('Auto-submit on expiry failed', { error: err.message, attemptId: attempt.id });
      throw err;
    } finally {
      ac.release();
    }
  }

  // Inside existing transaction – just update status, caller will commit
  await pool.query(
    `UPDATE test_attempts
     SET status = 'submitted', end_time = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
     WHERE id = $1 AND status = 'in_progress'`,
    [attempt.id]
  );
  attempt.status = 'submitted';
  attempt.end_time = new Date().toISOString();
  attempt.remainingSeconds = 0;
  attempt.serverNow = new Date().toISOString();
  return { expired: true, attempt: { ...attempt, expired: true } };
};

// ──────────────────────────────────────────────
// FETCH ATTEMPT WITH TEST DURATION
// ──────────────────────────────────────────────

const fetchAttemptWithDuration = async (attemptId, clientParam = null) => {
  const pool = clientParam || db;
  const result = await pool.query(
    `SELECT a.id, a.test_id, a.user_id, a.start_time, a.end_time, a.status, a.score,
            a.current_question_index, a.created_at, a.updated_at,
            t.duration_minutes, t.title AS test_title
     FROM test_attempts a
     JOIN tests t ON a.test_id = t.id
     WHERE a.id = $1`,
    [attemptId]
  );
  if (result.rows.length === 0) {
    throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found');
  }
  return result.rows[0];
};

// ──────────────────────────────────────────────
// START ATTEMPT (idempotent – resume if active)
// ──────────────────────────────────────────────

const startAttempt = async (testId, userId) => {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const existing = await client.query(
      `SELECT a.id, a.test_id, a.user_id, a.start_time, a.end_time, a.status, a.score,
              a.current_question_index, a.created_at, a.updated_at,
              t.duration_minutes
       FROM test_attempts a
       JOIN tests t ON a.test_id = t.id
       WHERE a.test_id = $1 AND a.user_id = $2 AND a.status = 'in_progress'`,
      [testId, userId]
    );

    let attempt;

    if (existing.rows.length > 0) {
      attempt = existing.rows[0];
      const { expired, attempt: checked } = await enforceExpiry(client, attempt);

      if (expired) {
        await client.query('COMMIT');
        return { attempt: checked, questions: [], responses: [], resumed: false, expired: true };
      }

      attempt = checked;
    } else {
      const newAttempt = await client.query(
        `INSERT INTO test_attempts (test_id, user_id, start_time, status, current_question_index)
         VALUES ($1, $2, CURRENT_TIMESTAMP, 'in_progress', 0)
         RETURNING id, test_id, user_id, start_time, end_time, status, score, current_question_index, created_at, updated_at`,
        [testId, userId]
      );
      attempt = newAttempt.rows[0];
      attempt.duration_minutes = (await db.query('SELECT duration_minutes FROM tests WHERE id = $1', [testId])).rows[0].duration_minutes;
      const { expired, attempt: checked } = await enforceExpiry(client, attempt);
      attempt = checked;
    }

    // Fetch questions
    const questionsResult = await client.query(
      `SELECT id, test_id, type, question_text, marks, order_index
       FROM questions WHERE test_id = $1 ORDER BY order_index ASC`,
      [testId]
    );
    const questions = questionsResult.rows;
    for (let q of questions) {
      if (q.type === 'mcq') {
        const opts = await client.query(
          `SELECT id, question_id, option_text, order_index FROM mcq_options WHERE question_id = $1 ORDER BY order_index`,
          [q.id]
        );
        q.options = opts.rows;
      } else {
        q.options = [];
      }
    }

    // Fetch previous responses for state restoration
    const responsesResult = await client.query(
      `SELECT id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status
       FROM question_responses WHERE attempt_id = $1`,
      [attempt.id]
    );

    await client.query('COMMIT');

    const isResume = existing.rows.length > 0;
    logger.info(isResume ? 'Resuming active attempt' : 'Test attempt started', {
      attemptId: attempt.id, testId, userId, questionIndex: attempt.current_question_index,
    });

    return {
      attempt,
      questions,
      responses: responsesResult.rows,
      resumed: isResume,
    };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    logger.error('Error starting/resuming attempt', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

// ──────────────────────────────────────────────
// GET ACTIVE ATTEMPT FOR USER
// ──────────────────────────────────────────────

const getActiveAttempt = async (userId) => {
  const result = await db.query(
    `SELECT a.id, a.test_id, a.user_id, a.start_time, a.end_time, a.status, a.score,
            a.current_question_index, a.created_at, a.updated_at,
            t.duration_minutes, t.title AS test_title
     FROM test_attempts a
     JOIN tests t ON a.test_id = t.id
     WHERE a.user_id = $1 AND a.status = 'in_progress'
     ORDER BY a.start_time DESC
     LIMIT 1`,
    [userId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  const attempt = result.rows[0];
  const { expired, attempt: checked } = await enforceExpiry(null, attempt);

  if (expired) {
    return { attempt: checked, expired: true };
  }

  // Fetch responses for state restoration
  const responsesResult = await db.query(
    `SELECT id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status
     FROM question_responses WHERE attempt_id = $1`,
    [attempt.id]
  );

  // Fetch questions
  const questionsResult = await db.query(
    `SELECT id, test_id, type, question_text, marks, order_index
     FROM questions WHERE test_id = $1 ORDER BY order_index ASC`,
    [attempt.test_id]
  );
  const questions = questionsResult.rows;
  for (let q of questions) {
    if (q.type === 'mcq') {
      const opts = await db.query(
        `SELECT id, question_id, option_text, order_index FROM mcq_options WHERE question_id = $1 ORDER BY order_index`,
        [q.id]
      );
      q.options = opts.rows;
    } else {
      q.options = [];
    }
  }

  return {
    attempt: checked,
    questions,
    responses: responsesResult.rows,
    expired: false,
  };
};

// ──────────────────────────────────────────────
// GET ATTEMPT BY ID (with expiry check)
// ──────────────────────────────────────────────

const getAttempt = async (attemptId) => {
  const attempt = await fetchAttemptWithDuration(attemptId);
  const { attempt: checked } = await enforceExpiry(null, attempt);

  // Fetch responses
  const responsesResult = await db.query(
    `SELECT id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status
     FROM question_responses WHERE attempt_id = $1 ORDER BY created_at ASC`,
    [attemptId]
  );

  checked.responses = responsesResult.rows;
  return checked;
};

// ──────────────────────────────────────────────
// GET ATTEMPT WITH RESPONSES (for resume/GET endpoint)
// Returns { attempt, responses, expired } with start_time, duration,
// and current_question_index for frontend resume.
// ──────────────────────────────────────────────

const getAttemptWithResponses = async (attemptId) => {
  const attempt = await fetchAttemptWithDuration(attemptId);
  const { expired, attempt: checked } = await enforceExpiry(null, attempt);

  if (expired) {
    return { attempt: checked, responses: [], expired: true };
  }

  // Fetch responses for state restoration
  const responsesResult = await db.query(
    `SELECT id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status
     FROM question_responses WHERE attempt_id = $1 ORDER BY created_at ASC`,
    [attemptId]
  );

  return {
    attempt: checked,
    responses: responsesResult.rows,
    expired: false,
  };
};

// ──────────────────────────────────────────────
// SUBMIT RESPONSE (with expiry check & question index update)
// ──────────────────────────────────────────────

const submitResponse = async (attemptId, questionId, selectedOption = null, codeAnswer = null) => {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const attempt = await fetchAttemptWithDuration(attemptId, client);
    const { expired, attempt: checked } = await enforceExpiry(client, attempt);

    if (expired) {
      await client.query('COMMIT');
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'This test attempt has expired');
    }

    if (checked.status !== 'in_progress') {
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'Cannot submit answers to a completed attempt');
    }

    const questionResult = await client.query(
      `SELECT id, test_id, type, marks, order_index FROM questions WHERE id = $1`,
      [questionId]
    );
    if (questionResult.rows.length === 0) {
      throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Question not found');
    }
    const question = questionResult.rows[0];

    if (question.test_id !== checked.test_id) {
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'Question does not belong to this test');
    }

    let isCorrect = null;
    let marksObtained = 0;
    let selectedOptionId = null;
    let gradingStatus = 'auto_graded';

    if (question.type === 'mcq' && selectedOption !== null && selectedOption !== undefined) {
      const optionsResult = await client.query(
        `SELECT id, is_correct, order_index FROM mcq_options WHERE question_id = $1 ORDER BY order_index ASC`,
        [questionId]
      );
      const options = optionsResult.rows;

      const isNumericString = typeof selectedOption === 'string' && /^\d+$/.test(selectedOption);
      const selectedOptionIndex = typeof selectedOption === 'number'
        ? selectedOption
        : isNumericString
          ? Number.parseInt(selectedOption, 10)
          : null;

      const selectedOptionRecord = Number.isInteger(selectedOptionIndex)
        ? options[selectedOptionIndex]
        : options.find((o) => o.id === selectedOption);

      if (!selectedOptionRecord) {
        throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'Invalid selected option');
      }

      selectedOptionId = selectedOptionRecord.id;
      isCorrect = selectedOptionRecord.is_correct;
      marksObtained = isCorrect ? question.marks : 0;
    }

    if (question.type === QUESTION_TYPES.CODING || question.type === QUESTION_TYPES.ESSAY) {
      gradingStatus = 'pending_review';
    }

    // Upsert response
    const existingResponse = await client.query(
      `SELECT id FROM question_responses WHERE attempt_id = $1 AND question_id = $2`,
      [attemptId, questionId]
    );

    let response;
    if (existingResponse.rows.length > 0) {
      const updateResult = await client.query(
        `UPDATE question_responses
         SET selected_option_id = $1, code_answer = $2, is_correct = $3, marks_obtained = $4,
             grading_status = $5, updated_at = CURRENT_TIMESTAMP
         WHERE attempt_id = $6 AND question_id = $7
         RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status`,
        [selectedOptionId || null, codeAnswer || null, isCorrect, marksObtained, gradingStatus, attemptId, questionId]
      );
      response = updateResult.rows[0];
    } else {
      const insertResult = await client.query(
        `INSERT INTO question_responses (attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status`,
        [attemptId, questionId, selectedOptionId || null, codeAnswer || null, isCorrect, marksObtained, gradingStatus]
      );
      response = insertResult.rows[0];
    }

    // Update current_question_index to the answered question's index
    await client.query(
      `UPDATE test_attempts SET current_question_index = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
      [question.order_index, attemptId]
    );

    await client.query('COMMIT');
    logger.info('Response submitted', { attemptId, questionId, isCorrect });
    return response;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    logger.error('Error submitting response', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

// ──────────────────────────────────────────────
// SUBMIT ATTEMPT (idempotent)
// ──────────────────────────────────────────────

const submitAttempt = async (attemptId) => {
  const evaluationResult = await evaluationService.evaluateAttempt(attemptId);
  const attemptResult = await db.query(
    `SELECT id, test_id, user_id, start_time, end_time, status, score, current_question_index, created_at, updated_at
     FROM test_attempts WHERE id = $1`,
    [attemptId]
  );
  const attempt = attemptResult.rows[0];

  logger.info(evaluationResult.isRetry ? 'Test resubmitted (idempotent)' : 'Test submitted', {
    attemptId, obtained: evaluationResult.evaluation.obtainedMarks,
    total: evaluationResult.evaluation.totalMarks,
    percentage: evaluationResult.evaluation.percentage,
    passed: evaluationResult.evaluation.passed,
  });

  return {
    attempt,
    result: evaluationResult.evaluation,
    resultRecord: evaluationResult.result,
    isRetry: evaluationResult.isRetry,
  };
};

// ──────────────────────────────────────────────
// REVIEW RESPONSE (unchanged logic, included for completeness)
// ──────────────────────────────────────────────

const reviewResponse = async (attemptId, responseId, marksObtained, reviewerId, reviewNotes = null) => {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    const attemptResult = await client.query(
      `SELECT id, test_id, user_id, status FROM test_attempts WHERE id = $1`,
      [attemptId]
    );
    if (attemptResult.rows.length === 0) {
      throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Attempt not found');
    }

    const responseResult = await client.query(
      `SELECT qr.id, qr.question_id, qr.marks_obtained, qr.grading_status, q.type, q.marks
       FROM question_responses qr
       JOIN questions q ON q.id = qr.question_id
       WHERE qr.id = $1 AND qr.attempt_id = $2`,
      [responseId, attemptId]
    );
    if (responseResult.rows.length === 0) {
      throw new ApiError(HTTP_STATUS.NOT_FOUND, 'Response not found');
    }
    const response = responseResult.rows[0];

    if (response.type === QUESTION_TYPES.MCQ) {
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'MCQ responses are auto-graded and cannot be manually reviewed');
    }

    const finalMarks = Number(marksObtained);
    if (!Number.isFinite(finalMarks) || finalMarks < 0 || finalMarks > response.marks) {
      throw new ApiError(HTTP_STATUS.BAD_REQUEST, `marksObtained must be between 0 and ${response.marks}`);
    }

    const updateResult = await client.query(
      `UPDATE question_responses
       SET marks_obtained = $1, grading_status = 'reviewed', reviewed_by = $2,
           reviewed_at = CURRENT_TIMESTAMP, review_notes = $3, updated_at = CURRENT_TIMESTAMP
       WHERE id = $4 AND attempt_id = $5
       RETURNING id, attempt_id, question_id, selected_option_id, code_answer, is_correct, marks_obtained, grading_status, reviewed_by, reviewed_at, review_notes`,
      [finalMarks, reviewerId, reviewNotes, responseId, attemptId]
    );

    let refreshedResult = null;
    const existingResult = await client.query(`SELECT id FROM results WHERE attempt_id = $1`, [attemptId]);
    if (existingResult.rows.length > 0) {
      const refreshedMetrics = await evaluationService.calculateAttemptMetrics(client, attemptId);
      const resultUpdate = await client.query(
        `UPDATE results SET total_marks = $1, obtained_marks = $2, percentage = $3, passed = $4, updated_at = CURRENT_TIMESTAMP
         WHERE attempt_id = $5
         RETURNING id, attempt_id, test_id, user_id, total_marks, obtained_marks, percentage, passed`,
        [refreshedMetrics.totalMarks, refreshedMetrics.obtainedMarks, refreshedMetrics.percentage, refreshedMetrics.passed, attemptId]
      );
      await client.query(
        `UPDATE test_attempts SET score = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
        [refreshedMetrics.obtainedMarks, attemptId]
      );
      refreshedResult = { result: resultUpdate.rows[0], evaluation: refreshedMetrics };
    }

    await client.query('COMMIT');
    return { response: updateResult.rows[0], refreshedResult };
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    logger.error('Error reviewing response', { error: error.message });
    throw error;
  } finally {
    client.release();
  }
};

// ──────────────────────────────────────────────
// QUERIES (unchanged from original)
// ──────────────────────────────────────────────

const getUserAttempts = async (userId) => {
  const result = await db.query(
    `SELECT a.id, a.test_id, a.user_id, a.start_time, a.end_time, a.status, a.score,
            a.current_question_index, a.created_at, a.updated_at,
            t.title as test_title, t.duration_minutes
     FROM test_attempts a
     JOIN tests t ON a.test_id = t.id
     WHERE a.user_id = $1
     ORDER BY a.start_time DESC`,
    [userId]
  );
  return result.rows;
};

const getTestAttempts = async (testId) => {
  const result = await db.query(
    `SELECT a.id, a.test_id, a.user_id, a.start_time, a.end_time, a.status, a.score,
            a.current_question_index, a.created_at, a.updated_at,
            u.name as user_name, u.email as user_email
     FROM test_attempts a
     JOIN users u ON a.user_id = u.id
     WHERE a.test_id = $1
     ORDER BY a.start_time DESC`,
    [testId]
  );
  return result.rows;
};

const getPendingEvaluations = async () => {
  const result = await db.query(
    `SELECT qr.id AS response_id, qr.attempt_id, qr.question_id, qr.code_answer,
            qr.grading_status, qr.created_at AS response_created_at,
            q.question_text, q.marks AS question_marks, q.type AS question_type,
            a.test_id, a.user_id, a.end_time, a.status AS attempt_status,
            t.title AS test_title, u.name AS candidate_name, u.email AS candidate_email
     FROM question_responses qr
     JOIN questions q ON q.id = qr.question_id
     JOIN test_attempts a ON a.id = qr.attempt_id
     JOIN tests t ON t.id = a.test_id
     JOIN users u ON u.id = a.user_id
     WHERE qr.grading_status = 'pending_review'
       AND q.type IN ('coding', 'essay')
       AND a.status = 'submitted'
     ORDER BY a.end_time DESC NULLS LAST, qr.created_at ASC`
  );

  const grouped = new Map();
  result.rows.forEach((row) => {
    if (!grouped.has(row.attempt_id)) {
      grouped.set(row.attempt_id, {
        attemptId: row.attempt_id,
        testId: row.test_id,
        testTitle: row.test_title,
        candidateId: row.user_id,
        candidateName: row.candidate_name,
        candidateEmail: row.candidate_email,
        submittedAt: row.end_time,
        pendingCount: 0,
        pendingResponses: [],
      });
    }
    const attempt = grouped.get(row.attempt_id);
    attempt.pendingCount += 1;
    attempt.pendingResponses.push({
      responseId: row.response_id,
      questionId: row.question_id,
      questionType: row.question_type,
      questionText: row.question_text,
      questionMarks: row.question_marks,
      answer: row.code_answer,
      gradingStatus: row.grading_status,
      submittedAt: row.response_created_at,
    });
  });

  return {
    pendingEvaluations: Array.from(grouped.values()),
    summary: { attempts: grouped.size, responses: result.rows.length },
  };
};

module.exports = {
  startAttempt,
  getAttempt,
  getAttemptWithResponses,
  getActiveAttempt,
  submitResponse,
  reviewResponse,
  submitAttempt,
  getUserAttempts,
  getTestAttempts,
  getPendingEvaluations,
  enforceExpiry,
};
