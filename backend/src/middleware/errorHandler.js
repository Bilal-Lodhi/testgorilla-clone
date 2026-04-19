const logger = require('../utils/logger');
const { HTTP_STATUS } = require('../utils/constants');

/**
 * Custom API Error class
 */
class ApiError extends Error {
  constructor(statusCode, message, details = null) {
    super(message);
    this.statusCode = statusCode;
    this.details = details;
  }
}

/**
 * Global error handling middleware
 * Must be the last middleware in the Express app
 */
const errorHandler = (err, req, res, next) => {
  const statusCode = err.statusCode || HTTP_STATUS.INTERNAL_SERVER_ERROR;
  const message = err.message || 'Internal Server Error';

  logger.error('Request error', {
    method: req.method,
    path: req.path,
    statusCode,
    message,
    details: err.details,
  });

  // Don't expose internal error details in production
  const response = {
    success: false,
    error: {
      message,
      ...(process.env.NODE_ENV !== 'production' && { details: err.details }),
      ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
    },
  };

  res.status(statusCode).json(response);
};

/**
 * Not found middleware (404)
 */
const notFound = (req, res, next) => {
  const error = new ApiError(
    HTTP_STATUS.NOT_FOUND,
    `Route not found: ${req.method} ${req.path}`
  );
  next(error);
};

/**
 * Async error wrapper
 * Wraps async route handlers to catch errors
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

module.exports = {
  ApiError,
  errorHandler,
  notFound,
  asyncHandler,
};
