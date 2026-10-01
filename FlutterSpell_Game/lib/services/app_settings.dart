import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local settings (persisted in SharedPreferences, not per user).
class AppSettings {
  /// Whether handwriting exercises show a "Skip" button. On by default.
  static final ValueNotifier<bool> showSkipWriting = ValueNotifier<bool>(true);

  static const _skipKey = 'show_skip_writing';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showSkipWriting.value = prefs.getBool(_skipKey) ?? true;
    await loadDictation();
  }

  static Future<void> setShowSkipWriting(bool value) async {
    showSkipWriting.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skipKey, value);
  }

  /// Spell (dictation) player: times each word is read, and the pause
  /// between reads, in seconds.
  static final ValueNotifier<int> dictationRepeat = ValueNotifier<int>(3);
  static final ValueNotifier<int> dictationInterval = ValueNotifier<int>(5);

  static Future<void> loadDictation() async {
    final prefs = await SharedPreferences.getInstance();
    dictationRepeat.value = prefs.getInt('dictation_repeat') ?? 3;
    dictationInterval.value = prefs.getInt('dictation_interval') ?? 5;
  }

  static Future<void> setDictation({int? repeat, int? interval}) async {
    final prefs = await SharedPreferences.getInstance();
    if (repeat != null) {
      dictationRepeat.value = repeat;
      await prefs.setInt('dictation_repeat', repeat);
    }
    if (interval != null) {
      dictationInterval.value = interval;
      await prefs.setInt('dictation_interval', interval);
    }
  }
}
