const cors = require('cors');
const logger = require('../utils/logger');

/**
 * Configure CORS middleware
 * Allows requests from specified origins
 */
const configureCors = () => {
  const allowedOrigins = (process.env.CORS_ORIGIN || 'http://localhost:*').split(',');

  logger.info('CORS enabled for origins:', { origins: allowedOrigins });

  return cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl requests)
      if (!origin) {
        return callback(null, true);
      }

      // Allow all localhost origins in development
      if (origin && origin.startsWith('http://localhost')) {
        callback(null, true);
      } else if (origin && origin.startsWith('http://127.0.0.1')) {
        callback(null, true);
      } else if (allowedOrigins.includes(origin) || allowedOrigins.includes('*')) {
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
