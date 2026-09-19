import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import '../config/api_config.dart';

// Ported from FlutterSpell (lib/services/tts_web.dart): browser
// speechSynthesis voices are unreliable across the board on web (missing
// or robotic voices, especially for Chinese, and especially on Firefox and
// iOS Safari), so Google Cloud TTS is tried first everywhere and
// speechSynthesis is only a fallback if that fails.

// iOS Safari's "unlock" isn't page-wide: a play() only succeeds without a
// direct gesture if it's called on an element that has itself already
// completed a play() from inside a real gesture. A freshly-constructed
// AudioElement is never blessed that way, so word pronunciation (triggered
// later from a post-frame callback, not a tap) must reuse the exact
// element that got primed in [unlockAudioForGesture] rather than
// constructing a new one per word.
html.AudioElement? _currentAudio;
final html.AudioElement _sharedAudio = html.AudioElement();

/// Speaks [word] on web. Returns `true` when Google Cloud TTS was attempted
/// and failed, falling back to the browser's built-in voice - callers use
/// this to warn the user once that voice quality may be degraded, instead
/// of failing silently.
Future<bool> speakOnWeb(String word) async {
  _stopCurrent();

  // Try Google Cloud TTS on every browser, not just mobile: desktop
  // Firefox ships few (often robotic) built-in voices, so relying on
  // speechSynthesis there gives noticeably worse quality than Chrome/Safari.
  final played = await _tryGoogleTts(word);
  if (!played) {
    await _speakWithBrowserTts(word);
  }
  return !played;
}

// iOS Safari (and, less strictly, Firefox) only allow audio/speech
// triggered by a direct, synchronous user gesture. Word pronunciation is
// often kicked off later from a post-frame callback, outside that gesture
// chain, so it gets silently rejected. Call this once from inside a real
// gesture handler (e.g. the app's first tap) to "prime" both the
// AudioElement and speechSynthesis so later programmatic calls succeed.
bool _audioUnlocked = false;

void unlockAudioForGesture() {
  if (_audioUnlocked) return;
  _audioUnlocked = true;
  try {
    final synth = js_util.getProperty(js_util.globalThis, 'speechSynthesis');
    final utter = js_util.callConstructor(
      js_util.getProperty(js_util.globalThis, 'SpeechSynthesisUtterance'),
      [''],
    );
    js_util.callMethod(synth, 'speak', [utter]);
  } catch (_) {
    // speechSynthesis not available in this browser
  }
  try {
    _sharedAudio
      ..src =
          'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA='
      ..volume = 0;
    _sharedAudio.play().catchError((_) {});
  } catch (_) {
    // Audio element playback not available
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

    final audio = _sharedAudio;
    audio.volume = 1.0;
    audio.src = url;
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
