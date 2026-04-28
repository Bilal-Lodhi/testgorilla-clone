const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const db = require('../config/db');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS } = require('../utils/constants');
const logger = require('../utils/logger');

const TOKEN_EXPIRY_MINUTES = 20; // 15-30 min range

/**
 * Generate a random token
 * @returns {string} Random token
 */
const generateToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

/**
 * Hash token for storage
 * @param {string} token - Plain token
 * @returns {string} Hashed token
 */
const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

/**
 * Create verification token
 * @param {string} userId - User ID
 * @param {string} type - Token type (email_verification | password_reset)
 * @returns {Promise<string>} Plain token (send to user)
 */
const createToken = async (userId, type) => {
  const plainToken = generateToken();
  const tokenHash = hashToken(plainToken);
  const expiresAt = new Date(Date.now() + TOKEN_EXPIRY_MINUTES * 60 * 1000);

  await db.query(
    `INSERT INTO verification_tokens (user_id, token_hash, type, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [userId, tokenHash, type, expiresAt]
  );

  logger.info('Token created', { userId, type });
  return plainToken;
};

/**
 * Verify and consume token
 * @param {string} token - Plain token from user
 * @param {string} type - Token type
 * @returns {Promise<Object>} User data
 */
const verifyToken = async (token, type) => {
  const tokenHash = hashToken(token);

  const result = await db.query(
    `SELECT vt.id, vt.user_id, vt.used_at, vt.expires_at, u.email
     FROM verification_tokens vt
     JOIN users u ON vt.user_id = u.id
     WHERE vt.token_hash = $1 AND vt.type = $2`,
    [tokenHash, type]
  );

  if (result.rows.length === 0) {
    throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'Invalid or expired token');
  }

  const tokenRecord = result.rows[0];

  // Check if already used
  if (tokenRecord.used_at) {
    throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'Token already used');
  }

  // Check if expired
  if (new Date() > new Date(tokenRecord.expires_at)) {
    throw new ApiError(HTTP_STATUS.BAD_REQUEST, 'Token expired');
  }

  // Mark as used
  await db.query(
    `UPDATE verification_tokens SET used_at = CURRENT_TIMESTAMP WHERE id = $1`,
    [tokenRecord.id]
  );

  return { userId: tokenRecord.user_id, email: tokenRecord.email };
};

/**
 * Invalidate all tokens of a type for a user
 * @param {string} userId - User ID
 * @param {string} type - Token type
 */
const invalidateTokens = async (userId, type) => {
  await db.query(
    `UPDATE verification_tokens SET used_at = CURRENT_TIMESTAMP
     WHERE user_id = $1 AND type = $2 AND used_at IS NULL`,
    [userId, type]
  );
};

module.exports = {
  createToken,
  verifyToken,
  invalidateTokens,
};
