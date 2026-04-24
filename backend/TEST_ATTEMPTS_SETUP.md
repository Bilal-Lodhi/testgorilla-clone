# Test Attempts System - Setup & Testing Guide

Complete implementation for candidates to take tests with auto-grading for MCQ questions.

---

## 🔧 Setup Instructions

### 1. Run Migration
```bash
psql -U postgres -h localhost -p 5433 -d testgorilla -f migrations/004_create_attempts.sql
```

Creates:
- `test_attempts` table (tracks candidate test sessions)
- `question_responses` table (stores answers per question)
- Indexes and triggers for performance

### 2. Restart Server
```bash
npm run dev
```

---

## 📋 Database Schema

### test_attempts
```
id UUID PRIMARY KEY
test_id UUID NOT NULL (References tests)
user_id UUID NOT NULL (References users)
start_time TIMESTAMP (when candidate started)
end_time TIMESTAMP (when candidate submitted)
status VARCHAR (in_progress | submitted)
score INT (total marks obtained)
created_at TIMESTAMP
updated_at TIMESTAMP

UNIQUE constraint: (test_id, user_id) - one attempt per user per test
```

### question_responses
```
id UUID PRIMARY KEY
attempt_id UUID NOT NULL (References test_attempts)
question_id UUID NOT NULL (References questions)
selected_option_id UUID NULL (MCQ option selected)
code_answer TEXT NULL (Code submission)
is_correct BOOLEAN (auto-calculated for MCQ)
marks_obtained INT (auto-calculated for MCQ)
created_at TIMESTAMP
updated_at TIMESTAMP
```

---

## 🚀 API Endpoints

### 1. Start Test Attempt
```
POST /api/v1/tests/:testId/attempts
Authorization: Bearer <candidate_token>
```

**Request:**
```json
{} // No body required
```

**Response (201):**
```json
{
  "success": true,
  "message": "Test attempt started successfully",
  "data": {
    "attempt": {
      "id": "uuid",
      "test_id": "uuid",
      "user_id": "uuid",
      "start_time": "2026-04-16T10:00:00Z",
      "end_time": null,
      "status": "in_progress",
      "score": 0,
      "created_at": "2026-04-16T10:00:00Z",
      "updated_at": "2026-04-16T10:00:00Z"
    },
    "questions": [
      {
        "id": "uuid",
        "test_id": "uuid",
        "type": "mcq",
        "question_text": "What is 2 + 2?",
        "marks": 1,
        "order_index": 1,
        "options": [
          {"id": "uuid", "option_text": "3", "order_index": 0},
          {"id": "uuid", "option_text": "4", "order_index": 1},
          {"id": "uuid", "option_text": "5", "order_index": 2}
        ]
      },
      {
        "id": "uuid",
        "test_id": "uuid",
        "type": "coding",
        "question_text": "Write a function to add two numbers",
        "marks": 5,
        "order_index": 2,
        "options": []
      }
    ]
  }
}
```

**Validations:**
- ✅ Only candidates can start attempts
- ✅ Test must exist and be published
- ✅ Only one active attempt per user per test

**Error Response (409 Conflict):**
```json
{
  "success": false,
  "error": "You already have an active attempt for this test"
}
```

---

### 2. Get Attempt Details
```
GET /api/v1/attempts/:attemptId
Authorization: Bearer <candidate_token>
```

**Response (200):**
```json
{
  "success": true,
  "message": "Attempt retrieved successfully",
  "data": {
    "attempt": {
      "id": "uuid",
      "test_id": "uuid",
      "user_id": "uuid",
      "start_time": "2026-04-16T10:00:00Z",
      "end_time": null,
      "status": "in_progress",
      "score": 0,
      "responses": [
        {
          "id": "uuid",
          "attempt_id": "uuid",
          "question_id": "uuid",
          "selected_option_id": "uuid",
          "code_answer": null,
          "is_correct": true,
          "marks_obtained": 1,
          "created_at": "2026-04-16T10:05:00Z",
          "updated_at": "2026-04-16T10:05:00Z"
        }
      ]
    }
  }
}
```

---

### 3. Submit Answer to Question (MCQ or Coding)
```
POST /api/v1/attempts/:attemptId/responses
Authorization: Bearer <candidate_token>
Content-Type: application/json
```

**MCQ Answer Request:**
```json
{
  "questionId": "uuid",
  "selectedOptionId": "uuid"
}
```

**Coding Answer Request:**
```json
{
  "questionId": "uuid",
  "codeAnswer": "function add(a, b) { return a + b; }"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "Response submitted successfully",
  "data": {
    "response": {
      "id": "uuid",
      "attempt_id": "uuid",
      "question_id": "uuid",
      "selected_option_id": "uuid",
      "code_answer": null,
      "is_correct": true,
      "marks_obtained": 1,
      "created_at": "2026-04-16T10:05:00Z",
      "updated_at": "2026-04-16T10:05:00Z"
    }
  }
}
```

**Auto-Grading Rules:**
- **MCQ:** Automatically marked as correct if `selectedOptionId` matches the correct option
- **Coding:** Marked as pending (score: 0) - evaluated later by system
- Marks obtained = marks (question.marks) if correct, 0 if wrong
- Can be updated multiple times during attempt

---

### 4. Submit Entire Test (Final Submission)
```
POST /api/v1/attempts/:attemptId/submit
Authorization: Bearer <candidate_token>
```

**Request:**
```json
{} // No body required
```

**Response (200):**
```json
{
  "success": true,
  "message": "Test submitted successfully",
  "data": {
    "attempt": {
      "id": "uuid",
      "test_id": "uuid",
      "user_id": "uuid",
      "start_time": "2026-04-16T10:00:00Z",
      "end_time": "2026-04-16T10:30:00Z",
      "status": "submitted",
      "score": 6,
      "created_at": "2026-04-16T10:00:00Z",
      "updated_at": "2026-04-16T10:30:00Z"
    },
    "result": {
      "totalScore": 6,
      "totalMarks": 10,
      "percentage": 60,
      "passed": false,
      "passPercentage": 70
    }
  }
}
```

---

### 5. Get Candidate's All Attempts
```
GET /api/v1/candidates/attempts
Authorization: Bearer <candidate_token>
```

**Response (200):**
```json
{
  "success": true,
  "message": "Attempts retrieved successfully",
  "data": {
    "attempts": [
      {
        "id": "uuid",
        "test_id": "uuid",
        "user_id": "uuid",
        "start_time": "2026-04-16T10:00:00Z",
        "end_time": "2026-04-16T10:30:00Z",
        "status": "submitted",
        "score": 6,
        "created_at": "2026-04-16T10:00:00Z",
        "updated_at": "2026-04-16T10:30:00Z",
        "test_title": "JavaScript Basics",
        "duration_minutes": 30
      }
    ]
  }
}
```

---

### 6. Get All Attempts for Test (Admin Only)
```
GET /api/v1/tests/:testId/attempts
Authorization: Bearer <admin_token>
```

**Response (200):**
```json
{
  "success": true,
  "message": "Test attempts retrieved successfully",
  "data": {
    "attempts": [
      {
        "id": "uuid",
        "test_id": "uuid",
        "user_id": "uuid",
        "start_time": "2026-04-16T10:00:00Z",
        "end_time": "2026-04-16T10:30:00Z",
        "status": "submitted",
        "score": 6,
        "created_at": "2026-04-16T10:00:00Z",
        "updated_at": "2026-04-16T10:30:00Z",
        "user_name": "John Doe",
        "user_email": "john@example.com"
      }
    ]
  }
}
```

---

## 🧪 Testing with Insomnia

### Insomnia Environment Variables

```
base_url: http://localhost:5000
admin_token: (set after login)
candidate_token: (set after login)
test_id: (set after creating test)
attempt_id: (set after starting attempt)
question_id: (set after fetching questions)
option_id: (set after fetching options)
```

### Step-by-Step Testing Workflow

#### Step 1: Admin Login
```
POST {{base_url}}/api/v1/auth/login
Body:
{
  "email": "admin@example.com",
  "password": "Password123!"
}

Response: save access_token as {{admin_token}}
```

#### Step 2: Admin Creates Test
```
POST {{base_url}}/api/v1/tests
Auth: Bearer {{admin_token}}
Body:
{
  "title": "JavaScript Basics",
  "description": "Test your JS knowledge",
  "duration_minutes": 30,
  "pass_percentage": 70,
  "status": "draft"
}

Response: save test.id as {{test_id}}
```

#### Step 3: Admin Creates MCQ Question
```
POST {{base_url}}/api/v1/tests/{{test_id}}/questions
Auth: Bearer {{admin_token}}
Body:
{
  "type": "mcq",
  "question_text": "What is 2 + 2?",
  "marks": 1,
  "order_index": 1,
  "options": ["3", "4", "5", "6"],
  "correct_option": 1
}

Response: save question.id as {{question1_id}}
         save options[].id for later use
```

#### Step 4: Admin Creates Coding Question
```
POST {{base_url}}/api/v1/tests/{{test_id}}/questions
Auth: Bearer {{admin_token}}
Body:
{
  "type": "coding",
  "question_text": "Write a function to add two numbers",
  "marks": 5,
  "order_index": 2,
  "options": [],
  "correct_option": null
}

Response: save question.id as {{question2_id}}
```

#### Step 5: Admin Publishes Test
```
PATCH {{base_url}}/api/v1/tests/{{test_id}}/publish
Auth: Bearer {{admin_token}}
```

#### Step 6: Candidate Login
```
POST {{base_url}}/api/v1/auth/login
Body:
{
  "email": "candidate@example.com",
  "password": "Password123!"
}

Response: save access_token as {{candidate_token}}
```

#### Step 7: Candidate Starts Test Attempt
```
POST {{base_url}}/api/v1/tests/{{test_id}}/attempts
Auth: Bearer {{candidate_token}}

Response: save attempt.id as {{attempt_id}}
         Review all questions and options returned
```

#### Step 8: Candidate Submits MCQ Answer
```
POST {{base_url}}/api/v1/attempts/{{attempt_id}}/responses
Auth: Bearer {{candidate_token}}
Body:
{
  "questionId": "{{question1_id}}",
  "selectedOptionId": "{{option_id}}"
}

Response: Verify is_correct: true
         Verify marks_obtained: 1
```

#### Step 9: Candidate Submits Coding Answer
```
POST {{base_url}}/api/v1/attempts/{{attempt_id}}/responses
Auth: Bearer {{candidate_token}}
Body:
{
  "questionId": "{{question2_id}}",
  "codeAnswer": "function add(a, b) { return a + b; }"
}

Response: Verify marks_obtained: 0 (pending evaluation)
```

#### Step 10: Candidate Reviews Attempt
```
GET {{base_url}}/api/v1/attempts/{{attempt_id}}
Auth: Bearer {{candidate_token}}

Response: Review all responses submitted
```

#### Step 11: Candidate Submits Test
```
POST {{base_url}}/api/v1/attempts/{{attempt_id}}/submit
Auth: Bearer {{candidate_token}}

Response: Verify status: "submitted"
         Verify result.percentage and result.passed
```

#### Step 12: Admin Reviews Test Results
```
GET {{base_url}}/api/v1/tests/{{test_id}}/attempts
Auth: Bearer {{admin_token}}

Response: View all candidates' performance on this test
```

#### Step 13: Candidate Views All Attempts
```
GET {{base_url}}/api/v1/candidates/attempts
Auth: Bearer {{candidate_token}}

Response: View all tests they've attempted
```

---

## ✅ Access Control Matrix

| Endpoint | Admin | Candidate | Requirement |
|----------|-------|-----------|-------------|
| POST /tests/:testId/attempts | ❌ | ✅ | Test must be published |
| GET /attempts/:attemptId | ✅ | ✅ own | Candidate owns attempt |
| POST /attempts/:attemptId/responses | ❌ | ✅ own | Attempt in_progress |
| POST /attempts/:attemptId/submit | ❌ | ✅ own | Attempt in_progress |
| GET /candidates/attempts | ✅ any | ✅ own | View own/other attempts |
| GET /tests/:testId/attempts | ✅ own | ❌ | Admin created test |

---

## 🔒 Security & Validation Rules

### Attempt Creation
- ✅ Only candidates (role: 'candidate') can start attempts
- ✅ Admin role cannot take tests
- ✅ Unique constraint prevents multiple active attempts per user per test
- ✅ Test must be published before attempt
- ✅ Only returns questions for that specific test

### Answer Submission
- ✅ Attempt must exist and be in_progress
- ✅ Question must belong to the test
- ✅ Candidate can update answers multiple times
- ✅ MCQ auto-grades based on is_correct flag
- ✅ Coding answers stored, score = 0 until evaluation
- ✅ Invalid option ID fails gracefully

### Test Submission
- ✅ Attempt must be in_progress
- ✅ Sets end_time to current timestamp
- ✅ Calculates total score from all responses
- ✅ Calculates percentage: (totalScore / totalMarks) * 100
- ✅ Pass/fail determined by: percentage >= test.pass_percentage
- ✅ Status changed to 'submitted'

---

## 📊 Auto-Grading Logic

### MCQ Questions
```
IF selected_option_id matches correct option:
  is_correct = true
  marks_obtained = question.marks
ELSE:
  is_correct = false
  marks_obtained = 0
```

### Coding Questions
```
is_correct = false (pending manual/system evaluation)
marks_obtained = 0 (assigned during evaluation phase)
```

### Test Score Calculation
```
total_score = SUM(CASE WHEN type='mcq' THEN marks_obtained
                       WHEN type='coding' THEN marks_obtained
                       END)

total_marks = SUM(marks) for all questions

percentage = (total_score / total_marks) * 100

passed = percentage >= test.pass_percentage
```

---

## 🎯 Features Implemented

✅ **Full Test Attempt Lifecycle**
- Start attempt → Submit answers → Finalize submission

✅ **Auto-Grading for MCQ**
- Instant pass/fail on answer submission
- Marks calculated immediately

✅ **Coding Question Support**
- Code answer storage
- Marks pending evaluation (framework for later)

✅ **Time Tracking**
- start_time on attempt creation
- end_time on submission
- Duration validation on server

✅ **Multiple Attempt Prevention**
- UNIQUE constraint in database
- Middleware validation

✅ **Admin Dashboard**
- View all attempts per test
- See candidate performance
- Track pass/fail rates

✅ **Candidate Dashboard**
- View all personal attempts
- Track test scores and percentages
- Review submitted answers

---

## 🚀 Next Steps (Future Features)

1. **Coding Evaluation Engine**
   - Execute submitted code
   - Run test cases
   - Auto-score based on tests passing

2. **Anti-Cheat System**
   - Log suspicious events (tab switches, copy-paste)
   - Flag attempts for review

3. **Results Export**
   - CSV/PDF export of test results
   - Analytics and reporting

4. **Attempt Analytics**
   - Time spent per question
   - Question difficulty analysis
   - Candidate performance trends

---

All code is **production-ready** with proper error handling, validation, and security! 🚀
