# Sound Effects & Animation Testing Guide

## Pre-Test Checklist

- [ ] Flutter SDK updated to latest stable version
- [ ] All dependencies installed (`flutter pub get`)
- [ ] Device/emulator with audio capability available
- [ ] Sound files generated or sourced (see QUICK_START_AUDIO.md)
- [ ] Project builds without errors (`flutter build` for target platform)

## Test Environment

### Required Setup

```bash
# Verify Flutter environment
flutter doctor

# Get dependencies
flutter pub get

# Generate sound files (if using test audio)
python generate_test_sounds.py
```

## Unit Test Cases

### Sound Service Tests

1. **Initialization**
   - [ ] SoundService initializes without errors
   - [ ] SharedPreferences loads sound_enabled setting
   - [ ] Default sound_enabled is true

2. **Sound Playback**
   - [ ] Each sound method can be called without crashes
   - [ ] Sound plays when sound_enabled = true
   - [ ] Sound is muted when sound_enabled = false
   - [ ] No crashes if sound files are missing

3. **Settings Synchronization**
   - [ ] setSoundEnabled(true) plays sounds
   - [ ] setSoundEnabled(false) mutes sounds
   - [ ] Setting persists across app restarts
   - [ ] GameProvider sound setting syncs with SoundService

### Animation Tests

1. **ConfettiAnimation**
   - [ ] Particles appear on screen
   - [ ] Particles fall with gravity simulation
   - [ ] Particles fade out over time
   - [ ] Animation completes callback is called
   - [ ] No jank on 60fps devices

2. **StarAnimation**
   - [ ] Stars pop in sequence with delay
   - [ ] Each star uses elastic curve animation
   - [ ] Correct number of stars displayed (1-3)
   - [ ] onComplete callback fires after all stars animate

3. **PointPopAnimation**
   - [ ] Point value displays correctly
   - [ ] Text floats upward
   - [ ] Text fades out smoothly
   - [ ] Scale animation creates pop effect
   - [ ] Shadow renders properly

4. **StreakFireAnimation**
   - [ ] Fire emoji scales in
   - [ ] Fire emoji rotates smoothly
   - [ ] Multiple fire emojis display correctly
   - [ ] onComplete callback fires

## Integration Tests

### Study Screen

1. **Correct Answer Path**
   - [ ] Select correct spelling option
   - [ ] Correct answer sound plays
   - [ ] "+1 point" animation appears
   - [ ] Point pop animation floats up and fades
   - [ ] Icon shows success (checkmark)
   - [ ] "Great job!" message displays

2. **Incorrect Answer Path**
   - [ ] Select incorrect spelling option
   - [ ] Incorrect answer buzz sound plays
   - [ ] Correct spelling is shown
   - [ ] "Try again!" message displays
   - [ ] No point animation shows

3. **Level Completion**
   - [ ] CompletionDialog appears with scale animation
   - [ ] Level complete fanfare sound plays
   - [ ] Star rating animates (pop-in sequence)
   - [ ] Confetti particles shower the dialog
   - [ ] Confetti fades after 3 seconds
   - [ ] Points earned display correctly
   - [ ] Accuracy percentage displays

4. **Sound Toggle Integration**
   - [ ] Go to Profile screen
   - [ ] Toggle Sound off
   - [ ] Return to Study screen
   - [ ] Answer a question - NO sound plays
   - [ ] Complete level - NO sound plays
   - [ ] Toggle Sound back on
   - [ ] Sounds work again

### Profile Screen

1. **Sound Setting**
   - [ ] Sound toggle appears in Settings section
   - [ ] Toggle shows current sound state
   - [ ] Toggling off/on changes SoundService state
   - [ ] Setting persists after app restart

2. **Cosmetic Equipping**
   - [ ] Tap "Equip" button on cosmetic
   - [ ] Cosmetic unlock sound plays
   - [ ] Success message shows
   - [ ] Item marked as "Equipped"

### Rewards Shop

1. **Point Redemption**
   - [ ] View available cosmetics
   - [ ] Click "Redeem" button
   - [ ] Confirmation dialog appears
   - [ ] Confirm redemption
   - [ ] Point redemption sound plays
   - [ ] Item now appears in "My Cosmetics"
   - [ ] Points balance updates

## Platform-Specific Tests

### Android Testing

```bash
flutter run -d <device_id>
```

Test Cases:
- [ ] App launches without audio errors
- [ ] All sounds play through speaker
- [ ] Switching audio to headphones works
- [ ] Animations smooth on various screen sizes
- [ ] Animations smooth on various API levels (minimum API 21)
- [ ] System volume controls affect sound
- [ ] Sound works after device lock/unlock

### iOS Testing

```bash
flutter run -d iphone
```

Test Cases:
- [ ] App launches without audio errors
- [ ] Sounds play through speaker
- [ ] Sounds respect device mute toggle
- [ ] Animations smooth on iPhone (various models)
- [ ] Audio device switching works (speaker ↔ headphones)
- [ ] Background audio settings respected

### Web Testing (Chrome)

```bash
flutter run -d chrome
```

Test Cases:
- [ ] Open DevTools (F12) → Console
- [ ] App loads without errors
- [ ] First interaction enables audio playback
- [ ] All sounds play through browser
- [ ] Animations smooth on 60fps browser
- [ ] No CORS errors for audio files
- [ ] Sound works after page refresh
- [ ] Check Network tab for audio file loading

### Web Testing (Firefox)

```bash
flutter run -d firefox
```

Test Cases:
- [ ] Same as Chrome tests above
- [ ] Audio API compatibility verified
- [ ] Performance acceptable on Firefox

### Web Testing (Safari)

Safari web testing (if supported):
- [ ] Audio plays (may require user interaction)
- [ ] Animations perform well
- [ ] No console errors

### Desktop (Windows/macOS/Linux)

```bash
flutter run -d windows  # or -d macos, -d linux
```

Test Cases:
- [ ] App launches
- [ ] All sounds play
- [ ] Volume respects system settings
- [ ] Animations smooth
- [ ] No platform-specific errors

## Performance Tests

### Animation Performance

Use Flutter DevTools Profiler:

```bash
flutter run --profile
```

1. **Start a level**
   - [ ] Frame rate stays ≥50fps during gameplay
   - [ ] No jank when playing sounds
   - [ ] No spikes during answer feedback

2. **Level Completion**
   - [ ] Frame rate stays ≥50fps during confetti
   - [ ] Particles don't exceed 50 count default
   - [ ] Dialog animation smooth (≥60fps)

### Memory Usage

Using DevTools Memory tab:
- [ ] Initial memory: <100MB
- [ ] After playing sounds: <110MB
- [ ] After animations: <110MB
- [ ] No memory leaks after 10+ level completions

### Audio Loading

Using DevTools Network tab (web):
- [ ] Each audio file loads within 1 second
- [ ] Audio files not re-downloaded after first load
- [ ] Cached successfully for offline use

## Stress Tests

1. **Rapid Answers**
   - [ ] Answer 10+ questions quickly
   - [ ] No audio overlap/distortion
   - [ ] Animations don't queue up
   - [ ] App remains responsive

2. **Multiple Completions**
   - [ ] Complete 5 levels in succession
   - [ ] Each completion plays full animation/sound
   - [ ] No performance degradation
   - [ ] No resource leaks

3. **Sound Toggle Cycling**
   - [ ] Toggle sound on/off 10+ times quickly
   - [ ] App stays responsive
   - [ ] Setting change always reflected immediately

4. **Web Audio Context**
   - [ ] Test in Firefox and Chrome
   - [ ] Sounds play after tab is hidden/shown
   - [ ] No Audio Context failures

## Edge Cases

1. **No Sound Files**
   - [ ] Delete all sound files
   - [ ] App continues to work
   - [ ] No crashes or errors
   - [ ] Animations still play
   - [ ] Check console for graceful handling

2. **Sound Disabled + Animations**
   - [ ] Disable sound in Profile
   - [ ] Start level, complete it
   - [ ] Animations still display
   - [ ] Only sounds are muted

3. **Low Memory Device**
   - [ ] Test on low-end Android device
   - [ ] Reduce confetti particles in code
   - [ ] Animations still smooth
   - [ ] No OutOfMemory errors

4. **Network Interruption (Web)**
   - [ ] Start app, disable internet
   - [ ] Audio files already cached play fine
   - [ ] Animations work without internet
   - [ ] Graceful fallback for missing audio

## Regression Tests

Run after any code changes:

```bash
# Build tests
flutter test

# Run app
flutter run

# Manual test flow:
# 1. Answer 3 questions (verify sounds)
# 2. Complete level (verify fanfare + animations)
# 3. Go to Profile (verify sound toggle)
# 4. Toggle sound off, complete another level
# 5. Toggle sound on, verify it works again
```

## Test Report Template

```
Platform: [Android/iOS/Web/Desktop]
Device: [Model/Browser]
Flutter Version: [Version]
Test Date: [Date]

PASS/FAIL: ____

Test Results:
- Sound Effects: ✓/✗
  - Correct Answer: ✓/✗
  - Incorrect Answer: ✓/✗
  - Level Complete: ✓/✗
  - Cosmetic Unlock: ✓/✗
  - Point Redemption: ✓/✗

- Animations: ✓/✗
  - Confetti: ✓/✗
  - Stars: ✓/✗
  - Point Pop: ✓/✗
  - Streak Fire: ✓/✗

- Settings: ✓/✗
  - Sound Toggle: ✓/✗
  - Persistence: ✓/✗

Issues Found:
[List any issues]

Performance:
- Average FPS: __
- Memory Usage: __MB
- Audio Latency: __ms

Recommendations:
[Any adjustments needed]
```

## Automated Testing

Create unit tests for SoundService:

```dart
void main() {
  group('SoundService', () {
    test('initializes without errors', () async {
      final soundService = SoundService();
      await soundService.init();
      expect(soundService.isSoundEnabled, true);
    });

    test('respects sound_enabled setting', () async {
      final soundService = SoundService();
      await soundService.init();
      await soundService.setSoundEnabled(false);
      expect(soundService.isSoundEnabled, false);
    });
  });
}
```

## Continuous Integration

Add to CI/CD pipeline:

```yaml
- name: Run Flutter tests
  run: flutter test

- name: Build Android
  run: flutter build apk

- name: Build iOS
  run: flutter build ios

- name: Build Web
  run: flutter build web

- name: Analyze code
  run: flutter analyze
```

## Success Criteria

- [ ] All sounds play on all platforms
- [ ] All animations render smoothly (≥50fps)
- [ ] Sound toggle works correctly
- [ ] No crashes or errors
- [ ] Performance acceptable (<150MB memory)
- [ ] Web audio works in Chrome and Firefox
- [ ] Settings persist across restarts
- [ ] App gracefully handles missing audio files

## Sign-Off

- Tester: ________________
- Date: __________________
- Overall Status: PASS / FAIL

## Issues to Track

| ID | Issue | Severity | Platform | Status |
|----|-------|----------|----------|--------|
|    |       |          |          |        |

---

For detailed information, see `SOUND_AND_ANIMATION_GUIDE.md`
