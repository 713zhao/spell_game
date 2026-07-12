# Integration Testing Guide

**Date:** 2026-07-12  
**Project:** Game-Based Spelling App  
**Purpose:** Comprehensive integration testing of all screens and backend APIs

---

## Overview

This document provides a complete guide for running and executing integration tests for the Spelling Game App. The tests cover:

1. **Full Game Flow** - Complete user journey from launch to rewards redemption
2. **API Integration** - All backend endpoints and error scenarios
3. **UI Integration** - Screen navigation, state management, error handling
4. **Data Consistency** - Points, inventory, profile data correctness
5. **Edge Cases** - Network issues, concurrent operations, boundary conditions
6. **Performance** - Load times and responsiveness

---

## Environment Setup

### Backend Setup

#### 1. Install Python Dependencies
```bash
cd SpellBackend
pip install -r requirements.txt
# Or with specific versions:
pip install fastapi uvicorn sqlmodel sqlalchemy pytest httpx
```

#### 2. Configure Environment
```bash
# Set up database (if using SQLite or PostgreSQL)
export DATABASE_URL="sqlite:///./test.db"  # or your production URL
```

#### 3. Start Backend Server
```bash
# Option 1: Using uvicorn directly
cd SpellBackend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Option 2: Using the start script
bash start.sh
```

Verify server is running: `http://localhost:8000/docs`

### Frontend Setup (Flutter)

#### 1. Install Flutter Dependencies
```bash
cd FlutterSpell
flutter pub get
```

#### 2. Configure API Endpoint
Edit `lib/config/api_config.dart`:
```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:8000/';  // or your API URL
}
```

#### 3. Verify Flutter Setup
```bash
flutter doctor
```

---

## Running Backend Integration Tests

### Quick Start
```bash
cd SpellBackend
pytest tests/test_integration_full_game_flow.py -v
```

### Run Specific Test Class
```bash
# Test only user management
pytest tests/test_integration_full_game_flow.py::TestUserManagement -v

# Test only points system
pytest tests/test_integration_full_game_flow.py::TestPointsSystem -v

# Test only full game flow
pytest tests/test_integration_full_game_flow.py::TestIntegrationFullGameFlow::test_full_game_flow_sequence -v
```

### Run with Detailed Output
```bash
pytest tests/test_integration_full_game_flow.py -v -s
```

### Run with Coverage Report
```bash
pytest tests/test_integration_full_game_flow.py --cov=src --cov-report=html -v
```

### Test Categories

1. **User Management**
   - Create user
   - Get profile
   - Update profile
   - Verify password
   - Delete user

2. **Points System**
   - Get points balance
   - Add points
   - Redeem points
   - Reward history

3. **Level System**
   - List levels
   - Get level details
   - Start level
   - Complete level
   - Get user progress

4. **Leaderboard**
   - Get top rankings
   - Get user position
   - Filter by school/grade

5. **Unlockables/Cosmetics**
   - List cosmetics
   - Redeem cosmetic
   - Equip cosmetic

6. **History Tracking**
   - Save study session
   - Get study history
   - Clear history

### Expected Test Results

#### All Tests Pass
```
============================= test session starts ==============================
tests/test_integration_full_game_flow.py::TestUserManagement::test_create_user PASSED
tests/test_integration_full_game_flow.py::TestUserManagement::test_user_already_exists PASSED
tests/test_integration_full_game_flow.py::TestPointsSystem::test_get_initial_points PASSED
...
======================== 50 passed in 12.45s ========================
```

#### Expected Failures to Investigate
- `test_complete_level_invalid_accuracy FAILED` → Check accuracy validation
- `test_redeem_points_insufficient FAILED` → Check points logic
- Any `ConnectionError` → Verify backend is running

---

## Running Flutter Integration Tests

### Quick Start
```bash
cd FlutterSpell
flutter test test/integration_test.dart
```

### Run with Verbose Output
```bash
flutter test test/integration_test.dart --verbose
```

### Run Specific Test Group
```bash
# Test only app initialization
flutter test test/integration_test.dart -k "App Initialization"

# Test only navigation
flutter test test/integration_test.dart -k "Navigation"
```

### Integration Testing on Device/Emulator
```bash
# Start an emulator or connect device
emulator -avd Pixel_4_API_30  # Android
# or open iOS simulator

# Run integration tests
flutter test test/integration_test.dart --target=test/integration_test.dart
```

### Expected Test Results
```
✓ App Initialization & Home Screen (Test 1)
✓ Study Flow - Screen Navigation (Test 2)
✓ Rewards & Points System (Test 3)
✓ Leaderboard Integration (Test 4)
...
Test session completed: 8/8 tests passed
```

---

## Manual Testing Checklist

### 1. Game Flow Manual Test
Follow these steps manually to verify the full game flow:

```
1. Launch app
   □ App loads without errors
   □ Home screen displays
   □ No crashes in console

2. Login/Authentication
   □ Can create new user account
   □ Can login with credentials
   □ Session persists after restart

3. Home Screen
   □ Available tags/levels display
   □ Points balance shows
   □ User name displays
   □ TTS plays when testing

4. Study Flow
   □ Can select tag/level
   □ Words load correctly
   □ Can progress through words
   □ Study completion saves

5. Quiz
   □ Quiz questions load
   □ Can answer questions
   □ Results display correctly
   □ Points awarded

6. Rewards
   □ Current points display
   □ Can view available cosmetics
   □ Can redeem (if enough points)
   □ Balance updates

7. Leaderboard
   □ Top 20 users display
   □ User's position shows
   □ Filtering works

8. Profile
   □ Stats display correctly
   □ Can update settings
   □ Language change works
```

### 2. API Endpoint Testing

Use curl or Postman to test endpoints:

```bash
# Get levels
curl http://localhost:8000/levels/

# Create user
curl -X POST http://localhost:8000/users/ \
  -H "Content-Type: application/json" \
  -d '{"name":"testuser","email":"test@test.com","password":"pass123"}'

# Get user profile
curl http://localhost:8000/users/testuser/profile

# Add points
curl -X POST http://localhost:8000/users/testuser/points/add \
  -H "Content-Type: application/json" \
  -d '{"points":100,"reason":"test"}'

# Get leaderboard
curl http://localhost:8000/leaderboard/top?limit=20
```

### 3. Data Consistency Check

After running tests, verify:

```sql
-- Check user creation
SELECT COUNT(*) FROM user;

-- Check points
SELECT name, total_points FROM user WHERE name LIKE 'test_%';

-- Check study history
SELECT COUNT(*) FROM study_history;

-- Check level progress
SELECT COUNT(*) FROM level_progress;
```

---

## Continuous Integration (CI) Setup

### GitHub Actions Example
```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      backend:
        image: python:3.11
        options: >-
          --health-cmd "curl -f http://localhost:8000/docs || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd SpellBackend
          pip install -r requirements.txt
      
      - name: Run backend tests
        run: |
          cd SpellBackend
          pytest tests/test_integration_full_game_flow.py -v
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      
      - name: Run Flutter tests
        run: |
          cd FlutterSpell
          flutter test test/integration_test.dart
```

---

## Performance Benchmarks

Expected performance metrics:

| Endpoint | Expected Time | Limit |
|----------|---|---|
| GET /levels/ | 100-200ms | 500ms |
| GET /levels/{id} | 150-300ms | 500ms |
| POST /users/ | 200-400ms | 1000ms |
| GET /users/{name}/profile | 100-200ms | 500ms |
| GET /leaderboard/top | 300-800ms | 2000ms |
| POST /points/redeem | 300-600ms | 1000ms |
| POST /history/study-session | 200-500ms | 1000ms |

### Measuring Performance
```bash
# With curl and time
time curl http://localhost:8000/levels/

# With Python requests
import requests
import time
start = time.time()
response = requests.get('http://localhost:8000/levels/')
end = time.time()
print(f"Time: {(end-start)*1000}ms")
```

---

## Troubleshooting

### Backend Tests Fail with Connection Error
```
ConnectionError: Failed to establish connection
```
**Solution:** Ensure backend is running on http://localhost:8000

### "User already exists" Error
```
HTTPException: status_code=409, detail="User already exists"
```
**Solution:** Tests use timestamp-based unique names. If issue persists, clean test users:
```bash
# In database
DELETE FROM user WHERE name LIKE 'test_%';
```

### Flutter Tests Fail with Widget Not Found
```
TestFailure: Expected Finder to find exactly 1 widget, but found 0
```
**Solution:** 
- Ensure app is properly initialized
- Check if widget types have changed
- Update imports in test file

### Leaderboard API Returns Empty
```
GET /leaderboard/top returns []
```
**Solution:**
- Create test users with points first
- Verify level_progress and points tables have data
- Check leaderboard query in backend

### Points Not Updating After Redemption
```
POST /points/redeem succeeds but balance unchanged
```
**Solution:**
- Verify points calculation in backend
- Check transaction logs
- Ensure session is committed to database

---

## Test Report Template

### Test Execution Report

**Date:** _______________  
**Tester:** _______________  
**Environment:** [ ] Dev [ ] Staging [ ] Production  

**Backend Tests:**
- Total Tests: _____
- Passed: _____
- Failed: _____
- Skipped: _____
- Execution Time: _____

**Flutter Tests:**
- Total Tests: _____
- Passed: _____
- Failed: _____
- Skipped: _____
- Execution Time: _____

**Manual Tests:**
- Game Flow: [ ] Pass [ ] Fail
- API Endpoints: [ ] Pass [ ] Fail
- Data Consistency: [ ] Pass [ ] Fail

**Critical Issues:**
1. _________________________________________________
2. _________________________________________________

**Minor Issues:**
1. _________________________________________________
2. _________________________________________________

**Recommendations:**
_________________________________________________
_________________________________________________

**Sign-Off:**
- Tester: ______________ Date: ___________
- QA Lead: ______________ Date: ___________

---

## Resources

- **FastAPI Testing:** https://fastapi.tiangolo.com/advanced/testing-dependencies/
- **Flutter Testing:** https://flutter.dev/docs/testing
- **Pytest Documentation:** https://docs.pytest.org/
- **API Testing Tools:** Postman, Insomnia, curl
- **Performance Testing:** Apache JMeter, LoadRunner

---

## Contact & Support

For issues or questions about integration testing:
- Check test logs: `pytest -v -s`
- Review API documentation: `http://localhost:8000/docs`
- Check database state directly
- Review application logs

