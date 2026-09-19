Future<bool> speakOnWeb(String word) async {
  // No-op on non-web platforms — SoundService uses flutter_tts directly there.
  return false;
}

void unlockAudioForGesture() {
  // No-op on non-web platforms — no autoplay-gesture restrictions to work around.
}
