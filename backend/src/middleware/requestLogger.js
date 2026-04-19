const logger = require('../utils/logger');

/**
 * Log all incoming requests
 */
const requestLogger = (req, res, next) => {
  const startTime = Date.now();

  // Log request
  logger.debug(`Incoming ${req.method} request`, {
    path: req.path,
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });

  // Log response on finish
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    logger.debug(`${req.method} ${req.path} completed`, {
      statusCode: res.statusCode,
      duration: `${duration}ms`,
    });
  });

  next();
};

module.exports = requestLogger;
