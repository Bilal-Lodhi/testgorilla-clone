/**
 * Application constants
 */

const HTTP_STATUS = {
  // 2xx Success
  OK: 200,
  CREATED: 201,
  ACCEPTED: 202,
  NO_CONTENT: 204,

  // 4xx Client errors
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  CONFLICT: 409,
  UNPROCESSABLE_ENTITY: 422,

  // 5xx Server errors
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
};

const USER_ROLES = {
  ADMIN: 'admin',
  RECRUITER: 'recruiter',
  CANDIDATE: 'candidate',
};

const TEST_STATUS = {
  DRAFT: 'draft',
  PUBLISHED: 'published',
  ARCHIVED: 'archived',
};

const QUESTION_TYPES = {
  MCQ: 'mcq',
  CODING: 'coding',
  ESSAY: 'essay',
};

const ATTEMPT_STATUS = {
  IN_PROGRESS: 'in_progress',
  SUBMITTED: 'submitted',
  EVALUATED: 'evaluated',
};

const CHEATING_EVENTS = {
  TAB_SWITCH: 'tab_switch',
  COPY_PASTE: 'copy_paste',
  SCREENSHOT: 'screenshot',
  WINDOW_BLUR: 'window_blur',
  MOUSE_EXIT: 'mouse_exit',
};

module.exports = {
  HTTP_STATUS,
  USER_ROLES,
  TEST_STATUS,
  QUESTION_TYPES,
  ATTEMPT_STATUS,
  CHEATING_EVENTS,
};
