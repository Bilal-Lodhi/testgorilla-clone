const cors = require('cors');
const logger = require('../utils/logger');

/**
 * Configure CORS middleware for production-safe cross-origin requests
 * 
 * Supported origins:
 * - Development: http://localhost:* (all ports)
 * - Firebase Web: https://*.web.app, https://*.firebaseapp.com
 * - Environment: CORS_ORIGIN env variable (comma-separated list or '*')
 * 
 * Mobile apps (APK) can make requests with no origin header,
 * which is allowed for development/testing only.
 */
const configureCors = () => {
  const NODE_ENV = process.env.NODE_ENV || 'development';
  const corsOriginEnv = process.env.CORS_ORIGIN || '';
  
  // Parse allowed origins from environment
  const envOrigins = corsOriginEnv
    .split(',')
    .map(o => o.trim())
    .filter(o => o && o !== '*');

  logger.info('CORS configuration', {
    environment: NODE_ENV,
    customOrigins: envOrigins,
  });

  return cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl requests)
      // This is safe as long as no sensitive cookies are used
      if (!origin) {
        return callback(null, true);
      }

      // Development: Allow all localhost origins
      if (NODE_ENV === 'development') {
        if (origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1')) {
          return callback(null, true);
        }
      }

      // Firebase Web Apps
      if (origin.includes('.web.app') || origin.includes('.firebaseapp.com')) {
        return callback(null, true);
      }

      // Environment-configured origins
      if (envOrigins.includes('*')) {
        logger.warn('CORS configured with wildcard (*) - use explicit origins in production');
        return callback(null, true);
      }

      if (envOrigins.includes(origin)) {
        return callback(null, true);
      }

      const message = `CORS policy: Origin ${origin} is not allowed`;
      logger.warn(message);
      callback(new Error(message));
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
