/// Non-web fallback: speech recognition isn't wired up for native
/// platforms yet, so callers fall back to the self-report path.
Future<String?> recognizeSpeech({
  String lang = 'zh-CN',
  Duration timeout = const Duration(seconds: 8),
}) async {
  return null;
}
