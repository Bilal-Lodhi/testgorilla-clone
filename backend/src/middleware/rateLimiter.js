/**
 * Rate limiting middleware for access code verification
 * Protects against brute force attacks on /tests/:id/verify-access
 *
 * Tracks failed attempts per (IP + testId) combination.
 * After MAX_ATTEMPTS failures → BLOCK_DURATION minutes lockout.
 * Returns 429 Too Many Requests when limit exceeded.
 */

const { HTTP_STATUS } = require('../utils/constants');
const { ApiError } = require('./errorHandler');
const logger = require('../utils/logger');

// Configuration
const MAX_ATTEMPTS = 5;
const BLOCK_DURATION_MS = 10 * 60 * 1000; // 10 minutes
const WINDOW_MS = 15 * 60 * 1000; // 15 minute sliding window

/**
 * In-memory store for rate limiting.
 * Key: `${ip}:${testId}` → { count, firstAttempt, blockedUntil }
 *
 * For production, replace with Redis to survive server restarts
 * and work across multiple instances.
 */
const attemptStore = new Map();

/**
 * Periodic cleanup of expired entries (every 5 minutes)
 */
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of attemptStore.entries()) {
    if (entry.blockedUntil && entry.blockedUntil < now) {
      attemptStore.delete(key);
    } else if (!entry.blockedUntil && entry.firstAttempt + WINDOW_MS < now) {
      attemptStore.delete(key);
    }
  }
}, 5 * 60 * 1000);

/**
 * Get client IP from request (handles proxies)
 */
function getClientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || 'unknown';
}

/**
 * Build rate limit key
 */
function getKey(ip, testId) {
  return `${ip}:${testId}`;
}

/**
 * Rate limiting middleware factory
 * Must be used AFTER authenticateToken middleware so req.user is available
 *
 * @param {Object} options
 * @param {number} options.maxAttempts - Max failed attempts before lockout (default 5)
 * @param {number} options.blockDurationMs - Lockout duration in ms (default 10 min)
 * @param {number} options.windowMs - Sliding window in ms (default 15 min)
 * @returns {Function} Express middleware
 */
function accessCodeRateLimiter(options = {}) {
  const maxAttempts = options.maxAttempts || MAX_ATTEMPTS;
  const blockDurationMs = options.blockDurationMs || BLOCK_DURATION_MS;
  const windowMs = options.windowMs || WINDOW_MS;

  return (req, res, next) => {
    try {
      const testId = req.params.testId || req.params.id;
      const ip = getClientIp(req);
      const key = getKey(ip, testId);
      const now = Date.now();

      let entry = attemptStore.get(key);

      if (!entry || entry.firstAttempt + windowMs < now) {
        // No recent attempts or window expired — start fresh
        entry = { count: 0, firstAttempt: now, blockedUntil: null };
        attemptStore.set(key, entry);
      }

      // Check if currently blocked
      if (entry.blockedUntil && entry.blockedUntil > now) {
        const remainingMs = entry.blockedUntil - now;
        const remainingMin = Math.ceil(remainingMs / 60000);

        logger.warn('Rate limit: access code verification blocked', {
          ip,
          testId,
          userId: req.user?.id,
          remainingMinutes: remainingMin,
        });

        throw new ApiError(
          HTTP_STATUS.TOO_MANY_REQUESTS,
          `Too many failed attempts. Try again in ${remainingMin} minute(s).`
        );
      }

      // Attach tracking functions to req for the route handler to use
      req._rateLimitRecordFailure = () => {
        const currentEntry = attemptStore.get(key);
        if (currentEntry) {
          currentEntry.count += 1;
          logger.debug('Rate limit: recorded failure', {
            ip,
            testId,
            count: currentEntry.count,
            maxAttempts,
          });

          if (currentEntry.count >= maxAttempts) {
            currentEntry.blockedUntil = now + blockDurationMs;
            logger.warn('Rate limit: access code verification locked out', {
              ip,
              testId,
              userId: req.user?.id,
              blockDurationMinutes: blockDurationMs / 60000,
            });
          }
        }
      };

      req._rateLimitRecordSuccess = () => {
        // On success, clear the entry so successful attempts don't count against limit
        attemptStore.delete(key);
        logger.debug('Rate limit: cleared on success', { ip, testId });
      };

      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Get current rate limit status (for debugging/admin purposes)
 */
function getRateLimitStatus(ip, testId) {
  const key = getKey(ip, testId);
  const entry = attemptStore.get(key);

  if (!entry) {
    return { blocked: false, attempts: 0, maxAttempts: MAX_ATTEMPTS };
  }

  const now = Date.now();
  const isBlocked = entry.blockedUntil && entry.blockedUntil > now;
  const remaining = Math.max(0, MAX_ATTEMPTS - entry.count);

  return {
    blocked: isBlocked,
    attempts: entry.count,
    maxAttempts: MAX_ATTEMPTS,
    remaining,
    blockedUntil: entry.blockedUntil
      ? new Date(entry.blockedUntil).toISOString()
      : null,
  };
}

module.exports = {
  accessCodeRateLimiter,
  getRateLimitStatus,
};