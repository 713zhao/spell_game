Future<bool> speakOnWeb(String word) async {
  // No-op on non-web platforms — SoundService uses flutter_tts directly there.
  return false;
}

void unlockAudioForGesture() {
  // No-op on non-web platforms — no autoplay-gesture restrictions to work around.
}

/// Local voices are enumerated through flutter_tts on native platforms.
Future<List<Map<String, String>>> getWebVoices() async => const [];

void setPreferredWebVoice(String langPrefix, String? voiceName) {}
