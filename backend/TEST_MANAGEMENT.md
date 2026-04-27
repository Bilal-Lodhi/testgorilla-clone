## Test Management Module - Setup & Testing Guide

---

## 📋 Files Created

1. **migrations/002_create_tests_table.sql** - Database table for tests
2. **src/services/testService.js** - Business logic (CRUD operations)
3. **src/controllers/testController.js** - Route handlers
4. **src/routes/tests.js** - API route definitions
5. **Updated src/app.js** - Integrated test routes

---

## 🚀 Setup Instructions

### 1. Run Migration to Create Tests Table

```bash
psql -U postgres -h localhost -p 5433 -d testgorilla -f migrations/002_create_tests_table.sql
```

**Expected output:**
```
CREATE TABLE
CREATE INDEX
CREATE INDEX
CREATE INDEX
CREATE OR REPLACE FUNCTION
DROP TRIGGER
CREATE TRIGGER
```

### 2. Start the Server

```bash
npm run dev
```

You should see:
```
[INFO] Database connection successful
[INFO] Server started successfully
```

---

## 📡 API Endpoints

### 1. Create Test (Admin Only)
**POST** `/api/v1/tests`

Headers:
```
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Request body:
```json
{
  "title": "JavaScript Fundamentals",
  "description": "Test basic JS concepts",
  "duration_minutes": 30,
  "pass_percentage": 70,
  "status": "draft"
}
```

Response (201 Created):
```json
{
  "success": true,
  "message": "Test created successfully",
  "data": {
    "test": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "JavaScript Fundamentals",
      "description": "Test basic JS concepts",
      "duration_minutes": 30,
      "created_by": "admin-uuid-here",
      "status": "draft",
      "pass_percentage": 70,
      "total_questions": 0,
      "created_at": "2026-04-16T10:30:00.000Z",
      "updated_at": "2026-04-16T10:30:00.000Z"
    }
  }
}
```

---

### 2. Get All Tests
**GET** `/api/v1/tests`

Headers:
```
Authorization: Bearer <access_token>
```

Query parameters (optional):
```
?page=1&limit=10&status=published
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Tests retrieved successfully",
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "JavaScript Fundamentals",
      "description": "Test basic JS concepts",
      "duration_minutes": 30,
      "created_by": "admin-uuid",
      "created_by_name": "John Doe",
      "status": "draft",
      "pass_percentage": 70,
      "total_questions": 0,
      "created_at": "2026-04-16T10:30:00.000Z",
      "updated_at": "2026-04-16T10:30:00.000Z"
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "limit": 10,
    "pages": 1
  }
}
```

**Behavior:**
- **Admin**: Sees all tests they created
- **Candidate**: Sees only published tests

---

### 3. Get Single Test
**GET** `/api/v1/tests/:id`

Headers:
```
Authorization: Bearer <access_token>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Test retrieved successfully",
  "data": {
    "test": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "JavaScript Fundamentals",
      "description": "Test basic JS concepts",
      "duration_minutes": 30,
      "created_by": "admin-uuid",
      "created_by_name": "John Doe",
      "status": "draft",
      "pass_percentage": 70,
      "total_questions": 0,
      "created_at": "2026-04-16T10:30:00.000Z",
      "updated_at": "2026-04-16T10:30:00.000Z"
    }
  }
}
```

**Restrictions:**
- Candidates can only view published tests

---

### 4. Update Test (Admin Only)
**PUT** `/api/v1/tests/:id`

Headers:
```
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

Request body (update any of these):
```json
{
  "title": "Updated Test Title",
  "description": "Updated description",
  "duration_minutes": 45,
  "pass_percentage": 75,
  "status": "published"
}
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Test updated successfully",
  "data": {
    "test": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Updated Test Title",
      "duration_minutes": 45,
      "status": "published",
      "updated_at": "2026-04-16T10:35:00.000Z"
    }
  }
}
```

---

### 5. Delete Test (Admin Only)
**DELETE** `/api/v1/tests/:id`

Headers:
```
Authorization: Bearer <admin_access_token>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Test deleted successfully",
  "data": {
    "message": "Test deleted successfully",
    "testId": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

---

### 6. Publish Test (Admin Only)
**PATCH** `/api/v1/tests/:id/publish`

Headers:
```
Authorization: Bearer <admin_access_token>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Test published successfully",
  "data": {
    "test": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "published",
      "updated_at": "2026-04-16T10:35:00.000Z"
    }
  }
}
```

---

### 7. Archive Test (Admin Only)
**PATCH** `/api/v1/tests/:id/archive`

Headers:
```
Authorization: Bearer <admin_access_token>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Test archived successfully",
  "data": {
    "test": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "archived",
      "updated_at": "2026-04-16T10:35:00.000Z"
    }
  }
}
```

---

## 🧪 Complete cURL Testing Examples

### Step 1: Register Admin User

```bash
curl -X POST http://localhost:5000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Admin User",
    "email": "admin@example.com",
    "password": "password123",
    "role": "admin"
  }'
```

Save the user ID from response.

### Step 2: Login as Admin

```bash
curl -X POST http://localhost:5000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "password123"
  }'
```

Save the `accessToken`.

### Step 3: Create a Test

```bash
curl -X POST http://localhost:5000/api/v1/tests \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "title": "React Fundamentals",
    "description": "Test your React knowledge",
    "duration_minutes": 45,
    "pass_percentage": 60,
    "status": "draft"
  }'
```

Save the test `id` from response.

### Step 4: Get All Tests

```bash
curl -X GET "http://localhost:5000/api/v1/tests?page=1&limit=10" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Step 5: Get Single Test

```bash
curl -X GET http://localhost:5000/api/v1/tests/TEST_ID \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Step 6: Update Test

```bash
curl -X PUT http://localhost:5000/api/v1/tests/TEST_ID \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -d '{
    "title": "Advanced React Fundamentals",
    "duration_minutes": 60,
    "pass_percentage": 70
  }'
```

### Step 7: Publish Test

```bash
curl -X PATCH http://localhost:5000/api/v1/tests/TEST_ID/publish \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Step 8: Archive Test

```bash
curl -X PATCH http://localhost:5000/api/v1/tests/TEST_ID/archive \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Step 9: Delete Test

```bash
curl -X DELETE http://localhost:5000/api/v1/tests/TEST_ID \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

---

## 🔐 Access Control

| Action | Admin | Candidate |
|--------|-------|-----------|
| Create test | ✅ Own | ❌ |
| View all tests | ✅ Own only | ✅ Published only |
| View single test | ✅ Any | ✅ Published only |
| Update test | ✅ Own | ❌ |
| Delete test | ✅ Own | ❌ |
| Publish test | ✅ Own | ❌ |
| Archive test | ✅ Own | ❌ |

---

## 📊 Database Schema

```sql
tests (
  id UUID PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  duration_minutes INT NOT NULL (> 0),
  created_by UUID FOREIGN KEY (users.id),
  status VARCHAR(50) CHECK ('draft' | 'published' | 'archived'),
  pass_percentage DECIMAL(5,2) DEFAULT 60.00,
  total_questions INT DEFAULT 0,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)

Indexes:
- idx_tests_created_by    -- Fast lookup by creator
- idx_tests_status         -- Fast filtering by status
- idx_tests_created_at    -- Fast sorting by date
```

---

## 🐛 Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "error": {
    "message": "Duration must be greater than 0"
  }
}
```

### 401 Unauthorized
```json
{
  "success": false,
  "error": {
    "message": "No token provided. Use Authorization header with Bearer token"
  }
}
```

### 403 Forbidden
```json
{
  "success": false,
  "error": {
    "message": "Access denied. Required role(s): admin"
  }
}
```

### 404 Not Found
```json
{
  "success": false,
  "error": {
    "message": "Test not found"
  }
}
```

---

## 📝 Code Structure

```
src/
├── services/
│   └── testService.js           # Business logic (CRUD, search, filtering)
├── controllers/
│   └── testController.js        # Request handlers (validation, response)
├── routes/
│   └── tests.js                 # Route definitions (endpoints)
├── middleware/
│   └── authMiddleware.js        # authenticateToken, adminOnly
└── app.js                       # Route mounting

migrations/
└── 002_create_tests_table.sql   # Database schema
```

---

## 🔄 Workflow Example

**Admin creates and publishes a test:**

1. Admin registers/logs in → gets `accessToken`
2. Admin creates test (status = 'draft') via `POST /api/v1/tests`
3. Admin updates test (add questions, etc.) via `PUT /api/v1/tests/:id`
4. Admin publishes test via `PATCH /api/v1/tests/:id/publish`
5. Test now visible to candidates in `GET /api/v1/tests` (status = published)
6. Candidates can view test details via `GET /api/v1/tests/:id`

**Candidates can only view published tests:**

1. Candidate logs in → gets `accessToken`
2. Candidate calls `GET /api/v1/tests` → sees only published tests
3. Candidate calls `GET /api/v1/tests/:id` → sees test IF status = 'published'
4. Cannot access draft/archived tests

---

## ✅ Feature Checklist

✅ Create tests (admin only)  
✅ Read tests (admin: own, candidate: published)  
✅ Update tests (admin only, own tests)  
✅ Delete tests (admin only, own tests)  
✅ Publish tests (status change to published)  
✅ Archive tests (status change to archived)  
✅ Pagination support  
✅ Role-based access control  
✅ Test ownership verification  
✅ Proper error handling  
✅ Database indexes for performance  

---

## 🎯 Next Steps

After test management, implement:

1. **Questions Module** - Add MCQ/coding questions to tests
2. **Test Attempts** - Candidates attempt tests
3. **Evaluation Engine** - Auto-grade MCQ and coding questions
4. **Results Dashboard** - View candidate results
5. **Anti-Cheat Module** - Detect suspicious behavior

---

All files are **production-ready**! 🚀
