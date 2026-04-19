const express = require('express');
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');

const router = express.Router();

/**
 * POST /api/v1/auth/register
 * Public route - Register a new user
 */
router.post('/register', asyncHandler(authController.register));

/**
 * POST /api/v1/auth/login
 * Public route - Login user and get tokens
 */
router.post('/login', asyncHandler(authController.login));

/**
 * GET /api/v1/auth/me
 * Protected route - Get current user profile
 */
router.get('/me', authenticateToken, asyncHandler(authController.getCurrentUser));

/**
 * POST /api/v1/auth/logout
 * Protected route - Logout user
 */
router.post('/logout', authenticateToken, asyncHandler(authController.logout));

module.exports = router;
