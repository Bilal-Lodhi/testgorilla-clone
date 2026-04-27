## JWT Authentication System Setup Guide

### Quick Start

#### 1. Install Dependencies
```bash
cd backend
npm install
```

#### 2. Create Database
```bash
createdb testgorilla
```

#### 3. Run Migration
```bash
psql testgorilla < migrations/001_create_users_table.sql
```

#### 4. Configure Environment
Copy and update `.env`:
```bash
cp .env.example .env
```

Set these critical variables:
```env
JWT_SECRET=your-super-secret-key-minimum-32-characters
JWT_EXPIRY=24h
REFRESH_TOKEN_EXPIRY=7d
BCRYPT_SALT_ROUNDS=10
```

#### 5. Start Server
```bash
npm run dev
```

You should see:
```
[2026-04-15T...] [INFO] Database connection successful
[2026-04-15T...] [INFO] Server started successfully { port: 5000 }
```

---

## API Endpoints

### 1. Register User
**POST** `/api/v1/auth/register`

Request body:
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "securepassword123",
  "role": "candidate"
}
```

Response (201 Created):
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "candidate",
      "created_at": "2026-04-15T10:30:00.000Z"
    }
  }
}
```

**Validation Rules:**
- Name: Required, any string
- Email: Required, must be unique, valid email format
- Password: Required, minimum 6 characters
- Role: Optional, defaults to "candidate" (values: "admin" | "candidate")

---

### 2. Login User
**POST** `/api/v1/auth/login`

Request body:
```json
{
  "email": "john@example.com",
  "password": "securepassword123"
}
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "candidate"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}
```

**Note:** Refresh token is also set as httpOnly cookie for extra security.

---

### 3. Get Current User Profile
**GET** `/api/v1/auth/me`

Headers (required):
```
Authorization: Bearer <accessToken>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "User profile retrieved",
  "data": {
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "John Doe",
      "email": "john@example.com",
      "role": "candidate",
      "created_at": "2026-04-15T10:30:00.000Z"
    }
  }
}
```

---

### 4. Logout User
**POST** `/api/v1/auth/logout`

Headers (required):
```
Authorization: Bearer <accessToken>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Logout successful"
}
```

---

## Using Protected Routes

### Authentication Middleware
To protect routes, use `authenticateToken` middleware:

```javascript
const { authenticateToken } = require('../middleware/authMiddleware');

// Protected route example
router.get('/protected-route', authenticateToken, (req, res) => {
  // req.user contains: { id, email, role }
  console.log('User ID:', req.user.id);
  res.json({ data: 'Only authenticated users can see this' });
});
```

### Role-Based Access Control
Use role authorization middleware for specific role access:

```javascript
const { adminOnly, candidateOnly, adminOrCandidate } = require('../middleware/authMiddleware');

// Admin only route
router.post('/admin/create-test', adminOnly, (req, res) => {
  // Only users with role='admin' can access
});

// Candidate only route
router.post('/candidate/attempt-test', candidateOnly, (req, res) => {
  // Only users with role='candidate' can access
});

// Both roles allowed
router.get('/results', adminOrCandidate, (req, res) => {
  // Both admin and candidate can access
});
```

---

## File Structure & Responsibilities

```
src/
├── utils/
│   └── jwt.js                    # Token generation, verification, extraction
├── services/
│   └── authService.js            # Business logic (register, login, user lookup)
├── controllers/
│   └── authController.js         # Route handlers (request/response handling)
├── middleware/
│   └── authMiddleware.js         # JWT verification & role authorization
├── routes/
│   └── auth.js                   # Auth endpoint definitions
└── app.js                        # Includes auth routes in Express app

migrations/
└── 001_create_users_table.sql    # Users table with indexes & triggers
```

---

## Complete Example: Testing with cURL

### 1. Register
```bash
curl -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jane Smith",
    "email": "jane@example.com",
    "password": "password123",
    "role": "admin"
  }'
```

### 2. Login
```bash
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "jane@example.com",
    "password": "password123"
  }'
```

Save the `accessToken` from response.

### 3. Get Profile (Protected Route)
```bash
curl -X GET http://localhost:5000/api/v1/auth/me \
  -H "Authorization: Bearer <YOUR_ACCESS_TOKEN>"
```

### 4. Logout
```bash
curl -X POST http://localhost:5000/api/v1/auth/logout \
  -H "Authorization: Bearer <YOUR_ACCESS_TOKEN>"
```

---

## Error Handling

### Common Errors

**400 Bad Request** - Missing or invalid fields
```json
{
  "success": false,
  "error": {
    "message": "Password must be at least 6 characters long"
  }
}
```

**409 Conflict** - Email already exists
```json
{
  "success": false,
  "error": {
    "message": "User with this email already exists"
  }
}
```

**401 Unauthorized** - Invalid credentials
```json
{
  "success": false,
  "error": {
    "message": "Invalid email or password"
  }
}
```

**401 Unauthorized** - Missing or expired token
```json
{
  "success": false,
  "error": {
    "message": "No token provided. Use Authorization header with Bearer token"
  }
}
```

**403 Forbidden** - Insufficient permissions
```json
{
  "success": false,
  "error": {
    "message": "Access denied. Required role(s): admin"
  }
}
```

---

## Security Features

✅ **Password Hashing** - bcryptjs with configurable salt rounds  
✅ **JWT Tokens** - Secure access tokens (24 hours) + refresh tokens (7 days)  
✅ **Token Verification** - Validates signature, expiration, issuer  
✅ **Role-Based Access Control** - Fine-grained permission control  
✅ **HTTP-Only Cookies** - Refresh tokens stored securely  
✅ **Email Uniqueness** - Prevents duplicate user registrations  
✅ **Input Validation** - Checks all required fields  
✅ **Secure Logout** - Clears refresh token cookies  

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| JWT_SECRET | *required* | Secret key for signing tokens (min 32 chars in production) |
| JWT_EXPIRY | 24h | Access token expiration time |
| REFRESH_TOKEN_EXPIRY | 7d | Refresh token expiration time |
| BCRYPT_SALT_ROUNDS | 10 | Password hashing rounds (higher = slower but more secure) |
| NODE_ENV | development | Environment mode |
| PORT | 5000 | Server port |

---

## Database Schema

### Users Table
```sql
users (
  id UUID PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL (admin | candidate),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)

Indexes:
- idx_users_email    -- Fast email lookups for login
- idx_users_role     -- Fast filtering by role
```

---

## Extending the System

### Adding More Routes with Role Protection

```javascript
// In routes/tests.js
const { adminOnly } = require('../middleware/authMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');

router.post('/tests', adminOnly, asyncHandler(async (req, res) => {
  // Create test - only admins can access
}));
```

### Custom Role Authorization

```javascript
const { authorizeRole } = require('../middleware/authMiddleware');

// Allow multiple roles
router.get('/dashboard', 
  authorizeRole('admin', 'recruiter'), 
  handler
);
```

### Access User Info in Routes

```javascript
router.get('/my-data', authenticateToken, (req, res) => {
  const userId = req.user.id;      // UUID
  const userEmail = req.user.email; // Email
  const userRole = req.user.role;   // admin | candidate
  
  // Use in your logic
});
```

---

## Troubleshooting

### "Invalid token" Error
- Check token hasn't expired
- Verify JWT_SECRET matches between encoding and decoding
- Confirm Authorization header format: `Bearer <token>`

### "User not found" During Login
- Verify email is registered correctly
- Check password matches (case-sensitive)
- Ensure database migration ran successfully

### "Access denied. Required role(s): admin"
- Verify user account has correct role in database
- Check Authorization header is included
- Confirm token is valid and not expired

### "Bcrypt errors"
- `npm install bcryptjs` to ensure module is installed
- Check BCRYPT_SALT_ROUNDS is a valid number (8-12 recommended)

---

## Next Steps

1. **Test endpoints** using the cURL examples above
2. **Implement test management** routes (create/read/update/delete tests)
3. **Add question management** routes
4. **Create test attempt** routes for candidates
5. **Build evaluation engine** for auto-grading
6. **Create recruiter dashboard** routes

---

## JWT Token Structure

Your tokens contain (no sensitive data):
```
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "jane@example.com",
  "role": "admin",
  "iat": 1713190200,
  "exp": 1713276600,
  "iss": "testgorilla",
  "aud": "testgorilla-users"
}
```

Decode tokens at [jwt.io](https://jwt.io) for debugging.

---

## Support for Other Modules

The authentication system is now fully integrated. You can build on it:

```javascript
// Example: Protected admin test creation
// routes/tests.js
const { adminOnly } = require('../middleware/authMiddleware');

router.post('/tests', adminOnly, async (req, res) => {
  const adminId = req.user.id; // From JWT token
  
  // Create test for this admin
  const test = await testService.createTest({
    ...req.body,
    created_by: adminId
  });
  
  res.json(test);
});
```

---

All files are production-ready. Start exploring! 🚀
