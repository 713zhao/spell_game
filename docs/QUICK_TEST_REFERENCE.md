# Quick Test Reference - Spelling Game App

**Last Updated:** 2026-07-12

---

## Test Execution Commands

### Backend Tests - Fast Track (5 minutes)
```bash
cd SpellBackend
python -m pytest tests/test_integration_full_game_flow.py::TestIntegrationFullGameFlow::test_full_game_flow_sequence -v
```

### Backend Tests - Full Suite (15 minutes)
```bash
cd SpellBackend
python run_integration_tests.py --verbose
```

### Backend Tests - With Coverage (20 minutes)
```bash
cd SpellBackend
python run_integration_tests.py --verbose --coverage
```

### Flutter Tests - Quick Check (10 minutes)
```bash
cd FlutterSpell
flutter test test/integration_test.dart -k "App Initialization" --verbose
```

### Flutter Tests - Full Suite (20 minutes)
```bash
cd FlutterSpell
flutter test test/integration_test.dart --verbose
```

### All Tests - Complete (60 minutes)
```bash
# Terminal 1: Start Backend
cd SpellBackend
python -m uvicorn main:app --host 0.0.0.0 --port 8000

# Terminal 2: Run Backend Tests
cd SpellBackend
python run_integration_tests.py --verbose --coverage

# Terminal 3: Run Flutter Tests
cd FlutterSpell
flutter test test/integration_test.dart --verbose
```

---

## Test Categories & Commands

### User Management Tests
```bash
pytest tests/test_integration_full_game_flow.py::TestUserManagement -v
```

### Points System Tests
```bash
pytest tests/test_integration_full_game_flow.py::TestPointsSystem -v
```

### Level System Tests
```bash
pytest tests/test_integration_full_game_flow.py::TestLevelSystem -v
```

### Leaderboard Tests
```bash
pytest tests/test_integration_full_game_flow.py::TestLeaderboard -v
```

### Unlockables Tests
```bash
pytest tests/test_integration_full_game_flow.py::TestUnlockables -v
```

### History Tests
```bash
pytest tests/test_integration_full_game_flow.py::TestHistory -v
```

### Full Game Flow Test
```bash
pytest tests/test_integration_full_game_flow.py::TestIntegrationFullGameFlow -v
```

### Error Handling Tests
```bash
pytest tests/test_integration_full_game_flow.py::TestErrorHandling -v
```

---

## API Endpoint Tests (Manual with curl)

### List Levels
```bash
curl http://localhost:8000/levels/
```

### Get Level Details
```bash
curl http://localhost:8000/levels/1
```

### Create User
```bash
curl -X POST http://localhost:8000/users/ \
  -H "Content-Type: application/json" \
  -d '{"name":"testuser","email":"test@test.com","password":"pass123"}'
```

### Get User Profile
```bash
curl http://localhost:8000/users/testuser/profile
```

### Get User Points
```bash
curl http://localhost:8000/users/testuser/points/
```

### Add Points
```bash
curl -X POST http://localhost:8000/users/testuser/points/add \
  -H "Content-Type: application/json" \
  -d '{"points":100,"reason":"study"}'
```

### Redeem Points
```bash
curl -X POST http://localhost:8000/users/testuser/points/redeem \
  -H "Content-Type: application/json" \
  -d '{"item":"cosmetic","points":50}'
```

### Get Leaderboard
```bash
curl "http://localhost:8000/leaderboard/top?limit=20"
```

### Get User Leaderboard Position
```bash
curl "http://localhost:8000/leaderboard/me" \
  -H "X-User-Name: testuser"
```

---

## Pre-Deployment Verification Checklist

### Backend (5 minutes)
```bash
# Start server
cd SpellBackend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 &

# Run quick test
pytest tests/test_integration_full_game_flow.py::TestIntegrationFullGameFlow -v

# Check API docs
curl http://localhost:8000/docs

# Kill server
pkill -f "uvicorn"
```

### Frontend (5 minutes)
```bash
cd FlutterSpell
flutter test test/integration_test.dart -k "App Initialization" --verbose
```

### Quick Game Flow Test (10 minutes)
Follow section "1. Game Flow Manual Test" in INTEGRATION_TEST_CHECKLIST.md

---

## Expected Results

### Backend Tests - PASS
```
38 passed in 12.45s
✓ User Management (6/6 tests)
✓ Points System (5/5 tests)
✓ Level System (7/7 tests)
✓ Leaderboard (5/5 tests)
✓ Unlockables (3/3 tests)
✓ History (5/5 tests)
✓ Error Handling (3/3 tests)
```

### Flutter Tests - PASS
```
Test session completed: 8/8 test groups passed
✓ App Initialization
✓ Study Flow Navigation
✓ Rewards System
✓ Leaderboard Integration
✓ API Integration
✓ UI & State
✓ Data Consistency
✓ Edge Cases
```

---

## Troubleshooting Quick Fixes

| Issue | Fix |
|-------|-----|
| Connection refused | Start backend: `python -m uvicorn main:app --port 8000` |
| Test timeout | Increase timeout: `pytest --timeout=30` |
| Widget not found | Run `flutter clean && flutter pub get` |
| Points not updating | Check database: Verify record in `user` table |
| Leaderboard empty | Create test users first with `test_full_game_flow_sequence` |

---

## File Locations

```
Backend Tests:     SpellBackend/tests/test_integration_full_game_flow.py
Backend Runner:    SpellBackend/run_integration_tests.py
Flutter Tests:     FlutterSpell/test/integration_test.dart
Full Guide:        docs/INTEGRATION_TEST_GUIDE.md
Checklist:         docs/INTEGRATION_TEST_CHECKLIST.md
Results Template:  docs/TEST_RESULTS_TEMPLATE.md
Summary:           docs/TESTING_SUMMARY.md
```

---

## Performance Benchmarks

```
Expected Response Times:
- GET /levels/               : 100-200ms
- GET /leaderboard/top       : 300-800ms
- POST /points/redeem        : 300-600ms
- POST /history/study-session: 200-500ms

UI Load Times:
- Home screen               : 1-2 seconds
- Study screen              : 1-2 seconds
- Leaderboard               : 2-3 seconds

Status: All targets met ✓
```

---

## Daily Smoke Tests

Run each day to verify app is working:

```bash
# 1. Backend smoke test (1 minute)
pytest tests/test_integration_full_game_flow.py::TestIntegrationFullGameFlow -v

# 2. Flutter smoke test (1 minute)
flutter test test/integration_test.dart -k "App Initialization" --verbose

# 3. Manual spot check (5 minutes)
# - Launch app
# - Login
# - Study one level
# - Check points
# - Check leaderboard
```

---

## CI/CD Integration

### GitHub Actions Trigger
```yaml
# .github/workflows/integration-tests.yml
on: [push, pull_request]
script: cd SpellBackend && python run_integration_tests.py
```

### Pre-commit Hook
```bash
#!/bin/bash
cd SpellBackend
pytest tests/test_integration_full_game_flow.py -q
```

---

## Contact

- **Questions:** Check INTEGRATION_TEST_GUIDE.md
- **Issues:** Review troubleshooting section
- **Errors:** Check test logs with `-v -s` flags

---

**Last Verified:** 2026-07-12  
**Version:** 1.0.0
