# TestGorilla Backend API

Production-ready Node.js + Express backend for a TestGorilla-like assessment platform.

## Prerequisites

- Node.js (v16+)
- PostgreSQL (v12+)
- npm or yarn

## Installation

1. **Clone and install dependencies:**
```bash
cd backend
npm install
```

2. **Set up environment variables:**
```bash
cp .env.example .env
```

Edit `.env` with your configuration:
```env
NODE_ENV=development
PORT=5000

DB_HOST=localhost
DB_PORT=5432
DB_NAME=testgorilla
DB_USER=postgres
DB_PASSWORD=postgres

CORS_ORIGIN=http://localhost:3000
LOG_LEVEL=debug
```

3. **Create PostgreSQL database:**
```bash
createdb testgorilla
```

4. **Start the server:**

**Development (with hot reload):**
```bash
npm run dev
```

**Production:**
```bash
npm start
```

## Architecture

```
src/
├── app.js                 # Express app setup
├── server.js              # Entry point & server startup
├── config/
│   └── db.js              # PostgreSQL pool configuration
├── routes/
│   ├── health.js          # Health check endpoint
│   └── ...                # Other route modules
├── controllers/           # Business logic handlers
├── middleware/
│   ├── errorHandler.js    # Global error handling
│   ├── cors.js            # CORS configuration
│   └── requestLogger.js   # Request logging
└── utils/
    ├── logger.js          # Logging utility
    └── constants.js       # Application constants
```

## API Endpoints

### Health Check
- **GET** `/api/v1/health` - Check API and database status

### Root
- **GET** `/` - API welcome page

## Features

✅ **Express.js** - Fast and minimal web framework
✅ **PostgreSQL** - Production-grade relational database
✅ **Connection Pool** - Efficient database connection management
✅ **CORS** - Configurable cross-origin requests
✅ **Error Handling** - Centralized error management
✅ **Logging** - Structured logging with levels
✅ **Graceful Shutdown** - Proper cleanup on shutdown
✅ **Environment Variables** - Configuration via .env

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| NODE_ENV | development | Application environment |
| PORT | 5000 | Server port |
| DB_HOST | localhost | Database host |
| DB_PORT | 5432 | Database port |
| DB_NAME | testgorilla | Database name |
| DB_USER | postgres | Database user |
| DB_PASSWORD | postgres | Database password |
| DB_POOL_MIN | 2 | Minimum pool connections |
| DB_POOL_MAX | 10 | Maximum pool connections |
| CORS_ORIGIN | http://localhost:3000 | Allowed CORS origins |
| LOG_LEVEL | debug | Log level (debug, info, warn, error) |

## Development

### Run in development mode with hot reload:
```bash
npm run dev
```

### Access the API:
```bash
curl http://localhost:5000/api/v1/health
```

## Database Connection

The application uses PostgreSQL connection pooling for better performance:
- Minimum pool size: 2
- Maximum pool size: 10
- Idle timeout: 30 seconds
- Connection timeout: 2 seconds

## Error Handling

Global error handler catches all errors and returns standardized JSON responses:

```json
{
  "success": false,
  "error": {
    "message": "Error message",
    "details": "..." // Only in development
  }
}
```

## Logging

Structured logging with timestamps and levels:
- **debug** - Detailed diagnostic information
- **info** - General informational messages
- **warn** - Warning messages
- **error** - Error messages

### Adjust log level in .env:
```env
LOG_LEVEL=debug  # Shows all logs
LOG_LEVEL=info   # Shows info, warn, error
LOG_LEVEL=error  # Shows only errors
```

## Next Steps

1. Add authentication routes
2. Implement database migrations
3. Create test management routes
4. Add question management
5. Implement test attempt logic
6. Add evaluation engine
7. Create recruiter dashboard routes

## License

MIT
