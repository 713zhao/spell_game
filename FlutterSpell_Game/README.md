# Spell Academy

A game-based spelling app for kids (ages 6-10) built with Flutter. Part of the Spell Learning Platform.

## Overview

Spell Academy transforms spelling practice into an engaging adventure game, inspired by Duolingo's reward loop mechanics. Kids progress through levels, earn rewards, and compete on leaderboards.

## Features

- 🎮 **Level-based gameplay** - Progress through increasingly challenging spelling levels
- 🏆 **Reward system** - Earn points and cosmetic rewards for correct spelling
- 🔥 **Daily streaks** - Maintain daily login streaks for bonus multipliers
- 🎵 **Audio support** - Listen to word pronunciations (using audioplayers)
- ✨ **Animated rewards** - Celebration animations using Lottie
- 📊 **Leaderboards** - Compete with friends and classmates

## Tech Stack

- **Framework:** Flutter (iOS, Android, Web)
- **State Management:** Provider
- **HTTP:** http package
- **Audio:** audioplayers ^5.0.0 (compatible with http ^1.1.0)
- **Animations:** Lottie
- **Local Storage:** shared_preferences
- **JSON:** json_serializable

## Getting Started

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0

### Installation

1. Clone the repository
2. Navigate to the project directory:
   ```bash
   cd FlutterSpell_Game
   ```
3. Get dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

**Development (local/emulator):**
```bash
flutter run -d chrome  # Web
flutter run            # Mobile (Android/iOS)
```

**Release build:**
```bash
flutter build apk --release    # Android
flutter build ios --release    # iOS
flutter build web --release    # Web
```

## Project Structure

```
lib/
├── main.dart           # App entry point
├── screens/            # Screen/page components
├── widgets/            # Reusable UI widgets
├── services/           # Business logic & API calls
├── models/             # Data models
└── providers/          # State management (Provider)

assets/
├── sounds/             # Game sound effects
└── animations/         # Lottie animation files
```

## Architecture

### State Management (Provider)
The app uses the Provider package for reactive state management. Game state, user progress, and UI state are managed through ChangeNotifier providers.

### API Integration
The app connects to the Spell Backend API (FastAPI) for:
- User management
- Level progression
- Reward system
- Leaderboard queries

### Asset Loading
- **Sounds** (assets/sounds/): Game SFX, voice guidance
- **Animations** (assets/animations/): Celebration effects, transitions

## Development Notes

### Dependency Versions
- **audioplayers ^5.0.0**: Required for compatibility with http ^1.1.0 (both specified in plan)
- **provider ^6.0.0**: Recommended for state management across screens

## Testing

Unit and widget tests should be added in the `test/` directory. Run tests with:
```bash
flutter test
```

## Future Enhancements

- [ ] Speech recognition for pronunciation practice
- [ ] OCR for real-world word detection
- [ ] Parent/teacher dashboard
- [ ] Offline mode
- [ ] Custom word lists

## Contributing

See CONTRIBUTING.md for guidelines.

## License

MIT License - See LICENSE file for details.
