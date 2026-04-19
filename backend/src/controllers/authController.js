const authService = require('../services/authService');
const { HTTP_STATUS } = require('../utils/constants');

/**
 * Register a new user
 * POST /api/v1/auth/register
 */
const register = async (req, res, next) => {
  try {
    const { name, email, password, role } = req.body;

    const user = await authService.registerUser({
      name,
      email,
      password,
      role,
    });

    res.status(HTTP_STATUS.CREATED).json({
      success: true,
      message: 'User registered successfully',
      data: {
        user,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Login user
 * POST /api/v1/auth/login
 */
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const result = await authService.loginUser(email, password);

    // Set refresh token as httpOnly cookie (optional, for extra security)
    res.cookie('refreshToken', result.refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
    });

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Login successful',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get current user profile
 * GET /api/v1/auth/me
 * Protected route (requires valid JWT token)
 */
const getCurrentUser = async (req, res, next) => {
  try {
    const user = await authService.getUserById(req.user.id);

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'User profile retrieved',
      data: {
        user,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Logout user
 * POST /api/v1/auth/logout
 * Protected route
 */
const logout = async (req, res, next) => {
  try {
    // Clear refresh token cookie
    res.clearCookie('refreshToken');

    res.status(HTTP_STATUS.OK).json({
      success: true,
      message: 'Logout successful',
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  getCurrentUser,
  logout,
};
