const { Pool } = require('pg');
const logger = require('../utils/logger');

const useSsl = process.env.DB_SSL === 'true';
const sslConfig = useSsl ? { rejectUnauthorized: false } : false;
const connectionString = process.env.DATABASE_URL;

// Create a pool of connections for PostgreSQL
const poolConfig = {
  min: parseInt(process.env.DB_POOL_MIN) || 2,
  max: parseInt(process.env.DB_POOL_MAX) || 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
  ssl: sslConfig,
};

if (connectionString) {
  poolConfig.connectionString = connectionString;
} else {
  poolConfig.host = process.env.DB_HOST || 'localhost';
  poolConfig.port = process.env.DB_PORT || 5432;
  poolConfig.database = process.env.DB_NAME || 'testgorilla';
  poolConfig.user = process.env.DB_USER || 'postgres';
  poolConfig.password = process.env.DB_PASSWORD || 'postgres';
}

const pool = new Pool(poolConfig);

/**
 * Handle pool errors
 */
pool.on('error', (err) => {
  logger.error('Unexpected error on idle client', err);
});

/**
 * Test the database connection
 * @returns {Promise<void>}
 */
const testConnection = async () => {
  const client = await pool.connect();
  try {
    const result = await client.query('SELECT NOW()');
    logger.info('Database connection successful:', result.rows[0]);
  } catch (err) {
    logger.error('Database connection failed:', err);
    throw err;
  } finally {
    client.release();
  }
};

/**
 * Execute a query and return results
 * @param {string} query - SQL query string
 * @param {Array} params - Query parameters
 * @returns {Promise<Object>} Query result object
 */
const query = async (queryText, params = []) => {
  const start = Date.now();
  try {
    const result = await pool.query(queryText, params);
    const duration = Date.now() - start;
    logger.debug(`Executed query in ${duration}ms`, { query: queryText, duration });
    return result;
  } catch (error) {
    logger.error('Database query error', { query: queryText, error: error.message });
    throw error;
  }
};

/**
 * Get a client from the pool for transactions
 * @returns {Promise<Object>} Database client
 */
const getClient = async () => {
  return await pool.connect();
};

/**
 * End the pool and close all connections
 * @returns {Promise<void>}
 */
const closePool = async () => {
  await pool.end();
  logger.info('Database pool closed');
};

module.exports = {
  pool,
  testConnection,
  query,
  getClient,
  closePool,
};
