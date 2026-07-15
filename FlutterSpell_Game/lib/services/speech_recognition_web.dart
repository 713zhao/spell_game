import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// Records one short utterance via the browser's Web Speech API
/// (SpeechRecognition / webkitSpeechRecognition) and returns the
/// recognized text, or null if the API isn't available in this browser,
/// the user denied mic access, nothing was recognized, or it timed out.
Future<String?> recognizeSpeech({
  String lang = 'zh-CN',
  Duration timeout = const Duration(seconds: 8),
}) async {
  final ctor = js_util.getProperty(html.window, 'SpeechRecognition') ??
      js_util.getProperty(html.window, 'webkitSpeechRecognition');
  if (ctor == null) return null;

  Object recognition;
  try {
    recognition = js_util.callConstructor(ctor, []);
  } catch (_) {
    return null;
  }

  final completer = Completer<String?>();
  void finish(String? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  try {
    js_util.setProperty(recognition, 'lang', lang);
    js_util.setProperty(recognition, 'continuous', false);
    js_util.setProperty(recognition, 'interimResults', false);
    js_util.setProperty(recognition, 'maxAlternatives', 1);

    js_util.setProperty(
      recognition,
      'onresult',
      js_util.allowInterop((event) {
        try {
          final results = js_util.getProperty(event, 'results');
          final first = js_util.callMethod(results, 'item', [0]);
          final alt = js_util.callMethod(first, 'item', [0]);
          finish(js_util.getProperty(alt, 'transcript') as String?);
        } catch (_) {
          finish(null);
        }
      }),
    );
    js_util.setProperty(
      recognition,
      'onerror',
      js_util.allowInterop((event) => finish(null)),
    );
    js_util.setProperty(
      recognition,
      'onend',
      js_util.allowInterop((event) => finish(null)),
    );

    js_util.callMethod(recognition, 'start', []);
  } catch (_) {
    return null;
  }

  return completer.future.timeout(
    timeout,
    onTimeout: () {
      try {
        js_util.callMethod(recognition, 'stop', []);
      } catch (_) {}
      return null;
    },
  );
}
