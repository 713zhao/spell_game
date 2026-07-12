# Quick Start: Audio & Animation Testing

## Pre-requisites

- Flutter SDK installed
- `flutter pub get` already run
- Audio files ready (see options below)

## Option 1: Generate Test Audio Files (Recommended for Dev)

Generate simple WAV files for testing:

```bash
python generate_test_sounds.py
```

This creates 7 test sound files in `assets/sounds/`:
- correct_answer.wav
- incorrect_answer.wav
- level_complete.wav
- streak_milestone.wav
- cosmetic_unlock.wav
- point_redemption.wav
- pop.wav

**Note**: These are minimal test sounds. Replace with professional audio for production.

## Option 2: Use Existing Audio Files

If you have audio files, place them in `assets/sounds/` with these names:
- correct_answer.mp3 (or .wav)
- incorrect_answer.mp3
- level_complete.mp3
- streak_milestone.mp3
- cosmetic_unlock.mp3
- point_redemption.mp3
- pop.mp3

## Option 3: Skip Audio (Testing Animations Only)

Animations work independently. The app won't crash without sound files.

## Running the App

```bash
# Build and run
flutter run

# Run on web
flutter run -d chrome

# Run on iOS
flutter run -d iphone

# Run on Android
flutter run -d android
```

## Testing Audio

### Manual Testing

1. Navigate to Profile screen
2. Ensure "Sound" toggle is enabled
3. Start a level on the Study screen
4. Answer questions to hear:
   - Correct answer chime
   - Incorrect answer buzz
5. Complete level to hear:
   - Level complete fanfare
   - See star animations
   - See confetti particles
6. Try redeeming cosmetics to hear redemption sound

### Automated Testing (AudioTestWidget)

Add to your app temporarily to test all sounds:

```dart
// Example: Add to Profile screen's debug menu
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AudioTestWidget()),
    );
  },
  child: const Text('Test Audio'),
)
```

## Troubleshooting

### No Sound
- Check device volume is not muted
- Verify sound files exist in `assets/sounds/`
- Check Profile > Sound toggle is enabled
- Look for errors in Flutter console

### Web Audio Not Working
- Check browser console (F12) for errors
- Ensure browser audio is enabled
- Try different browser (Chrome, Firefox)
- Check file paths in network tab

### Animations Stuttering
- Close background apps
- Try on a different device
- Check CPU/GPU usage
- Reduce animation complexity if needed

### App Crashes
- Run `flutter clean`
- Run `flutter pub get`
- Rebuild the app
- Check Flutter console for error details

## Development Notes

### Adding More Sounds

Edit `lib/services/sound_service.dart`:

```dart
Future<void> playMyNewSound() async {
  if (!_soundEnabled) return;
  await _playSound('my_new_sound');
}
```

Add file: `assets/sounds/my_new_sound.mp3`

### Customizing Animations

All widgets expose configuration parameters:

```dart
// Adjust confetti particles
ConfettiAnimation(
  pieceCount: 100, // More particles
  duration: const Duration(seconds: 5), // Longer duration
)

// Adjust star animation
StarAnimation(
  starCount: 3,
  delayBetweenStars: const Duration(milliseconds: 300), // More delay
)
```

### Disabling Specific Sounds

Comment out in `SoundService`:

```dart
// Future<void> playCorrectAnswer() async {
//   if (!_soundEnabled) return;
//   await _playSound('correct_answer');
// }
```

## Performance Tips

1. Use low-quality audio files (64kbps MP3) to save size
2. Test on actual devices, not just emulators
3. Monitor performance with Android Studio Profiler
4. Reduce animation particle count on low-end devices

## Platform Specific Notes

### Android
- Sound works on emulator and device
- Use speaker or headphones for audio
- Mute button respects app settings

### iOS
- Test on actual device for best results
- Audio plays through device speaker
- Respects system mute toggle

### Web
- Audio requires user interaction first
- Test with a simple level completion
- Check browser developer tools for audio errors

### macOS/Linux/Windows
- Requires system audio device
- Test with headphones and speakers
- Volume follows system settings

## Next Steps

1. Generate or add sound files
2. Run the app and test manually
3. Use AudioTestWidget for comprehensive testing
4. Review console output for any warnings
5. Test on all target platforms
6. Replace test audio with professional recordings
7. Deploy to production

## Resources

- Flutter Audio: https://pub.dev/packages/audioplayers
- Sound Effects Library: https://freesound.org
- Web Audio API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API
- Flutter Animations: https://flutter.dev/docs/development/ui/animations

## Support

For issues, check:
1. `SOUND_AND_ANIMATION_GUIDE.md` - Detailed documentation
2. Flutter console for error messages
3. Browser console (web debugging)
4. Platform-specific logs (Android/iOS)
