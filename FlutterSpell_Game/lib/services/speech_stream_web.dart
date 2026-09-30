import 'dart:html' as html;
import 'dart:js_util' as js_util;

/// Continuous browser speech recognition (Web Speech API). Emits the full
/// transcript of the current recognition session, including interim
/// results, every time it changes. Chrome ends sessions after a stretch of
/// silence, so it restarts itself until [stop] is called; each new session
/// starts with an empty transcript.
class SpeechListener {
  Object? _recognition;
  bool _active = false;

  static bool get supported =>
      (js_util.getProperty<Object?>(html.window, 'SpeechRecognition') ??
          js_util.getProperty<Object?>(html.window, 'webkitSpeechRecognition')) !=
      null;

  bool start({
    required String lang,
    required void Function(String transcript) onTranscript,
    void Function()? onError,
  }) {
    stop();
    final ctor =
        js_util.getProperty<Object?>(html.window, 'SpeechRecognition') ??
        js_util.getProperty<Object?>(html.window, 'webkitSpeechRecognition');
    if (ctor == null) return false;
    _active = true;

    void begin() {
      if (!_active) return;
      Object rec;
      try {
        rec = js_util.callConstructor(ctor, []);
      } catch (_) {
        onError?.call();
        return;
      }
      _recognition = rec;
      js_util.setProperty(rec, 'lang', lang);
      js_util.setProperty(rec, 'continuous', true);
      js_util.setProperty(rec, 'interimResults', true);
      js_util.setProperty(
        rec,
        'onresult',
        js_util.allowInterop((event) {
          try {
            final results = js_util.getProperty<Object>(event, 'results');
            final n = js_util.getProperty<int>(results, 'length');
            final buf = StringBuffer();
            for (var i = 0; i < n; i++) {
              final r = js_util.callMethod<Object>(results, 'item', [i]);
              final alt = js_util.callMethod<Object>(r, 'item', [0]);
              buf.write(js_util.getProperty<String>(alt, 'transcript'));
              buf.write(' ');
            }
            onTranscript(buf.toString());
          } catch (_) {}
        }),
      );
      js_util.setProperty(
        rec,
        'onerror',
        js_util.allowInterop((event) {
          final err = js_util.getProperty<Object?>(event, 'error');
          // "no-speech"/"aborted" are routine; denied mic access is fatal.
          if (err == 'not-allowed' || err == 'service-not-allowed') {
            _active = false;
            onError?.call();
          }
        }),
      );
      js_util.setProperty(
        rec,
        'onend',
        js_util.allowInterop((event) {
          if (_active) {
            Future.delayed(const Duration(milliseconds: 200), begin);
          }
        }),
      );
      try {
        js_util.callMethod(rec, 'start', []);
      } catch (_) {
        onError?.call();
      }
    }

    begin();
    return true;
  }

  void stop() {
    _active = false;
    final rec = _recognition;
    _recognition = null;
    if (rec != null) {
      try {
        js_util.callMethod(rec, 'abort', []);
      } catch (_) {}
    }
  }
}
