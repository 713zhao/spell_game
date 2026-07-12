# Sound Effects for Spell Adventure

This directory contains sound effect files for the Spell Adventure game. The following sound files should be added:

## Required Sound Files

All files should be in MP3 or WAV format:

1. **correct_answer.mp3** - Short, uplifting chime for correct answers
   - Duration: 0.5-1 second
   - Suggested: Bright piano note or chime sound

2. **incorrect_answer.mp3** - Low, brief buzz for incorrect answers
   - Duration: 0.3-0.5 second
   - Suggested: Low beep or error sound

3. **level_complete.mp3** - Celebratory fanfare for level completion
   - Duration: 1-2 seconds
   - Suggested: Triumphant trumpet or victory fanfare

4. **streak_milestone.mp3** - Special sound for streak milestones
   - Duration: 0.8-1.5 seconds
   - Suggested: Power-up or achievement sound

5. **cosmetic_unlock.mp3** - Sound for unlocking/equipping cosmetics
   - Duration: 0.6-1 second
   - Suggested: Magical sparkle or unlock sound

6. **point_redemption.mp3** - Sound for redeeming points in shop
   - Duration: 0.6-1 second
   - Suggested: Coin clink or purchase sound

7. **pop.mp3** - Generic pop/achievement sound
   - Duration: 0.3-0.5 second
   - Suggested: Bubble pop or click sound

## Implementation Notes

- Sound files are loaded from the assets/sounds/ directory
- The SoundService automatically checks the `sound_enabled` setting from SharedPreferences
- If sound files are missing, the app gracefully continues without audio (no crashes)
- Sound effects are played through the `audioplayers: ^5.0.0` package
- Web platform support is built-in through the audioplayers package

## Audio Testing

To verify audio works on all platforms:
- **Android/iOS**: Test on physical device with volume enabled
- **Web**: Test in Firefox and Chrome, check browser console for audio errors
- **Desktop**: Test sound output through system speakers

## Future Enhancement

Consider adding:
- Background music for menu screens
- Custom volume control per sound type
- Haptic feedback for additional tactile feedback
