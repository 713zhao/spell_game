/// Non-web fallback: continuous speech recognition isn't wired up for
/// native platforms yet.
class SpeechListener {
  static bool get supported => false;

  bool start({
    required String lang,
    required void Function(String transcript) onTranscript,
    void Function()? onError,
  }) => false;

  void stop() {}
}
