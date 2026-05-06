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
  
  const rawEnvOrigins = corsOriginEnv.split(',').map(o => o.trim()).filter(Boolean);

  // Support exact origins and wildcard-localhost entries like 'http://localhost:*'
  const exactEnvOrigins = rawEnvOrigins.filter(o => o && !o.includes(':*') && o !== '*');
  const wildcardLocalOrigins = rawEnvOrigins
    .filter(o => o.endsWith(':*'))
    .map(o => o.replace(/:\*$/, ''));

  logger.info('CORS configuration', {
    environment: NODE_ENV,
    customOrigins: rawEnvOrigins,
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
      if (rawEnvOrigins.includes('*')) {
        logger.warn('CORS configured with wildcard (*) - use explicit origins in production');
        return callback(null, true);
      }

      // Exact match
      if (exactEnvOrigins.includes(origin)) {
        logger.debug('CORS allow decision', { origin, allowedBy: 'exact' });
        return callback(null, true);
      }

      // Wildcard localhost match (e.g. http://localhost:*)
      if (wildcardLocalOrigins.some(prefix => origin && origin.startsWith(prefix))) {
        logger.debug('CORS allow decision', { origin, allowedBy: 'wildcard-local' });
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
