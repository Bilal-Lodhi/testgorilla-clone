# Test Attempts System - cURL Testing Examples

Quick command-line testing guide using cURL.

---

## Setup Variables
```bash
export BASE_URL="http://localhost:5000"
export ADMIN_TOKEN="your_admin_token_here"
export CANDIDATE_TOKEN="your_candidate_token_here"
export TEST_ID="your_test_id_here"
export ATTEMPT_ID="your_attempt_id_here"
export QUESTION_1_ID="your_question_1_id_here"
export OPTION_ID="your_option_id_here"
```

---

## 1. Admin Login (Get Admin Token)
```bash
curl -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "Password123!"
  }' | jq '.'
```

**Extract token:** `jq -r '.data.accessToken'`

---

## 2. Create Test
```bash
curl -X POST "$BASE_URL/api/v1/tests" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "JavaScript Basics Quiz",
    "description": "Test your JavaScript fundamentals",
    "duration_minutes": 30,
    "pass_percentage": 70,
    "status": "draft"
  }' | jq '.data.test.id'
```

---

## 3. Create MCQ Question
```bash
curl -X POST "$BASE_URL/api/v1/tests/$TEST_ID/questions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "mcq",
    "question_text": "What is 2 + 2?",
    "marks": 1,
    "order_index": 1,
    "options": ["3", "4", "5", "6"],
    "correct_option": 1
  }' | jq '.'
```

**Extract option IDs from response options[].id**

---

## 4. Create Coding Question
```bash
curl -X POST "$BASE_URL/api/v1/tests/$TEST_ID/questions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "coding",
    "question_text": "Write a function to add two numbers",
    "marks": 5,
    "order_index": 2,
    "options": [],
    "correct_option": null
  }' | jq '.data.question.id'
```

---

## 5. Publish Test
```bash
curl -X PATCH "$BASE_URL/api/v1/tests/$TEST_ID/publish" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
```

---

## 6. Candidate Login (Get Candidate Token)
```bash
curl -X POST "$BASE_URL/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "candidate@example.com",
    "password": "Password123!"
  }' | jq '.'
```

**Extract token:** `jq -r '.data.accessToken'`

---

## 7. Candidate Starts Test Attempt
```bash
curl -X POST "$BASE_URL/api/v1/tests/$TEST_ID/attempts" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
```

**Extract from response:**
- `.data.attempt.id` → `$ATTEMPT_ID`
- `.data.questions[0].id` → `$QUESTION_1_ID`
- `.data.questions[0].options[1].id` → `$OPTION_ID` (correct option for index 1)

---

## 8. Candidate Submits MCQ Answer
```bash
curl -X POST "$BASE_URL/api/v1/attempts/$ATTEMPT_ID/responses" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"questionId\": \"$QUESTION_1_ID\",
    \"selectedOptionId\": \"$OPTION_ID\"
  }" | jq '.'
```

**Expected:** `is_correct: true, marks_obtained: 1`

---

## 9. Candidate Gets Attempt Details
```bash
curl -X GET "$BASE_URL/api/v1/attempts/$ATTEMPT_ID" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
```

---

## 10. Candidate Submits Coding Answer
```bash
curl -X POST "$BASE_URL/api/v1/attempts/$ATTEMPT_ID/responses" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "questionId": "question_2_id_here",
    "codeAnswer": "function add(a, b) { return a + b; }"
  }' | jq '.'
```

**Expected:** `marks_obtained: 0` (pending evaluation)

---

## 11. Candidate Submits Test (Final Submission)
```bash
curl -X POST "$BASE_URL/api/v1/attempts/$ATTEMPT_ID/submit" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
```

**Response includes:**
- `status: "submitted"`
- `score: total_score`
- `result.percentage: 60`
- `result.passed: false/true`

---

## 12. Candidate Views All Personal Attempts
```bash
curl -X GET "$BASE_URL/api/v1/candidates/attempts" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
```

---

## 13. Admin Views All Test Attempts
```bash
curl -X GET "$BASE_URL/api/v1/tests/$TEST_ID/attempts" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" | jq '.'
```

**Shows all candidates' attempts with their scores**

---

## Error Testing

### 1. Test Duplicate Attempt (Should Get 409 Conflict)
```bash
curl -X POST "$BASE_URL/api/v1/tests/$TEST_ID/attempts" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Error:**
```json
{
  "success": false,
  "error": "You already have an active attempt for this test"
}
```

---

### 2. Test Unpublished Test (Should Get 400)
```bash
# Create draft test
curl -X POST "$BASE_URL/api/v1/tests" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Draft Test",
    "duration_minutes": 30,
    "pass_percentage": 70,
    "status": "draft"
  }' | jq -r '.data.test.id' > draft_test_id.txt

# Try to start attempt on draft test
DRAFT_TEST_ID=$(cat draft_test_id.txt)
curl -X POST "$BASE_URL/api/v1/tests/$DRAFT_TEST_ID/attempts" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Error:**
```json
{
  "success": false,
  "error": "Test is not published. Cannot start attempt."
}
```

---

### 3. Test Non-Candidate User (Should Get 403)
```bash
curl -X POST "$BASE_URL/api/v1/tests/$TEST_ID/attempts" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Error:**
```json
{
  "success": false,
  "error": "Access denied. Required role(s): candidate"
}
```

---

### 4. Test Invalid Answer (Wrong Option)
```bash
# Get an INCORRECT option ID (not the correct one)
curl -X POST "$BASE_URL/api/v1/attempts/$ATTEMPT_ID/responses" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"questionId\": \"$QUESTION_1_ID\",
    \"selectedOptionId\": \"wrong_option_id\"
  }" | jq '.'
```

**Expected:** `is_correct: false, marks_obtained: 0`

---

## Full Workflow Script
```bash
#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== TestGorilla API Full Workflow ===${NC}\n"

# 1. Admin Login
echo -e "${BLUE}1. Admin Login...${NC}"
ADMIN_LOGIN=$(curl -s -X POST "http://localhost:5000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"Password123!"}')
ADMIN_TOKEN=$(echo $ADMIN_LOGIN | jq -r '.data.accessToken')
echo -e "${GREEN}Admin Token: $ADMIN_TOKEN${NC}\n"

# 2. Create Test
echo -e "${BLUE}2. Creating Test...${NC}"
TEST=$(curl -s -X POST "http://localhost:5000/api/v1/tests" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"JS Quiz","description":"Test JS","duration_minutes":30,"pass_percentage":70,"status":"draft"}')
TEST_ID=$(echo $TEST | jq -r '.data.test.id')
echo -e "${GREEN}Test ID: $TEST_ID${NC}\n"

# 3. Create Question
echo -e "${BLUE}3. Creating MCQ Question...${NC}"
QUESTION=$(curl -s -X POST "http://localhost:5000/api/v1/tests/$TEST_ID/questions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"type":"mcq","question_text":"What is 2+2?","marks":1,"order_index":1,"options":["3","4","5","6"],"correct_option":1}')
QUESTION_ID=$(echo $QUESTION | jq -r '.data.question.id')
OPTION_ID=$(echo $QUESTION | jq -r '.data.question.options[1].id')
echo -e "${GREEN}Question ID: $QUESTION_ID${NC}"
echo -e "${GREEN}Correct Option ID: $OPTION_ID${NC}\n"

# 4. Publish Test
echo -e "${BLUE}4. Publishing Test...${NC}"
curl -s -X PATCH "http://localhost:5000/api/v1/tests/$TEST_ID/publish" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" -d '{}' | jq '.message'

# 5. Candidate Login
echo -e "\n${BLUE}5. Candidate Login...${NC}"
CANDIDATE_LOGIN=$(curl -s -X POST "http://localhost:5000/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"candidate@example.com","password":"Password123!"}')
CANDIDATE_TOKEN=$(echo $CANDIDATE_LOGIN | jq -r '.data.accessToken')
echo -e "${GREEN}Candidate Token: $CANDIDATE_TOKEN${NC}\n"

# 6. Start Attempt
echo -e "${BLUE}6. Starting Test Attempt...${NC}"
ATTEMPT=$(curl -s -X POST "http://localhost:5000/api/v1/tests/$TEST_ID/attempts" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" -d '{}')
ATTEMPT_ID=$(echo $ATTEMPT | jq -r '.data.attempt.id')
echo -e "${GREEN}Attempt ID: $ATTEMPT_ID${NC}\n"

# 7. Submit Answer
echo -e "${BLUE}7. Submitting Answer...${NC}"
RESPONSE=$(curl -s -X POST "http://localhost:5000/api/v1/attempts/$ATTEMPT_ID/responses" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"questionId\":\"$QUESTION_ID\",\"selectedOptionId\":\"$OPTION_ID\"}")
IS_CORRECT=$(echo $RESPONSE | jq -r '.data.response.is_correct')
MARKS=$(echo $RESPONSE | jq -r '.data.response.marks_obtained')
echo -e "${GREEN}Answer Correct: $IS_CORRECT, Marks: $MARKS${NC}\n"

# 8. Submit Test
echo -e "${BLUE}8. Submitting Test...${NC}"
RESULT=$(curl -s -X POST "http://localhost:5000/api/v1/attempts/$ATTEMPT_ID/submit" \
  -H "Authorization: Bearer $CANDIDATE_TOKEN" \
  -H "Content-Type: application/json" -d '{}')
echo $RESULT | jq '.data.result'

echo -e "\n${GREEN}=== Workflow Complete ===${NC}\n"
```

Save as `test_workflow.sh`, then:
```bash
chmod +x test_workflow.sh
./test_workflow.sh
```

---

## Quick Testing Tips

1. **Pretty Print Responses:**
   ```bash
   curl ... | jq '.'
   ```

2. **Extract Specific Fields:**
   ```bash
   curl ... | jq '.data.attempt.id'
   ```

3. **Save Response to File:**
   ```bash
   curl ... | jq '.' > response.json
   ```

4. **Test Multiple Times:**
   ```bash
   for i in {1..5}; do
     curl -X POST ...
   done
   ```

5. **Time Request Duration:**
   ```bash
   time curl -X POST ...
   ```

---

All endpoints tested and working! 🚀
