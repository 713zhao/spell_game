import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage all sound effects in the app
class SoundService {
  static final SoundService _instance = SoundService._internal();

  late AudioPlayer _audioPlayer;
  late SharedPreferences _prefs;
  bool _soundEnabled = true;

  factory SoundService() {
    return _instance;
  }

  SoundService._internal();

  /// Initialize the sound service
  Future<void> init() async {
    _audioPlayer = AudioPlayer();
    _prefs = await SharedPreferences.getInstance();
    _soundEnabled = _prefs.getBool('sound_enabled') ?? true;
  }

  /// Update sound enabled setting
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _prefs.setBool('sound_enabled', enabled);
  }

  /// Check if sound is enabled
  bool get isSoundEnabled => _soundEnabled;

  /// Play correct answer chime
  Future<void> playCorrectAnswer() async {
    if (!_soundEnabled) return;
    await _playSound('correct_answer');
  }

  /// Play incorrect answer buzz
  Future<void> playIncorrectAnswer() async {
    if (!_soundEnabled) return;
    await _playSound('incorrect_answer');
  }

  /// Play level completion fanfare
  Future<void> playLevelComplete() async {
    if (!_soundEnabled) return;
    await _playSound('level_complete');
  }

  /// Play streak milestone sound
  Future<void> playStreakMilestone() async {
    if (!_soundEnabled) return;
    await _playSound('streak_milestone');
  }

  /// Play cosmetic unlock/equip sound
  Future<void> playCosmeticUnlock() async {
    if (!_soundEnabled) return;
    await _playSound('cosmetic_unlock');
  }

  /// Play point redemption sound
  Future<void> playPointRedemption() async {
    if (!_soundEnabled) return;
    await _playSound('point_redemption');
  }

  /// Play generic pop/achievement sound
  Future<void> playPop() async {
    if (!_soundEnabled) return;
    await _playSound('pop');
  }

  /// Internal method to play a sound by name
  Future<void> _playSound(String soundName) async {
    try {
      // Try to play from assets first
      await _audioPlayer.play(
        AssetSource('sounds/$soundName.mp3'),
      );
    } catch (e) {
      // Silently fail if sound file not found
      // In production, this would be logged
    }
  }

  /// Stop current sound
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Dispose the audio player
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
