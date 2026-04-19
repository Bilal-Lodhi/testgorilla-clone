const express = require('express');
const db = require('../config/db');
const { asyncHandler } = require('../middleware/errorHandler');
const { HTTP_STATUS } = require('../utils/constants');

const router = express.Router();

/**
 * GET /health
 * Health check endpoint
 * Returns status of the API and database connection
 */
router.get('/health', asyncHandler(async (req, res) => {
  const result = await db.query('SELECT NOW()');

  res.status(HTTP_STATUS.OK).json({
    success: true,
    message: 'API is healthy',
    timestamp: new Date().toISOString(),
    database: {
      connected: !!result,
      serverTime: result.rows[0].now,
    },
  });
}));

module.exports = router;
