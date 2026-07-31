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

/// Unlike the FlutterSpell original this is ported from, this calls
/// audio.play() immediately instead of awaiting the network fetch/canPlay
/// event first. iOS Safari only allows an unmuted play() to succeed when
/// it's invoked directly off a user gesture; awaiting anything (like the
/// backend round-trip) beforehand breaks that chain and play() gets
/// silently rejected, so audio never starts.
Future<bool> _tryGoogleTts(String word) async {
  try {
    final isChinese = RegExp(r'[一-鿿]').hasMatch(word);
    final lang = isChinese ? 'zh-CN' : 'en-US';
    final encodedWord = Uri.encodeComponent(word);
    final url = '${ApiConfig.baseUrl}/api/tts/speak?text=$encodedWord&lang=$lang';

    final audio = html.AudioElement(url);
    audio.volume = 1.0;
    _currentAudio = audio;

    final started = Completer<bool>();
    audio.onError.first.then((_) {
      if (!started.isCompleted) started.complete(false);
    });
    audio.play().then((_) {
      if (!started.isCompleted) started.complete(true);
    }).catchError((_) {
      if (!started.isCompleted) started.complete(false);
    });

    final ok = await started.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => false,
    );
    if (!ok) {
      if (_currentAudio == audio) _currentAudio = null;
      return false;
    }

    await audio.onEnded.first;

    if (_currentAudio == audio) _currentAudio = null;
    return true;
  } catch (_) {
    _currentAudio = null;
    return false;
  }
}

// Web Speech API voices don't expose a gender field, so match common
// female voice names from the OS/browser catalogs (Windows, macOS, Chrome,
// Edge) that desktop `speechSynthesis` typically offers.
const _femaleVoiceNameHints = [
  'female',
  // English (Windows SAPI, macOS, Chrome/Edge online voices)
  'zira', 'samantha', 'susan', 'victoria', 'karen', 'moira', 'tessa',
  'fiona', 'kate', 'serena', 'ava', 'allison', 'aria', 'jenny', 'sara',
  'salli', 'joanna', 'kimberly', 'ivy', 'emma', 'amy', 'hazel',
  // Chinese (Windows SAPI, macOS, Edge online voices)
  'huihui', 'xiaoxiao', 'yaoyao', 'ting-ting', 'tingting', 'xiaoyi',
  'meijia', 'mei-jia',
];

bool _looksFemale(String voiceName) {
  final name = voiceName.toLowerCase();
  return _femaleVoiceNameHints.any((hint) => name.contains(hint));
}

Future<void> _speakWithBrowserTts(String word) async {
  try {
    final synth = js_util.getProperty(js_util.globalThis, 'speechSynthesis');
    js_util.callMethod(synth, 'cancel', []);

    final voices = List.from(js_util.callMethod(synth, 'getVoices', []));
    final isChinese = RegExp(r'[一-鿿]').hasMatch(word);
    final langPrefix = isChinese ? 'zh' : 'en';

    final langVoices = voices
        .where((v) => js_util
            .getProperty(v, 'lang')
            .toString()
            .startsWith(langPrefix))
        .toList();

    final selectedVoice = langVoices.firstWhere(
      (v) => _looksFemale(js_util.getProperty(v, 'name').toString()),
      orElse: () => langVoices.isNotEmpty
          ? langVoices.first
          : (voices.isNotEmpty ? voices.first : null),
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
