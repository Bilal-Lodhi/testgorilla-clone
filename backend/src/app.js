const express = require('express');
const { configureCors } = require('./middleware/cors');
const requestLogger = require('./middleware/requestLogger');
const { errorHandler, notFound } = require('./middleware/errorHandler');
const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/auth');
const testRoutes = require('./routes/tests');
const questionRoutes = require('./routes/questions');
const attemptRoutes = require('./routes/attempts');
const resultRoutes = require('./routes/results');
const logger = require('./utils/logger');

// Create Express app
const app = express();

/**
 * ===== MIDDLEWARE SETUP =====
 */

// CORS configuration
app.use(configureCors());

// Body parser middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ limit: '10mb', extended: true }));

// Request logging
app.use(requestLogger);

/**
 * ===== ROUTES =====
 */

// Health check route
app.use('/api/v1', healthRoutes);

// Authentication routes
app.use('/api/v1/auth', authRoutes);

// Test management routes
app.use('/api/v1/tests', testRoutes);

// Question management routes (nested under tests with parameter inheritance)
app.use('/api/v1/tests/:testId/questions', questionRoutes);

// Test attempts routes (nested under tests)
app.use('/api/v1/tests/:testId/attempts', attemptRoutes);

// Standalone attempt endpoints
app.use('/api/v1/attempts', attemptRoutes);
app.use('/api/v1/candidates/attempts', attemptRoutes);

// Results and evaluation routes
app.use('/api/v1/results', resultRoutes);
app.use('/api/v1/tests/:testId/results', resultRoutes);
app.use('/api/v1/candidates/:userId/results', resultRoutes);

// API welcome route
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'TestGorilla API Server',
    version: '1.0.0',
    status: 'running',
    endpoints: {
      health: '/api/v1/health',
      auth: {
        register: 'POST /api/v1/auth/register',
        login: 'POST /api/v1/auth/login',
        profile: 'GET /api/v1/auth/me',
        logout: 'POST /api/v1/auth/logout',
      },
      tests: {
        create: 'POST /api/v1/tests (admin only)',
        list: 'GET /api/v1/tests (admin: own tests, candidate: published)',
        get: 'GET /api/v1/tests/:id',
        update: 'PUT /api/v1/tests/:id (admin only)',
        delete: 'DELETE /api/v1/tests/:id (admin only)',
        publish: 'PATCH /api/v1/tests/:id/publish (admin only)',
        archive: 'PATCH /api/v1/tests/:id/archive (admin only)',
      },
      questions: {
        create: 'POST /api/v1/tests/:testId/questions (admin only)',
        list: 'GET /api/v1/tests/:testId/questions',
        get: 'GET /api/v1/tests/:testId/questions/:questionId',
        update: 'PUT /api/v1/tests/:testId/questions/:questionId (admin only)',
        delete: 'DELETE /api/v1/tests/:testId/questions/:questionId (admin only)',
      },
      attempts: {
        start: 'POST /api/v1/tests/:testId/attempts (candidate only)',
        get: 'GET /api/v1/attempts/:attemptId',
        submitResponse: 'POST /api/v1/attempts/:attemptId/responses (candidate only)',
        submit: 'POST /api/v1/attempts/:attemptId/submit (candidate only)',
        candidateAttempts: 'GET /api/v1/candidates/attempts (candidate)',
        testAttempts: 'GET /api/v1/tests/:testId/attempts (admin only)',
      },
      results: {
        getAttemptResult: 'GET /api/v1/results/:attemptId (candidate own or admin)',
        getTestResults: 'GET /api/v1/tests/:testId/results (admin only)',
        getTestStatistics: 'GET /api/v1/tests/:testId/results/statistics (admin only)',
        getCandidateResults: 'GET /api/v1/candidates/:userId/results (candidate own or admin)',
      },
    },
  });
});

/**
 * ===== ERROR HANDLING =====
 */

// 404 handler (must be before error handler)
app.use(notFound);

// Global error handler (must be last)
app.use(errorHandler);

/**
 * ===== START LOGGING =====
 */
logger.info('Express app configured successfully');

module.exports = app;
