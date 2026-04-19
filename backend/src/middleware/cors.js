const cors = require('cors');
const logger = require('../utils/logger');

/**
 * Configure CORS middleware
 * Allows requests from specified origins
 */
const configureCors = () => {
  const allowedOrigins = (process.env.CORS_ORIGIN || 'http://localhost:3000').split(',');

  logger.info('CORS enabled for origins:', { origins: allowedOrigins });

  return cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl requests)
      if (!origin) {
        return callback(null, true);
      }

      if (allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        const message = `CORS policy: Origin ${origin} is not allowed`;
        logger.warn(message);
        callback(new Error(message));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 3600,
  });
};

module.exports = {
  configureCors,
};
