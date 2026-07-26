import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import '../config/api_config.dart';

// Ported from FlutterSpell (lib/services/tts_web.dart): mobile browsers
// (iOS Safari especially) either lack decent built-in TTS voices or lack
// Chinese voices entirely, so prefer Google Cloud TTS there and only fall
// back to speechSynthesis if that fails. Desktop browsers already have
// reasonable voices, so skip the network round-trip and use them directly.

html.AudioElement? _currentAudio;

bool _isMobileDevice() {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('android');
}

Future<void> speakOnWeb(String word) async {
  _stopCurrent();

  if (_isMobileDevice()) {
    final played = await _tryGoogleTts(word);
    if (!played) {
      await _speakWithBrowserTts(word);
    }
  } else {
    await _speakWithBrowserTts(word);
  }
}

void _stopCurrent() {
  if (_currentAudio != null) {
    _currentAudio!.pause();
    _currentAudio!.currentTime = 0;
    _currentAudio = null;
  }
  try {
    final synth = js_util.getProperty(js_util.globalThis, 'speechSynthesis');
    js_util.callMethod(synth, 'cancel', []);
  } catch (_) {
    // speechSynthesis not available in this browser
  }
}

/// Unlike the FlutterSpell original this is ported from, this listens for
/// the audio element's error event (not just canPlay) so a failed/500
/// backend response falls back to browser TTS immediately instead of
/// hanging forever waiting for a "can play" event that never fires.
Future<bool> _tryGoogleTts(String word) async {
  try {
    final isChinese = RegExp(r'[一-鿿]').hasMatch(word);
    final lang = isChinese ? 'zh-CN' : 'en-US';
    final encodedWord = Uri.encodeComponent(word);
    final url = '${ApiConfig.baseUrl}/api/tts/speak?text=$encodedWord&lang=$lang';

    final audio = html.AudioElement(url);
    audio.volume = 1.0;
    _currentAudio = audio;

    final ready = Completer<bool>();
    audio.onCanPlay.first.then((_) {
      if (!ready.isCompleted) ready.complete(true);
    });
    audio.onError.first.then((_) {
      if (!ready.isCompleted) ready.complete(false);
    });

    final canPlay = await ready.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => false,
    );
    if (!canPlay) {
      if (_currentAudio == audio) _currentAudio = null;
      return false;
    }

    await audio.play();
    await audio.onEnded.first;

    if (_currentAudio == audio) _currentAudio = null;
    return true;
  } catch (_) {
    _currentAudio = null;
    return false;
  }
}

Future<void> _speakWithBrowserTts(String word) async {
  try {
    final synth = js_util.getProperty(js_util.globalThis, 'speechSynthesis');
    js_util.callMethod(synth, 'cancel', []);

    final voices = List.from(js_util.callMethod(synth, 'getVoices', []));
    final isChinese = RegExp(r'[一-鿿]').hasMatch(word);
    final langPrefix = isChinese ? 'zh' : 'en';

    final selectedVoice = voices.firstWhere(
      (v) => js_util.getProperty(v, 'lang').toString().startsWith(langPrefix),
      orElse: () => voices.isNotEmpty ? voices[0] : null,
    );

    final utter = js_util.callConstructor(
      js_util.getProperty(js_util.globalThis, 'SpeechSynthesisUtterance'),
      [word],
    );
    if (selectedVoice != null) {
      js_util.setProperty(utter, 'voice', selectedVoice);
      js_util.setProperty(utter, 'lang', js_util.getProperty(selectedVoice, 'lang'));
    }
    js_util.callMethod(synth, 'speak', [utter]);
  } catch (_) {
    // No speechSynthesis available at all — silently give up, matching
    // native flutter_tts's own try/catch-and-continue behavior.
  }
}
