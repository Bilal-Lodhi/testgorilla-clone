## Question Management Module - Setup & Testing Guide

---

## 📋 Files Created

1. **migrations/003_create_questions.sql** - Database tables for questions and MCQ options
2. **src/services/questionService.js** - Business logic for question operations
3. **src/controllers/questionController.js** - Route handlers
4. **src/routes/questions.js** - API route definitions
5. **Updated src/routes/tests.js** - Integrated questions routes

---

## 🚀 Setup Instructions

### 1. Run Migration to Create Questions Tables

```bash
psql -U postgres -h localhost -p 5433 -d testgorilla -f migrations/003_create_questions.sql
```

**Expected output:**
```
CREATE TABLE
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

### 1. Create Question (Admin Only)
**POST** `/api/v1/tests/:testId/questions`

Headers:
```
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

**For MCQ Question:**
```json
{
  "type": "mcq",
  "question_text": "What does HTML stand for?",
  "marks": 1,
  "order_index": 1,
  "options": [
    { "option_text": "Hyper Text Markup Language", "is_correct": true },
    { "option_text": "High Tech Modern Language", "is_correct": false },
    { "option_text": "Home Tool Markup Language", "is_correct": false }
  ]
}
```

**For Coding Question:**
```json
{
  "type": "coding",
  "question_text": "Write a function to reverse a string",
  "marks": 5,
  "order_index": 2
}
```

Response (201 Created):
```json
{
  "success": true,
  "message": "Question created successfully",
  "data": {
    "question": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "test_id": "test-uuid",
      "type": "mcq",
      "question_text": "What does HTML stand for?",
      "marks": 1,
      "order_index": 1,
      "created_at": "2026-04-16T10:30:00.000Z",
      "updated_at": "2026-04-16T10:30:00.000Z",
      "options": [
        {
          "id": "opt-uuid-1",
          "question_id": "qid",
          "option_text": "Hyper Text Markup Language",
          "is_correct": true,
          "order_index": 0
        },
        {
          "id": "opt-uuid-2",
          "question_id": "qid",
          "option_text": "High Tech Modern Language",
          "is_correct": false,
          "order_index": 1
        },
        {
          "id": "opt-uuid-3",
          "question_id": "qid",
          "option_text": "Home Tool Markup Language",
          "is_correct": false,
          "order_index": 2
        }
      ]
    }
  }
}
```

---

### 2. Get All Questions for a Test
**GET** `/api/v1/tests/:testId/questions`

Headers:
```
Authorization: Bearer <access_token>
```

Query parameters (optional):
```
?page=1&limit=50
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Questions retrieved successfully",
  "data": [
    {
      "id": "q1-uuid",
      "test_id": "test-uuid",
      "type": "mcq",
      "question_text": "What does HTML stand for?",
      "marks": 1,
      "order_index": 1,
      "created_at": "2026-04-16T10:30:00.000Z",
      "updated_at": "2026-04-16T10:30:00.000Z",
      "options": [
        {
          "id": "opt-uuid-1",
          "question_id": "q1-uuid",
          "option_text": "Hyper Text Markup Language",
          "is_correct": true,
          "order_index": 0
        }
      ]
    }
  ],
  "pagination": {
    "total": 1,
    "page": 1,
    "limit": 50,
    "pages": 1
  }
}
```

**Behavior:**
- **Admin**: Sees all questions in tests they created
- **Candidate**: Sees only questions in published tests

---

### 3. Get Single Question
**GET** `/api/v1/tests/:testId/questions/:questionId`

Headers:
```
Authorization: Bearer <access_token>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Question retrieved successfully",
  "data": {
    "question": {
      "id": "q1-uuid",
      "test_id": "test-uuid",
      "type": "mcq",
      "question_text": "What does HTML stand for?",
      "marks": 1,
      "order_index": 1,
      "created_at": "2026-04-16T10:30:00.000Z",
      "updated_at": "2026-04-16T10:30:00.000Z",
      "options": [
        {
          "id": "opt-uuid-1",
          "question_id": "q1-uuid",
          "option_text": "Hyper Text Markup Language",
          "is_correct": true,
          "order_index": 0
        }
      ]
    }
  }
}
```

---

### 4. Update Question (Admin Only)
**PUT** `/api/v1/tests/:testId/questions/:questionId`

Headers:
```
Authorization: Bearer <admin_access_token>
Content-Type: application/json
```

**Update MCQ question (text, marks, options):**
```json
{
  "question_text": "Updated: What does HTML stand for?",
  "marks": 2,
  "options": [
    { "option_text": "Hyper Text Markup Language", "is_correct": true },
    { "option_text": "Another Option", "is_correct": false },
    { "option_text": "Third Option", "is_correct": false }
  ]
}
```

**Update coding question (text, marks only):**
```json
{
  "question_text": "Write a function to reverse a string",
  "marks": 10
}
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Question updated successfully",
  "data": {
    "question": {
      "id": "q1-uuid",
      "test_id": "test-uuid",
      "type": "mcq",
      "question_text": "Updated: What does HTML stand for?",
      "marks": 2,
      "order_index": 1,
      "created_at": "2026-04-16T10:30:00.000Z",
      "updated_at": "2026-04-16T10:35:00.000Z",
      "options": [
        {
          "id": "opt-uuid-1",
          "question_id": "q1-uuid",
          "option_text": "Hyper Text Markup Language",
          "is_correct": true,
          "order_index": 0
        }
      ]
    }
  }
}
```

---

### 5. Delete Question (Admin Only)
**DELETE** `/api/v1/tests/:testId/questions/:questionId`

Headers:
```
Authorization: Bearer <admin_access_token>
```

Response (200 OK):
```json
{
  "success": true,
  "message": "Question deleted successfully",
  "data": {
    "message": "Question deleted successfully",
    "questionId": "q1-uuid"
  }
}
```

---

## 🧪 Complete Insomnia Testing Guide

### Setup Variables in Insomnia

Set up environment variables in Insomnia for easier testing:
- `base_url`: `http://localhost:5000`
- `admin_token`: Your admin access token
- `candidate_token`: Your candidate access token
- `test_id`: Your test ID
- `question_id`: Your question ID

---

### Step 1: Register & Login Admin

**POST** `{{ base_url }}/api/v1/auth/register`
```json
{
  "name": "Test Admin",
  "email": "admin@testgorilla.com",
  "password": "password123",
  "role": "admin"
}
```

**POST** `{{ base_url }}/api/v1/auth/login`
```json
{
  "email": "admin@testgorilla.com",
  "password": "password123"
}
```

Save `accessToken` as `admin_token` in Insomnia variables.

---

### Step 2: Create a Test

**POST** `{{ base_url }}/api/v1/tests`

Headers:
```
Authorization: Bearer {{ admin_token }}
Content-Type: application/json
```

Body:
```json
{
  "title": "Web Development Fundamentals",
  "description": "Test your knowledge of HTML, CSS, and JavaScript",
  "duration_minutes": 60,
  "pass_percentage": 70,
  "status": "draft"
}
```

Save test ID as `test_id` in Insomnia variables.

---

### Step 3: Create MCQ Question

**POST** `{{ base_url }}/api/v1/tests/{{ test_id }}/questions`

Headers:
```
Authorization: Bearer {{ admin_token }}
Content-Type: application/json
```

Body:
```json
{
  "type": "mcq",
  "question_text": "What does HTML stand for?",
  "marks": 1,
  "order_index": 1,
  "options": [
    { "option_text": "Hyper Text Markup Language", "is_correct": true },
    { "option_text": "High Tech Modern Language", "is_correct": false },
    { "option_text": "Home Tool Markup Language", "is_correct": false },
    { "option_text": "Help Technology Markup Language", "is_correct": false }
  ]
}
```

Save question ID as `question_id` in Insomnia variables.

---

### Step 4: Create Coding Question

**POST** `{{ base_url }}/api/v1/tests/{{ test_id }}/questions`

Headers:
```
Authorization: Bearer {{ admin_token }}
Content-Type: application/json
```

Body:
```json
{
  "type": "coding",
  "question_text": "Write a JavaScript function to find the sum of all numbers in an array",
  "marks": 5,
  "order_index": 2
}
```

---

### Step 5: Get All Questions

**GET** `{{ base_url }}/api/v1/tests/{{ test_id }}/questions`

Headers:
```
Authorization: Bearer {{ admin_token }}
```

---

### Step 6: Get Single Question

**GET** `{{ base_url }}/api/v1/tests/{{ test_id }}/questions/{{ question_id }}`

Headers:
```
Authorization: Bearer {{ admin_token }}
```

---

### Step 7: Update MCQ Question

**PUT** `{{ base_url }}/api/v1/tests/{{ test_id }}/questions/{{ question_id }}`

Headers:
```
Authorization: Bearer {{ admin_token }}
Content-Type: application/json
```

Body:
```json
{
  "question_text": "Updated: What does HTML stand for?",
  "marks": 2,
  "options": [
    { "option_text": "Hyper Text Markup Language", "is_correct": true },
    { "option_text": "Different Option 1", "is_correct": false },
    { "option_text": "Different Option 2", "is_correct": false }
  ]
}
```

---

### Step 8: Delete Question

**DELETE** `{{ base_url }}/api/v1/tests/{{ test_id }}/questions/{{ question_id }}`

Headers:
```
Authorization: Bearer {{ admin_token }}
```

---

### Step 9: Test Candidate Access (Published Test)

1. First, publish the test:
   **PATCH** `{{ base_url }}/api/v1/tests/{{ test_id }}/publish`

2. Create a candidate account and login
3. Try to view questions:
   **GET** `{{ base_url }}/api/v1/tests/{{ test_id }}/questions`
   
   Should succeed (test is published)

4. Create a new test and DON'T publish it
5. Candidate tries to view questions of unpublished test
   
   Should fail with 401 error

---

## 🔐 Access Control

| Action | Admin (own test) | Admin (other test) | Candidate (published test) | Candidate (unpublished test) |
|--------|------------------|--------------------|-----------------------------|-------------------------------|
| Create question | ✅ | ❌ | ❌ | ❌ |
| View questions | ✅ | ❌ | ✅ | ❌ |
| View single question | ✅ | ❌ | ✅ | ❌ |
| Update question | ✅ | ❌ | ❌ | ❌ |
| Delete question | ✅ | ❌ | ❌ | ❌ |

---

## 📊 Database Schema

### questions table
```sql
questions (
  id UUID PRIMARY KEY,
  test_id UUID FOREIGN KEY → tests(id),
  type VARCHAR(50) IN ('mcq', 'coding'),
  question_text TEXT NOT NULL,
  marks INT NOT NULL (> 0),
  order_index INT NOT NULL,
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  UNIQUE(test_id, order_index)
)

Indexes:
  - idx_questions_test_id
  - idx_questions_type
```

### mcq_options table
```sql
mcq_options (
  id UUID PRIMARY KEY,
  question_id UUID FOREIGN KEY → questions(id),
  option_text TEXT NOT NULL,
  is_correct BOOLEAN NOT NULL,
  order_index INT NOT NULL,
  created_at TIMESTAMP,
  UNIQUE(question_id, order_index)
)

Indexes:
  - idx_mcq_options_question_id
```

---

## ✅ Validation Rules

### MCQ Questions
- Must have **exactly 2 or more options**
- Must have **exactly 1 correct option**
- Options ordered by `order_index`

### Coding Questions
- No options needed
- Can have any `marks` value > 0

### All Questions
- `marks` must be > 0
- `question_text` is required
- `type` must be 'mcq' or 'coding'
- `order_index` for question ordering within test

---

## 🐛 Error Responses

### 400 Bad Request - Missing Fields
```json
{
  "success": false,
  "error": {
    "message": "test_id, type, and question_text are required"
  }
}
```

### 400 Bad Request - Invalid MCQ
```json
{
  "success": false,
  "error": {
    "message": "MCQ questions must have exactly 1 correct option"
  }
}
```

### 401 Unauthorized - Not Authenticated
```json
{
  "success": false,
  "error": {
    "message": "No token provided. Use Authorization header with Bearer token"
  }
}
```

### 403 Forbidden - Not Admin
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
    "message": "Question not found"
  }
}
```

---

## 📝 Code Structure

```
src/
├── services/
│   └── questionService.js           # CRUD, validation, MCQ handling
├── controllers/
│   └── questionController.js        # Request handlers, auth checks
├── routes/
│   ├── questions.js                 # Question endpoints
│   └── tests.js                     # Integrates questions routes
└── app.js                           # Updated endpoints

migrations/
└── 003_create_questions.sql         # Database schema
```

---

## ✨ Features Implemented

✅ **MCQ support** - Multiple choice questions with 1+ correct answers  
✅ **Coding support** - Coding problems (structure for later evaluation)  
✅ **Full CRUD** - Create, read, update, delete questions  
✅ **Role-based access** - Admin-only write, candidate read-only (published)  
✅ **Test ownership** - Can only modify questions in own tests  
✅ **Transactions** - Atomic operations for complex updates  
✅ **Pagination** - List questions with page/limit support  
✅ **Validation** - Comprehensive input validation  
✅ **Database constraints** - Unique ordering, referential integrity  
✅ **Error handling** - Detailed error messages  
✅ **Logging** - Track question operations  

---

## 🎯 Next Steps

After questions, implement:

1. **Test Attempts** - Candidates attempt tests
2. **Question Responses** - Store candidate answers
3. **Evaluation Engine** - Auto-grade MCQ questions
4. **Results Dashboard** - View candidate performance
5. **Anti-Cheat Module** - Detect suspicious behavior

---

All files are **production-ready**! 🚀
