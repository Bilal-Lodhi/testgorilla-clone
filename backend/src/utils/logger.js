const LOG_LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

const currentLogLevel = LOG_LEVELS[process.env.LOG_LEVEL || 'debug'];

/**
 * Format log message with timestamp
 * @param {string} level - Log level
 * @param {string} message - Log message
 * @param {Object} data - Additional data
 * @returns {string} Formatted log message
 */
const formatLog = (level, message, data) => {
  const timestamp = new Date().toISOString();
  const dataStr = data ? ` ${JSON.stringify(data)}` : '';
  return `[${timestamp}] [${level.toUpperCase()}] ${message}${dataStr}`;
};

const logger = {
  debug: (message, data) => {
    if (currentLogLevel <= LOG_LEVELS.debug) {
      console.log(formatLog('debug', message, data));
    }
  },
  info: (message, data) => {
    if (currentLogLevel <= LOG_LEVELS.info) {
      console.log(formatLog('info', message, data));
    }
  },
  warn: (message, data) => {
    if (currentLogLevel <= LOG_LEVELS.warn) {
      console.warn(formatLog('warn', message, data));
    }
  },
  error: (message, data) => {
    if (currentLogLevel <= LOG_LEVELS.error) {
      console.error(formatLog('error', message, data));
    }
  },
};

module.exports = logger;
