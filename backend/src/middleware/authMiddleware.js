const { verifyToken, extractTokenFromHeader } = require('../utils/jwt');
const { ApiError } = require('./errorHandler');
const { HTTP_STATUS, USER_ROLES } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Verify JWT token from Authorization header
 * Attaches user data to req.user
 */
const authenticateToken = (req, res, next) => {
  try {
    const authHeader = req.get('Authorization');
    const token = extractTokenFromHeader(authHeader);

    if (!token) {
      throw new ApiError(
        HTTP_STATUS.UNAUTHORIZED,
        'No token provided. Use Authorization header with Bearer token'
      );
    }

    try {
      const decoded = verifyToken(token);
      req.user = decoded;
      next();
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        throw new ApiError(
          HTTP_STATUS.UNAUTHORIZED,
          'Token has expired'
        );
      }
      if (error.name === 'JsonWebTokenError') {
        throw new ApiError(
          HTTP_STATUS.UNAUTHORIZED,
          'Invalid token'
        );
      }
      throw error;
    }
  } catch (error) {
    next(error);
  }
};

/**
 * Authorize specific roles
 * @param  {...string} allowedRoles - Roles allowed to access this route
 * @returns {Function} Middleware function
 */
const authorizeRole = (...allowedRoles) => {
  return (req, res, next) => {
    try {
      if (!req.user) {
        throw new ApiError(
          HTTP_STATUS.UNAUTHORIZED,
          'Authentication required'
        );
      }

      if (!allowedRoles.includes(req.user.role)) {
        logger.warn('Unauthorized access attempt', {
          userId: req.user.id,
          requiredRole: allowedRoles,
          userRole: req.user.role,
          path: req.path,
        });

        throw new ApiError(
          HTTP_STATUS.FORBIDDEN,
          `Access denied. Required role(s): ${allowedRoles.join(', ')}`
        );
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};

/**
 * Shorthand: Only admin can access
 */
const adminOnly = authorizeRole(USER_ROLES.ADMIN);

/**
 * Shorthand: Only candidate can access
 */
const candidateOnly = authorizeRole(USER_ROLES.CANDIDATE);

/**
 * Shorthand: Both admin and candidate can access
 */
const adminOrCandidate = authorizeRole(USER_ROLES.ADMIN, USER_ROLES.CANDIDATE);

module.exports = {
  authenticateToken,
  authorizeRole,
  adminOnly,
  candidateOnly,
  adminOrCandidate,
};
