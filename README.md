# TestGorilla - Online Testing & Assessment Platform

A production-ready, full-stack assessment platform built with **Express.js + PostgreSQL** (backend) and **Flutter** (mobile & web frontend). Designed for recruiters and educators to create, publish, and manage online tests with real-time candidate feedback.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
  - [Backend Setup](#backend-setup)
  - [Frontend Setup](#frontend-setup)
- [API Documentation](#api-documentation)
- [Features](#features)
- [Architecture & Design](#architecture--design)
- [Development Guide](#development-guide)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)

---

## 📌 Overview

TestGorilla is an enterprise-grade assessment platform that enables organizations to:

- **Create & Manage Tests**: Build assessments with multiple question types (MCQ, coding, essays)
- **Live Testing**: Candidates take tests in real-time with timer, anti-cheating detection, and response validation
- **Dual-Role Support**: Admin panels for test creation/management, candidate interfaces for test taking
- **Real-time Results**: Instant feedback for MCQ, manual review workflows for subjective questions
- **Cross-Platform**: Works on iOS, Android, Web, and Desktop (built with Flutter)

**Current Status**: Production-ready backend with full Flutter frontend support

---

## 🛠 Tech Stack

### Backend

| Component | Technology | Version |
|-----------|-----------|---------|
| **Runtime** | Node.js | 16+ LTS |
| **Framework** | Express.js | 4.22.1 |
| **Database** | PostgreSQL | 12+ |
| **Authentication** | JWT (jsonwebtoken) | 9.0.3 |
| **Security** | bcryptjs | 2.4.3 |
| **CORS** | cors | 2.8.6 |
| **Development** | Nodemon | 3.1.14 |

### Frontend

| Component | Technology | Version |
|-----------|-----------|---------|
| **Framework** | Flutter | 3.9.2+ |
| **UI Framework** | Material 3 | Latest |
| **State Management** | Provider | 6.0.0 |
| **HTTP Client** | http | 1.1.0 |
| **Storage** | shared_preferences | 2.0.0 |
| **Audio** | audioplayers | 5.2.1 |
| **Ringtone** | flutter_ringtone_player | 4.0.0+4 |
| **Icons** | cupertino_icons | 1.0.8 |

---

## 📁 Project Structure

```
test-gorilla/
├── backend/                          # Node.js/Express backend
│   ├── src/
│   │   ├── app.js                   # Express app setup & middleware
│   │   ├── server.js                # Entry point & server startup
│   │   ├── config/
│   │   │   └── db.js                # PostgreSQL pool configuration
│   │   ├── routes/
│   │   │   ├── auth.js              # Authentication endpoints
│   │   │   ├── tests.js             # Test CRUD & management
│   │   │   ├── questions.js         # Question management
│   │   │   ├── attempts.js          # Test attempt & response tracking
│   │   │   ├── results.js           # Test results & evaluation
│   │   │   └── health.js            # Health check endpoint
│   │   ├── controllers/             # Business logic handlers
│   │   │   ├── authController.js
│   │   │   ├── testController.js
│   │   │   ├── questionController.js
│   │   │   ├── attemptController.js
│   │   │   └── resultController.js
│   │   ├── services/                # Database & business services
│   │   │   ├── authService.js
│   │   │   ├── testService.js
│   │   │   ├── questionService.js
│   │   │   ├── attemptService.js
│   │   │   ├── evaluationService.js
│   │   │   └── tokenService.js
│   │   ├── middleware/
│   │   │   ├── authMiddleware.js    # JWT validation & role checks
│   │   │   ├── attemptMiddleware.js # Attempt-specific checks
│   │   │   ├── cors.js              # CORS configuration
│   │   │   ├── errorHandler.js      # Global error handling
│   │   │   └── requestLogger.js     # Request logging
│   │   └── utils/
│   │       ├── logger.js            # Structured logging
│   │       ├── jwt.js               # JWT utilities
│   │       └── constants.js         # App constants & enums
│   ├── migrations/                  # Database migrations (SQL)
│   │   ├── 001_create_users_table.sql
│   │   ├── 002_create_tests_table.sql
│   │   ├── 003_create_questions.sql
│   │   ├── 004_create_attempts.sql
│   │   ├── 005_create_results.sql
│   │   ├── 006_add_manual_review_support.sql
│   │   └── 007_create_verification_tokens.sql
│   ├── package.json                 # npm dependencies & scripts
│   ├── .env.example                 # Environment variables template
│   └── seed_users.js                # Database seeding script
│
├── frontend/                        # Flutter cross-platform app
│   └── test_gorilla/
│       ├── lib/
│       │   ├── main.dart            # App entry point & providers
│       │   ├── core/
│       │   │   ├── api/
│       │   │   │   └── api_client.dart       # HTTP client & API wrapper
│       │   │   ├── config/
│       │   │   │   └── app_config.dart       # App configuration
│       │   │   ├── theme/
│       │   │   │   └── app_theme.dart        # Material 3 theme
│       │   │   ├── utils/
│       │   │   │   ├── jwt_storage.dart      # JWT token storage
│       │   │   │   ├── tenseconds.mp3        # Timer audio
│       │   │   │   └── constants.dart
│       │   │   └── services/
│       │   ├── features/
│       │   │   ├── auth/
│       │   │   │   ├── auth_provider.dart    # Auth state management
│       │   │   │   ├── login_screen.dart
│       │   │   │   └── register_screen.dart
│       │   │   ├── admin/
│       │   │   │   ├── dashboard_screen.dart # Admin panel
│       │   │   │   ├── test_creation/
│       │   │   │   ├── test_management/
│       │   │   │   └── evaluation/           # Manual evaluation UI
│       │   │   ├── candidate/
│       │   │   │   ├── candidate_dashboard_shell.dart
│       │   │   │   ├── available_tests_screen.dart
│       │   │   │   ├── test_taking/
│       │   │   │   │   ├── test_screen.dart
│       │   │   │   │   ├── timer_widget.dart
│       │   │   │   │   └── question_widgets/
│       │   │   │   └── results_screen.dart
│       │   │   ├── navigation/
│       │   │   │   └── app_router.dart       # Route management
│       │   │   └── shared/
│       │   │       ├── widgets/
│       │   │       └── dialogs/
│       │   ├── test/
│       │   │   └── widget_test.dart
│       ├── android/                 # Android-specific config
│       ├── ios/                     # iOS-specific config
│       ├── web/                     # Web-specific config
│       ├── pubspec.yaml             # Flutter dependencies
│       └── analysis_options.yaml    # Lint rules
│
└── README.md                        # This file
```

---

## 📦 Prerequisites

### Minimum Requirements

- **Node.js**: v16 LTS or higher ([download](https://nodejs.org))
- **PostgreSQL**: v12+ ([download](https://www.postgresql.org/download))
- **Flutter**: 3.9.2+ ([install](https://flutter.dev/docs/get-started/install))
- **Dart**: 3.9.2+ (included with Flutter)
- **npm/yarn**: v7+ (comes with Node.js)

### Verify Installation

```bash
# Check Node.js version
node --version    # Should be v16+

# Check npm version
npm --version     # Should be v7+

# Check PostgreSQL
psql --version    # Should be 12+

# Check Flutter
flutter --version # Should be 3.9.2+

# Check Dart
dart --version    # Should be 3.9.2+
```

---

## 🚀 Installation & Setup

### Backend Setup

#### 1. Clone & Navigate to Backend

```bash
git clone <repository-url>
cd test-gorilla/backend
```

#### 2. Install Dependencies

```bash
npm install
```

This installs all required packages:
- **express** - Web framework
- **pg** - PostgreSQL client
- **jsonwebtoken** - JWT authentication
- **bcryptjs** - Password hashing
- **cors** - Cross-origin requests
- **dotenv** - Environment variables
- **nodemon** - Development hot reload

#### 3. Configure Environment Variables

```bash
# Copy the example file
cp .env.example .env

# Edit .env with your settings (see Environment Variables section below)
```

**Quick Start Config:**

```env
# .env
NODE_ENV=development
PORT=5000

# PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=testgorilla
DB_USER=postgres
DB_PASSWORD=postgres

# JWT
JWT_SECRET=your-secret-key-change-in-production
JWT_EXPIRY=24h

# CORS
CORS_ORIGIN=http://localhost:3000

# Logging
LOG_LEVEL=debug
```

#### 4. Create PostgreSQL Database

```bash
# Open PostgreSQL terminal
psql -U postgres

# Inside psql:
CREATE DATABASE testgorilla;
\q
```

Or use a single command:

```bash
createdb -U postgres testgorilla
```

#### 5. Run Database Migrations

Migrations create the necessary tables and schema:

```bash
# Manually run migrations (in order)
psql -U postgres -d testgorilla -f migrations/001_create_users_table.sql
psql -U postgres -d testgorilla -f migrations/002_create_tests_table.sql
psql -U postgres -d testgorilla -f migrations/003_create_questions.sql
psql -U postgres -d testgorilla -f migrations/004_create_attempts.sql
psql -U postgres -d testgorilla -f migrations/005_create_results.sql
psql -U postgres -d testgorilla -f migrations/006_add_manual_review_support.sql
psql -U postgres -d testgorilla -f migrations/007_create_verification_tokens.sql
```

Or create a migration script and automate this process.

#### 6. (Optional) Seed Test Data

```bash
# Add sample users for development
node seed_users.js
```

#### 7. Start the Backend Server

**Development (with hot reload):**

```bash
npm run dev
```

Server will be available at: `http://localhost:5000`

**Production:**

```bash
npm start
```

**Expected Output:**

```
Server started successfully
  environment: development
  port: 5000
  url: http://localhost:5000
```

### Frontend Setup

#### 1. Navigate to Frontend

```bash
cd test-gorilla/frontend/test_gorilla
```

#### 2. Get Flutter Dependencies

```bash
flutter pub get
```

This installs all packages from [pubspec.yaml](frontend/test_gorilla/pubspec.yaml).

#### 3. Configure API Connection

Edit the API base URL in your app configuration:

**File**: `lib/core/config/app_config.dart`

```dart
class AppConfig {
  // Development
  static const String DEV_API_BASE_URL = 'http://localhost:5000/api/v1';
  
  // Production
  static const String PROD_API_BASE_URL = 'https://api.testgorilla.com/api/v1';
  
  // Use based on environment
  static const String API_BASE_URL = DEV_API_BASE_URL;
}
```

**For Android Emulator:**
- Use `http://10.0.2.2:5000/api/v1` (special IP for emulator to reach host)

**For iOS Simulator:**
- Use `http://localhost:5000/api/v1` or use ngrok for tunneling

**For Web:**
- Use `http://localhost:5000/api/v1`

#### 4. Run on Different Platforms

**Run on Android Emulator:**

```bash
flutter emulators --launch emulator-5554  # Launch emulator first
flutter run -d emulator-5554
```

**Run on iOS Simulator:**

```bash
flutter run -d iPhone
```

**Run on Web Browser:**

```bash
flutter run -d chrome
```

Or for a specific browser:

```bash
flutter run -d edge
flutter run -d firefox
```

**Run on Physical Device:**

```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

#### 5. Build for Release

**Android APK:**

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**iOS IPA:**

```bash
flutter build ios --release
# Output: build/ios/ipa/
```

**Web Release:**

```bash
flutter build web --release
# Output: build/web/
```

---

## 🔌 API Documentation

### Base URL

```
http://localhost:5000/api/v1
```

### Authentication Endpoints

All endpoints except `/auth/register` and `/auth/login` require JWT token in header.

#### Register User

```http
POST /auth/register
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "SecurePassword123",
  "role": "candidate"  // or "admin"
}
```

**Response:**

```json
{
  "success": true,
  "message": "User registered successfully",
  "user": {
    "id": "uuid-123",
    "name": "John Doe",
    "email": "john@example.com",
    "role": "candidate"
  },
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc..."
}
```

#### Login User

```http
POST /auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "SecurePassword123"
}
```

**Response:**

```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "id": "uuid-123",
    "name": "John Doe",
    "email": "john@example.com",
    "role": "candidate"
  },
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc..."
}
```

#### Get Current User

```http
GET /auth/me
Authorization: Bearer <accessToken>
```

**Response:**

```json
{
  "success": true,
  "user": {
    "id": "uuid-123",
    "name": "John Doe",
    "email": "john@example.com",
    "role": "candidate",
    "createdAt": "2024-04-20T10:30:00Z"
  }
}
```

---

### Test Management Endpoints

#### Create Test (Admin Only)

```http
POST /tests
Authorization: Bearer <adminToken>
Content-Type: application/json

{
  "title": "JavaScript Assessment",
  "description": "Test your JavaScript skills",
  "duration_minutes": 60,
  "pass_percentage": 75
}
```

#### Get All Tests

```http
GET /tests
Authorization: Bearer <token>
```

**Admin** sees: their own created tests
**Candidate** sees: published tests only

#### Get Test by ID

```http
GET /tests/{testId}
Authorization: Bearer <token>
```

#### Update Test (Admin Only)

```http
PUT /tests/{testId}
Authorization: Bearer <adminToken>
Content-Type: application/json

{
  "title": "Updated Title",
  "description": "Updated description",
  "duration_minutes": 90
}
```

#### Publish Test (Admin Only)

```http
PATCH /tests/{testId}/publish
Authorization: Bearer <adminToken>
```

#### Archive Test (Admin Only)

```http
PATCH /tests/{testId}/archive
Authorization: Bearer <adminToken>
```

#### Delete Test (Admin Only)

```http
DELETE /tests/{testId}
Authorization: Bearer <adminToken>
```

---

### Question Management Endpoints

#### Create Question (Admin Only)

```http
POST /tests/{testId}/questions
Authorization: Bearer <adminToken>
Content-Type: application/json

{
  "question_text": "What is the output of this code?",
  "question_type": "mcq",  // mcq, coding, or essay
  "options": [
    { "text": "Option A", "is_correct": true },
    { "text": "Option B", "is_correct": false },
    { "text": "Option C", "is_correct": false }
  ],
  "order_index": 1
}
```

#### Get Questions in Test

```http
GET /tests/{testId}/questions
Authorization: Bearer <token>
```

#### Update Question (Admin Only)

```http
PUT /tests/{testId}/questions/{questionId}
Authorization: Bearer <adminToken>
Content-Type: application/json
```

#### Delete Question (Admin Only)

```http
DELETE /tests/{testId}/questions/{questionId}
Authorization: Bearer <adminToken>
```

---

### Test Attempt Endpoints

#### Start Test Attempt (Candidate Only)

```http
POST /tests/{testId}/attempts
Authorization: Bearer <candidateToken>
Content-Type: application/json

{
  "candidate_id": "uuid-456"
}
```

**Response:**

```json
{
  "success": true,
  "attempt": {
    "id": "attempt-uuid",
    "test_id": "test-uuid",
    "candidate_id": "candidate-uuid",
    "status": "in_progress",
    "started_at": "2024-04-20T10:30:00Z",
    "time_limit_seconds": 3600,
    "questions": [
      {
        "id": "q-1",
        "text": "Question text...",
        "type": "mcq",
        "options": [...]
      }
    ]
  }
}
```

#### Get Attempt Details

```http
GET /attempts/{attemptId}
Authorization: Bearer <token>
```

#### Submit Answer to Question

```http
POST /attempts/{attemptId}/responses
Authorization: Bearer <candidateToken>
Content-Type: application/json

{
  "question_id": "q-1",
  "selected_option_id": "option-a",  // For MCQ
  "answer_text": "...",              // For essay
  "code_answer": "..."               // For coding
}
```

#### Submit Entire Attempt

```http
POST /attempts/{attemptId}/submit
Authorization: Bearer <candidateToken>
```

**Response:**

```json
{
  "success": true,
  "message": "Test submitted successfully",
  "result": {
    "id": "result-uuid",
    "attempt_id": "attempt-uuid",
    "total_questions": 10,
    "correct_answers": 8,
    "score": 80,
    "passing_score": 75,
    "status": "passed"  // or "pending_review" if has essays/coding
  }
}
```

---

### Results & Evaluation Endpoints

#### Get Test Results

```http
GET /results?test_id={testId}
Authorization: Bearer <adminToken>
```

#### Get Candidate Results

```http
GET /candidates/{candidateId}/results
Authorization: Bearer <token>
```

#### Get Pending Evaluations (Admin Only)

```http
GET /attempts/pending-evaluations
Authorization: Bearer <adminToken>
```

Returns all pending essays and coding question evaluations.

#### Submit Evaluation (Admin Only)

```http
POST /attempts/{attemptId}/evaluate
Authorization: Bearer <adminToken>
Content-Type: application/json

{
  "question_id": "q-1",
  "marks_obtained": 8,
  "marks_total": 10,
  "feedback": "Good solution with proper error handling"
}
```

---

### Health Check Endpoint

```http
GET /health
```

**Response:**

```json
{
  "success": true,
  "status": "API and database are operational",
  "database": "connected",
  "timestamp": "2024-04-20T10:30:00Z"
}
```

---

## ✨ Features

### Admin Features

- ✅ **Test Management**
  - Create, edit, publish, archive tests
  - Set duration, passing criteria
  - Manage test visibility
  
- ✅ **Question Management**
  - Add MCQ, Coding, Essay questions
  - Set correct answers for MCQ
  - Define evaluation rubrics
  
- ✅ **Candidate Management**
  - View all test takers
  - Track candidate progress
  - Download results in CSV/PDF
  
- ✅ **Evaluation & Scoring**
  - Auto-score MCQ questions
  - Manual review interface for essays/coding
  - Provide feedback to candidates
  
- ✅ **Analytics Dashboard**
  - Pass/fail statistics
  - Time analysis
  - Performance trends

### Candidate Features

- ✅ **Test Discovery**
  - Browse available tests
  - View test details (duration, questions count)
  - Check previous attempts
  
- ✅ **Test Taking Experience**
  - Real-time timer with audio alerts
  - Question navigation (previous/next)
  - Progress indicator
  - MCQ response selection
  - Essay/Coding text input
  
- ✅ **Anti-Cheating Measures**
  - Tab switch detection
  - Full-screen enforcement
  - Window blur detection
  - Suspicious activity logging
  
- ✅ **Immediate Feedback**
  - Instant MCQ results
  - Overall score display
  - Detailed question review
  
- ✅ **Results History**
  - View all attempt history
  - Compare scores
  - Download certificates (if passed)

---

## 🏗 Architecture & Design

### Authentication Flow (JWT)

```
1. User Registration/Login
   └─> POST /auth/register or /auth/login
       └─> Generate JWT tokens (Access + Refresh)
           └─> Return tokens to client

2. Authenticated Requests
   └─> Client includes: Authorization: Bearer {accessToken}
       └─> Middleware validates JWT signature
           └─> Extract user ID & role
               └─> Proceed with request or reject

3. Token Refresh (Future Implementation)
   └─> Access Token expires → Use Refresh Token
       └─> GET /auth/refresh
           └─> Issue new Access Token pair
```

**JWT Payload:**

```json
{
  "id": "user-uuid",
  "email": "user@example.com",
  "role": "admin|candidate|recruiter",
  "iat": 1713607800,
  "exp": 1713694200
}
```

### Role-Based Access Control (RBAC)

```
┌─────────────┐
│   User      │
│  (Role)     │
└──────┬──────┘
       │
       ├─→ [ADMIN]
       │   ├─ Create/Edit Tests
       │   ├─ Manage Questions
       │   ├─ View All Results
       │   ├─ Evaluate Essays/Coding
       │   └─ Access Analytics
       │
       ├─→ [CANDIDATE]
       │   ├─ View Published Tests
       │   ├─ Take Tests
       │   ├─ View Own Results
       │   └─ View Own Attempts
       │
       └─→ [RECRUITER]
           ├─ Create Tests
           ├─ View Results (own tests)
           └─ Evaluate Submissions
```

### Database Schema Overview

**Users Table:**
- `id` (UUID Primary Key)
- `name`, `email`, `password_hash`
- `role` (admin/candidate/recruiter)
- `created_at`, `updated_at`

**Tests Table:**
- `id`, `title`, `description`
- `duration_minutes`, `pass_percentage`
- `created_by` (Reference to Users)
- `status` (draft/published/archived)
- `created_at`, `updated_at`

**Questions Table:**
- `id`, `test_id`, `question_text`, `question_type`
- `options` (JSON array for MCQ)
- `correct_answer` (for MCQ/coding)
- `order_index`, `marks`

**Attempts Table:**
- `id`, `test_id`, `candidate_id`
- `status` (in_progress/submitted/evaluated)
- `started_at`, `submitted_at`
- `time_spent_seconds`

**Results Table:**
- `id`, `attempt_id`, `score`, `status`
- `total_questions`, `correct_answers`
- `evaluated_at`, `created_at`

### API Request/Response Pattern

**Standard Success Response:**

```json
{
  "success": true,
  "message": "Operation successful",
  "data": { ... },
  "timestamp": "2024-04-20T10:30:00Z"
}
```

**Standard Error Response:**

```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": { ... },
  "timestamp": "2024-04-20T10:30:00Z"
}
```

---

## 👨‍💻 Development Guide

### Backend Development

#### Running Tests

```bash
npm test
```

#### Code Structure

- **Controllers**: Handle HTTP request/response
- **Services**: Core business logic & database queries
- **Middleware**: Request interceptors (auth, logging, error)
- **Routes**: Endpoint definitions & routing
- **Utils**: Helpers (JWT, logger, constants)

#### Adding a New Endpoint

1. Define route in `routes/` folder
2. Create controller method in `controllers/` folder
3. Add business logic in `services/` folder
4. Register route in `app.js`
5. Add middleware (auth, validation)

#### Database Queries

```javascript
// Using connection pool from config/db.js
const db = require('../config/db');

// Query with parameters (prevent SQL injection)
const result = await db.query(
  'SELECT * FROM users WHERE email = $1',
  [email]
);

// Insert
await db.query(
  'INSERT INTO users (name, email) VALUES ($1, $2)',
  [name, email]
);
```

### Frontend Development

#### Running App in Debug Mode

```bash
flutter run -v  # Verbose output
```

#### State Management (Provider)

```dart
// Define provider
class TestProvider with ChangeNotifier {
  List<Test> _tests = [];
  
  Future<void> fetchTests() async {
    _tests = await apiClient.getTests();
    notifyListeners();
  }
}

// Use in widget
Consumer<TestProvider>(
  builder: (context, testProvider, child) {
    return ListView(
      children: testProvider.tests.map((test) => ...).toList(),
    );
  },
)
```

#### API Client Usage

```dart
// lib/core/api/api_client.dart
final apiClient = ApiClient();

// GET request
final tests = await apiClient.get('/tests');

// POST request
final result = await apiClient.post('/tests', {
  'title': 'New Test',
  'duration_minutes': 60
});
```

#### Local Storage (JWT Tokens)

```dart
// Save token
await JwtStorage.saveToken(token);

// Retrieve token
final token = await JwtStorage.getToken();

// Remove token (logout)
await JwtStorage.deleteToken();
```

---

## 🔐 Environment Variables

### Backend (.env)

```env
# Server
NODE_ENV=development|production
PORT=5000

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=testgorilla
DB_USER=postgres
DB_PASSWORD=<secure-password>
DB_POOL_MIN=2
DB_POOL_MAX=10

# JWT Authentication
JWT_SECRET=your-secret-key-minimum-32-characters
JWT_EXPIRY=24h
REFRESH_TOKEN_EXPIRY=7d
BCRYPT_SALT_ROUNDS=10

# CORS
CORS_ORIGIN=http://localhost:3000,http://localhost:8080

# Logging
LOG_LEVEL=debug|info|warn|error
```

### Frontend (lib/core/config/app_config.dart)

```dart
class AppConfig {
  // API Configuration
  static const String DEV_API_BASE_URL = 'http://localhost:5000/api/v1';
  static const String PROD_API_BASE_URL = 'https://api.testgorilla.com/api/v1';
  static const String API_BASE_URL = DEV_API_BASE_URL;
  
  // JWT Storage Keys
  static const String JWT_TOKEN_KEY = 'auth_token';
  static const String REFRESH_TOKEN_KEY = 'refresh_token';
}
```

---

## 🐛 Troubleshooting

### Backend Issues

#### Port Already in Use

```bash
# Kill process on port 5000
lsof -ti:5000 | xargs kill -9  # macOS/Linux
netstat -ano | findstr :5000   # Windows
```

#### Database Connection Failed

```bash
# Verify PostgreSQL is running
psql -U postgres -c "SELECT version();"

# Check .env variables
cat .env | grep DB_

# Reset database
dropdb testgorilla
createdb testgorilla
# Re-run migrations
```

#### JWT Token Invalid

- Ensure `JWT_SECRET` is set in `.env`
- Check token expiry: `JWT_EXPIRY=24h`
- Clear browser localStorage and re-login

#### CORS Errors

Update `CORS_ORIGIN` in `.env`:

```env
# Allow multiple origins
CORS_ORIGIN=http://localhost:3000,http://localhost:8080,https://example.com
```

### Frontend Issues

#### Android Emulator Cannot Reach Backend

Use the special IP for emulator:

```dart
static const String DEV_API_BASE_URL = 'http://10.0.2.2:5000/api/v1';
```

#### Build Fails - Dependency Issues

```bash
flutter clean
flutter pub get
flutter pub upgrade
```

#### iOS Pod Installation Fails

```bash
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

#### HTTP Certificate Validation Error

Update API client to allow self-signed certificates (dev only):

```dart
HttpClient httpClient = new HttpClient()
  ..badCertificateCallback = ((certificate, host, port) => true);
```

---

## 📄 License

MIT License - See LICENSE file for details.

---

## 👥 Support & Contribution

For issues, feature requests, or contributions:
1. Check existing issues
2. Create detailed bug reports
3. Submit pull requests with clear descriptions
4. Follow existing code style and patterns

---

## 📞 Contact

For questions or support, reach out to the development team or check the project wiki for additional documentation.

---

**Last Updated**: April 2024  
**Version**: 1.0.0  
**Status**: Production Ready
