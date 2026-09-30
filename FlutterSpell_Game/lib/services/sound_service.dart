import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_tts_service.dart';

/// Service to manage all sound effects in the app
class SoundService {
  static final SoundService _instance = SoundService._internal();

  /// Set by the app root (see main.dart) to surface a one-time in-app
  /// notice when word pronunciation had to fall back to the browser's
  /// built-in voice - otherwise a backend TTS outage degrades silently
  /// with no indication to the user of why the voice sounds different.
  static void Function(String message)? onNotice;
  bool _ttsFallbackNoticeShown = false;

  AudioPlayer? _audioPlayer;
  FlutterTts? _flutterTts;
  late SharedPreferences _prefs;
  bool _soundEnabled = true;
  bool _ttsInitialized = false;
  bool _webAudioUnlocked = false;

  factory SoundService() {
    return _instance;
  }

  SoundService._internal();

  /// Initialize the sound service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _soundEnabled = _prefs.getBool('sound_enabled') ?? true;
    _initializeAudioIfNeeded();
    for (final prefix in ['en', 'zh']) {
      final name = _prefs.getString('tts_voice_$prefix');
      if (name != null) {
        _preferredVoices[prefix] = name;
        _preferredLocales[prefix] =
            _prefs.getString('tts_voice_locale_$prefix') ?? '';
      }
      if (kIsWeb) setPreferredWebVoice(prefix, name);
    }
  }

  // Voice chosen by the user per language prefix ('en' / 'zh'), name only.
  final Map<String, String> _preferredVoices = {};
  final Map<String, String> _preferredLocales = {};

  String? preferredVoice(String langPrefix) => _preferredVoices[langPrefix];

  /// Lists local TTS voices as `{name, locale}` maps, sorted by name.
  Future<List<Map<String, String>>> getAvailableVoices() async {
    List<Map<String, String>> result = [];
    if (kIsWeb) {
      result = (await getWebVoices())
          .map((v) => {'name': v['name']!, 'locale': v['lang']!})
          .toList();
    } else {
      try {
        _flutterTts ??= FlutterTts();
        final raw = await _flutterTts!.getVoices;
        if (raw is List) {
          for (final v in raw) {
            if (v is Map && v['name'] != null) {
              result.add({
                'name': v['name'].toString(),
                'locale': (v['locale'] ?? '').toString(),
              });
            }
          }
        }
      } catch (e) {
        debugPrint('SoundService: failed to list voices: $e');
      }
    }
    result.sort((a, b) => a['name']!.compareTo(b['name']!));
    return result;
  }

  /// Saves (and applies) the voice for [langPrefix]; null restores default.
  Future<void> setPreferredVoice(
      String langPrefix, String? name, String? locale) async {
    _prefs = await SharedPreferences.getInstance();
    if (name == null) {
      _preferredVoices.remove(langPrefix);
      _preferredLocales.remove(langPrefix);
      await _prefs.remove('tts_voice_$langPrefix');
      await _prefs.remove('tts_voice_locale_$langPrefix');
    } else {
      _preferredVoices[langPrefix] = name;
      _preferredLocales[langPrefix] = locale ?? '';
      await _prefs.setString('tts_voice_$langPrefix', name);
      await _prefs.setString('tts_voice_locale_$langPrefix', locale ?? '');
    }
    if (kIsWeb) setPreferredWebVoice(langPrefix, name);
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

  static final RegExp _chineseChar = RegExp(r'[一-鿿]');

  /// Initialize TTS settings
  Future<void> _initTts() async {
    if (_flutterTts == null) return;
    try {
      // Set default language to English (US); playWordPronunciation swaps
      // to zh-CN per-utterance for Chinese text.
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

  /// Primes audio/speech playback from inside a real user gesture (e.g. the
  /// app's first tap). Browsers — iOS Safari in particular, Firefox more
  /// loosely — block audio and speechSynthesis triggered outside a direct
  /// gesture, and this app often starts playback from a post-frame callback
  /// (auto-advancing to the next word) rather than a tap. Call this from a
  /// gesture handler once per session so that later programmatic playback
  /// isn't silently dropped.
  void unlockAudioForWeb() {
    if (!kIsWeb || _webAudioUnlocked) return;
    _webAudioUnlocked = true;
    try {
      unlockAudioForGesture();
    } catch (e) {
      debugPrint('SoundService: audio unlock failed: $e');
    }
    // Use a throwaway player rather than the shared _audioPlayer: reusing
    // the same instance every tap would steal it from whatever real sound
    // effect or word audio happens to be playing/about to play, since an
    // AudioPlayer can only have one active source at a time.
    final unlockPlayer = AudioPlayer();
    unlockPlayer
        .play(AssetSource('sounds/pop.wav'), volume: 0)
        .catchError((e) {
      debugPrint('SoundService: sound-effect unlock failed: $e');
    }).whenComplete(() => unlockPlayer.dispose());
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

  /// Play word pronunciation using Text-to-Speech.
  ///
  /// On web, flutter_tts just wraps the browser's speechSynthesis, which is
  /// unreliable on iOS Safari (missing/robotic voices, especially for
  /// Chinese) — so web uses Google Cloud TTS via the backend instead, with
  /// speechSynthesis only as a fallback (see web_tts_web.dart). Native
  /// Android/iOS apps keep using flutter_tts directly since they have
  /// proper OS-level TTS engines.
  Future<void> playWordPronunciation(String word) async {
    if (!_soundEnabled) return;
    if (kIsWeb) {
      final usedFallback = await speakOnWeb(word);
      if (usedFallback) _notifyTtsFallbackOnce();
      return;
    }
    if (!_ttsInitialized || _flutterTts == null) return;
    try {
      final isChinese = _chineseChar.hasMatch(word);
      final prefix = isChinese ? 'zh' : 'en';
      await _flutterTts!.setLanguage(isChinese ? "zh-CN" : "en-US");
      final voice = _preferredVoices[prefix];
      if (voice != null) {
        final locale = _preferredLocales[prefix] ??
            _prefs.getString('tts_voice_locale_$prefix') ??
            '';
        await _flutterTts!.setVoice({'name': voice, 'locale': locale});
      }
      await _flutterTts!.speak(word);
    } catch (e) {
      // TTS playback failed, but app continues gracefully
      debugPrint('SoundService: native TTS playback failed: $e');
    }
  }

  void _notifyTtsFallbackOnce() {
    if (_ttsFallbackNoticeShown) return;
    _ttsFallbackNoticeShown = true;
    onNotice?.call(
      "Using built-in voice",
    );
  }

  /// Internal method to play a sound by name
  Future<void> _playSound(String soundName) async {
    if (_audioPlayer == null) return;
    try {
      // Try to play from assets first
      await _audioPlayer!.play(
        AssetSource('sounds/$soundName.wav'),
      );
    } catch (e) {
      // Silently fail if sound file not found, but surface it in the
      // console — this used to be swallowed entirely, which made browser
      // autoplay-policy failures (e.g. on Firefox) invisible.
      debugPrint('SoundService: failed to play sound "$soundName": $e');
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
