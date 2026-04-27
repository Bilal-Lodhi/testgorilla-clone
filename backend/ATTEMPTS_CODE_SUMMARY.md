# Test Attempts System - Complete Code Files

All working code for the test attempt feature (candidates taking tests).

---

## 📁 Files Created

### 1. migrations/004_create_attempts.sql
**Purpose:** Database tables and indexes for test attempts and question responses
**Key Objects:**
- test_attempts table (candidate test sessions)
- question_responses table (stored answers)
- Indexes on test_id, user_id, attempt_id, question_id
- Triggers for updated_at timestamps
- UNIQUE constraint (test_id, user_id) to prevent duplicate attempts

---

### 2. src/services/attemptService.js
**Purpose:** Business logic for all attempt operations
**Functions:**
1. `startAttempt(testId, userId)` - Create attempt, fetch all questions + options
2. `getAttempt(attemptId)` - Retrieve attempt with all responses
3. `submitResponse(attemptId, questionId, selectedOptionId, codeAnswer)` - Submit answer, auto-grade MCQ
4. `submitAttempt(attemptId)` - Finalize test, calculate score + percentage
5. `getUserAttempts(userId)` - Get all attempts by candidate
6. `getTestAttempts(testId)` - Get all attempts for a test (admin)

**Key Features:**
- Transaction support for data consistency
- Auto-grading for MCQ (compare selectedOptionId with is_correct)
- Percentage calculation: (totalScore / totalMarks) * 100
- Pass determination: percentage >= test.pass_percentage
- Error handling for duplicate attempts, duration exceeded, etc.

---

### 3. src/controllers/attemptController.js
**Purpose:** HTTP request handling for attempt endpoints
**Handlers:**
1. `startAttempt` - POST /tests/:testId/attempts
   - Validates candidate role
   - Checks test is published
   - Prevents multiple active attempts
   
2. `getAttempt` - GET /attempts/:attemptId
   - Verifies user owns attempt (candidate) or is admin
   - Returns attempt with all responses
   
3. `submitResponse` - POST /attempts/:attemptId/responses
   - Validates attempt in_progress
   - Validates question belongs to test
   - Saves/updates response
   
4. `submitAttempt` - POST /attempts/:attemptId/submit
   - Validates attempt in_progress
   - Calculates final score
   - Determines pass/fail status
   
5. `getCandidateAttempts` - GET /candidates/attempts
   - Returns all attempts by candidate
   - Admin can view other users if userId in query
   
6. `getTestAttempts` - GET /tests/:testId/attempts
   - Admin only (test creator)
   - Shows all candidates' attempts on test

---

### 4. src/routes/attempts.js
**Purpose:** API route definitions for all attempt endpoints
**Routes:**
- POST / → `startAttempt` (when mounted at /tests/:testId/attempts)
- GET /:attemptId → `getAttempt`
- POST /:attemptId/responses → `submitResponse`
- POST /:attemptId/submit → `submitAttempt`
- GET / → `getCandidateAttempts` (when mounted at /candidates/attempts)

**Key Settings:**
- `mergeParams: true` - Inherits parent route params
- Middleware: `authenticateToken`, `candidateOnly`, `adminOnly`
- `checkActiveAttempt` - Validates attempt state and duration
- `preventMultipleAttempts` - Prevents duplicate attempts

---

### 5. src/middleware/attemptMiddleware.js
**Purpose:** Middleware for attempt validation and duration checking
**Functions:**
1. `checkActiveAttempt` - Verify attempt in_progress, check time limit
   - Attaches req.attempt with timeRemaining and elapsedTime
   - Fails if duration exceeded
   
2. `preventMultipleAttempts` - Prevent multiple active attempts per user per test
   - Checks for existing in_progress attempt
   - Returns 409 Conflict if one exists

---

## 📝 Files Modified

### src/app.js
**Changes:**
1. Added: `const attemptRoutes = require('./routes/attempts');`
2. Mounted routes:
   - `app.use('/api/v1/tests/:testId/attempts', attemptRoutes);`
   - `app.use('/api/v1/attempts', attemptRoutes);`
   - `app.use('/api/v1/candidates/attempts', attemptRoutes);`
3. Updated welcome endpoint with attempt endpoints documentation

---

### src/routes/tests.js
**Changes:**
1. Added: `const attemptController = require('../controllers/attemptController');`
2. Added route: `GET /:id/attempts` → `attemptController.getTestAttempts` (admin only)
   - Maps to endpoint: GET /api/v1/tests/:testId/attempts

---

## 🔗 Integration Points

### With Authentication (auth.js, authMiddleware.js)
- Uses `authenticateToken` middleware on all endpoints
- Validates user roles: admin, candidate
- Uses `candidateOnly` for attempt endpoints

### With Tests (tests.js, testService.js)
- Validates test exists via `testService.getTestById()`
- Checks test is published before allowing attempt
- Verifies admin ownership for test results view

### With Questions (questions.js, questionService.js)
- Fetches all questions for a test
- Returns MCQ options with is_correct flag for auto-grading
- Validates question belongs to test
- Supports both MCQ and Coding question types

### With Database (config/db.js)
- Uses connection pool with transactions
- Queries test_attempts, question_responses tables
- Validates referential integrity

---

## 📊 Endpoint Summary

| Method | Path | Auth | Role | Purpose |
|--------|------|------|------|---------|
| POST | /tests/:testId/attempts | ✅ | candidate | Start attempt |
| GET | /attempts/:attemptId | ✅ | any | Get attempt details |
| POST | /attempts/:attemptId/responses | ✅ | candidate | Submit answer |
| POST | /attempts/:attemptId/submit | ✅ | candidate | Submit test |
| GET | /candidates/attempts | ✅ | any | List candidate attempts |
| GET | /tests/:testId/attempts | ✅ | admin | List test attempts |

---

## 🎯 Key Features

✅ **Candidate Test Taking**
- Start test with all questions visible
- Submit answers per question or all at once
- Update answers multiple times

✅ **Auto-Grading for MCQ**
- Instant pass/fail on submission
- Marks calculated immediately
- is_correct flag determines response

✅ **Coding Support**
- Store code submissions
- Marks pending evaluation (framework ready)

✅ **Time Tracking**
- Measure attempt duration
- Enforce test duration limits
- Track start_time and end_time

✅ **Score Calculation**
- Sum all marks_obtained
- Calculate percentage
- Determine pass/fail

✅ **Multiple Prevention**
- UNIQUE constraint in database
- Middleware validation
- Error on duplicate attempt

✅ **Admin Dashboard**
- View all attempts per test
- See candidate scores and progress
- Export functionality (next phase)

---

## 🔒 Access Control

**Candidates Can:**
- ✅ Start published tests
- ✅ Submit answers to own attempts
- ✅ View own attempt details
- ✅ View own attempt history

**Admins Can:**
- ✅ View all attempts for their tests
- ✅ See candidate performance
- ✅ Cannot take tests themselves

**Public (No Auth):**
- ❌ Cannot access any attempt endpoints

---

## 💾 Database Transactions

All multi-step operations use transactions:
- Start attempt (create attempt + fetch questions)
- Submit response (validate + insert/update + calculate)
- Submit test (finalize + calculate score)

If any step fails, entire transaction rolls back ensuring data consistency.

---

## ⚡ Performance Optimizations

✅ **Indexes Created:**
- idx_test_attempts_test_id
- idx_test_attempts_user_id
- idx_test_attempts_status
- idx_question_responses_attempt_id
- idx_question_responses_question_id

✅ **Query Optimization:**
- Single query to fetch all questions with options
- Use SUM() for score calculation in database
- Index on status for quick in_progress lookup

✅ **Connection Pooling:**
- Min 2, Max 10 connections
- Reuse connections across requests

---

## 🚀 Deployment Checklist

- [x] Run migration 004
- [x] Restart npm run dev
- [x] Test all 6 endpoints
- [x] Verify access controls
- [x] Test auto-grading MCQ
- [x] Verify attempt duration tracking
- [x] Check duplicate attempt prevention
- [x] Validate score calculation

Ready for production! 🎉
