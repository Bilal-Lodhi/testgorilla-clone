const bcrypt = require('bcryptjs');
const db = require('../config/db');
const { generateAccessToken, generateRefreshToken } = require('../utils/jwt');
const { ApiError } = require('../middleware/errorHandler');
const { HTTP_STATUS, USER_ROLES } = require('../utils/constants');
const logger = require('../utils/logger');

/**
 * Hash password using bcrypt
 * @param {string} password - Plain password
 * @returns {Promise<string>} Hashed password
 */
const hashPassword = async (password) => {
  const saltRounds = parseInt(process.env.BCRYPT_SALT_ROUNDS) || 10;
  return await bcrypt.hash(password, saltRounds);
};

/**
 * Compare password with hash
 * @param {string} password - Plain password
 * @param {string} hash - Password hash
 * @returns {Promise<boolean>} True if password matches
 */
const comparePassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};

/**
 * Register a new user
 * @param {Object} userData - User data
 * @param {string} userData.name - User name
 * @param {string} userData.email - User email
 * @param {string} userData.password - User password
 * @param {string} userData.role - User role (admin | candidate)
 * @returns {Promise<Object>} Created user
 */
const registerUser = async ({ name, email, password, role = USER_ROLES.CANDIDATE }) => {
  // Validate input
  if (!name || !email || !password) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Name, email, and password are required'
    );
  }

  if (password.length < 6) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Password must be at least 6 characters long'
    );
  }

  if (!Object.values(USER_ROLES).includes(role)) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      `Invalid role. Must be one of: ${Object.values(USER_ROLES).join(', ')}`
    );
  }

  // Check if user already exists
  const existingUser = await db.query(
    'SELECT id FROM users WHERE email = $1',
    [email.toLowerCase()]
  );

  if (existingUser.rows.length > 0) {
    throw new ApiError(
      HTTP_STATUS.CONFLICT,
      'User with this email already exists'
    );
  }

  // Hash password
  const passwordHash = await hashPassword(password);

  // Create user
  const result = await db.query(
    `INSERT INTO users (name, email, password_hash, role, created_at)
     VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
     RETURNING id, name, email, role, created_at`,
    [name, email.toLowerCase(), passwordHash, role]
  );

  const user = result.rows[0];

  logger.info('User registered successfully', {
    userId: user.id,
    email: user.email,
    role: user.role,
  });

  return user;
};

/**
 * Login user and generate tokens
 * @param {string} email - User email
 * @param {string} password - User password
 * @returns {Promise<Object>} User data and tokens
 */
const loginUser = async (email, password) => {
  // Validate input
  if (!email || !password) {
    throw new ApiError(
      HTTP_STATUS.BAD_REQUEST,
      'Email and password are required'
    );
  }

  // Find user by email
  const result = await db.query(
    'SELECT id, name, email, password_hash, role FROM users WHERE email = $1',
    [email.toLowerCase()]
  );

  if (result.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.UNAUTHORIZED,
      'Invalid email or password'
    );
  }

  const user = result.rows[0];

  // Verify password
  const passwordMatch = await comparePassword(password, user.password_hash);

  if (!passwordMatch) {
    logger.warn('Failed login attempt', { email: user.email });
    throw new ApiError(
      HTTP_STATUS.UNAUTHORIZED,
      'Invalid email or password'
    );
  }

  // Generate tokens
  const tokenPayload = {
    id: user.id,
    email: user.email,
    role: user.role,
  };

  const accessToken = generateAccessToken(tokenPayload);
  const refreshToken = generateRefreshToken(tokenPayload);

  logger.info('User logged in successfully', {
    userId: user.id,
    email: user.email,
  });

  return {
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
    },
    accessToken,
    refreshToken,
  };
};

/**
 * Get user by ID
 * @param {string} userId - User ID
 * @returns {Promise<Object>} User object
 */
const getUserById = async (userId) => {
  const result = await db.query(
    'SELECT id, name, email, role, created_at FROM users WHERE id = $1',
    [userId]
  );

  if (result.rows.length === 0) {
    throw new ApiError(
      HTTP_STATUS.NOT_FOUND,
      'User not found'
    );
  }

  return result.rows[0];
};

/**
 * Verify user credentials and return user data
 * @param {string} userId - User ID
 * @returns {Promise<Object>} User data
 */
const verifyUserSession = async (userId) => {
  return await getUserById(userId);
};

module.exports = {
  registerUser,
  loginUser,
  getUserById,
  verifyUserSession,
  hashPassword,
  comparePassword,
};
