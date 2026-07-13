import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service to manage all sound effects in the app
class SoundService {
  static final SoundService _instance = SoundService._internal();

  AudioPlayer? _audioPlayer;
  FlutterTts? _flutterTts;
  late SharedPreferences _prefs;
  bool _soundEnabled = true;
  bool _ttsInitialized = false;

  factory SoundService() {
    return _instance;
  }

  SoundService._internal();

  /// Initialize the sound service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _soundEnabled = _prefs.getBool('sound_enabled') ?? true;
    // Skip audio initialization on web
    if (kIsWeb) return;
    _initializeAudioIfNeeded();
  }

  void _initializeAudioIfNeeded() {
    try {
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
      }
    } catch (e) {
      // AudioPlayer initialization failed
    }
    try {
      if (_flutterTts == null) {
        _flutterTts = FlutterTts();
      }
    } catch (e) {
      // FlutterTts initialization failed
    }
    _initTts();
  }

  /// Initialize TTS settings
  Future<void> _initTts() async {
    if (_flutterTts == null) return;
    try {
      // Set default language to English (US)
      await _flutterTts!.setLanguage("en-US");
      // Set speech rate (0.0 to 2.0, where 1.0 is normal)
      await _flutterTts!.setSpeechRate(0.5);
      // Set pitch (0.5 to 2.0, where 1.0 is normal)
      await _flutterTts!.setPitch(1.0);
      _ttsInitialized = true;
    } catch (e) {
      // TTS initialization failed, but app continues
      _ttsInitialized = false;
    }
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

  /// Play word pronunciation using Text-to-Speech
  Future<void> playWordPronunciation(String word) async {
    if (!_soundEnabled || !_ttsInitialized || _flutterTts == null) return;
    try {
      await _flutterTts!.speak(word);
    } catch (e) {
      // TTS playback failed, but app continues gracefully
      // In production, this would be logged
    }
  }

  /// Internal method to play a sound by name
  Future<void> _playSound(String soundName) async {
    if (_audioPlayer == null) return;
    try {
      // Try to play from assets first
      await _audioPlayer!.play(
        AssetSource('sounds/$soundName.mp3'),
      );
    } catch (e) {
      // Silently fail if sound file not found
      // In production, this would be logged
    }
  }

  /// Stop current sound
  Future<void> stop() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.stop();
    }
  }

  /// Dispose the audio player and TTS
  Future<void> dispose() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.dispose();
    }
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
  }
}
