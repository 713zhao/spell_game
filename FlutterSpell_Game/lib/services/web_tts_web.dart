import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import '../config/api_config.dart';

// Ported from FlutterSpell (lib/services/tts_web.dart): browser
// speechSynthesis voices are unreliable across the board on web (missing
// or robotic voices, especially for Chinese, and especially on Firefox and
// iOS Safari), so Google Cloud TTS is tried first everywhere and
// speechSynthesis is only a fallback if that fails.

// Every real caller of speakOnWeb is already gesture-synchronous (see the
// _autoPlayCurrentWord comment in study.dart - deliberately never invoked
// from a post-frame callback or other async gap), so word audio itself
// qualifies for iOS Safari's per-call "this play() happened inside a user
// gesture's call stack" allowance on its own merits. It does NOT need to
// reuse a previously-blessed element to work.
//
// [unlockAudioForGesture] exists only to prime speechSynthesis once so a
// *rejected/glitchy first-ever* speak() doesn't leave the engine wedged,
// plus a defensive silent AudioElement.play(). It used to reuse this same
// _sharedAudio element, which meant the very first tap after a page
// reload could race two play() calls against each other on one element
// (the unlock's silent blip and, moments later, the real TTS clip
// overwriting .src mid-flight) - iOS Safari can silently drop the second
// play() when that happens. Giving the unlock ping its own dedicated
// element removes that race entirely.
html.AudioElement? _currentAudio;
final html.AudioElement _sharedAudio = html.AudioElement();
final html.AudioElement _unlockAudio = html.AudioElement();

/// Speaks [word] on web. Returns `true` when Google Cloud TTS was attempted
/// and failed, falling back to the browser's built-in voice - callers use
/// this to warn the user once that voice quality may be degraded, instead
/// of failing silently.
// After Google TTS fails (e.g. billing disabled on the backend), skip it for
// a few minutes so every play doesn't wait on a request that will fail
// again, and go straight to the built-in voice.
DateTime? _googleFailedAt;
const _googleRetryAfter = Duration(minutes: 5);

// User-selected browser voices, keyed by language prefix ('en' / 'zh').
final Map<String, String> _preferredVoices = {};

void setPreferredWebVoice(String langPrefix, String? voiceName) {
  if (voiceName == null || voiceName.isEmpty) {
    _preferredVoices.remove(langPrefix);
  } else {
    _preferredVoices[langPrefix] = voiceName;
  }
}

/// Lists every voice the browser's speechSynthesis offers, as
/// `{name, lang}` maps.
Future<List<Map<String, String>>> getWebVoices() async {
  try {
    final synth = js_util.getProperty(js_util.globalThis, 'speechSynthesis');
    final voices = await _getVoicesAsync(synth);
    return voices
        .map<Map<String, String>>((v) => {
              'name': js_util.getProperty(v, 'name').toString(),
              'lang': js_util.getProperty(v, 'lang').toString(),
            })
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<bool> speakOnWeb(String word) async {
  _stopCurrent();

  // An explicitly chosen local voice always wins over Google Cloud TTS.
  final prefix = RegExp(r'[一-鿿]').hasMatch(word) ? 'zh' : 'en';
  if (_preferredVoices.containsKey(prefix)) {
    await _speakWithBrowserTts(word);
    return false;
  }

  // Try Google Cloud TTS on every browser, not just mobile: desktop
  // Firefox ships few (often robotic) built-in voices, so relying on
  // speechSynthesis there gives noticeably worse quality than Chrome/Safari.
  final skipGoogle = _googleFailedAt != null &&
      DateTime.now().difference(_googleFailedAt!) < _googleRetryAfter;
  final played = skipGoogle ? false : await _tryGoogleTts(word);
  if (!skipGoogle) _googleFailedAt = played ? null : DateTime.now();
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
    _unlockAudio
      ..src =
          'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQAAAAA='
      ..volume = 0;
    _unlockAudio.play().catchError((_) {});
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

// Safari (and Chrome, on a cold cache) returns an empty voice list from
// the very first getVoices() call after a page load - the real list only
// arrives asynchronously via the 'voiceschanged' event. Calling speak()
// with no matching voice found doesn't usually fail outright, but it
// silently loses the language/gender preference. Wait briefly for the
// event (capped so a browser that never fires it - some older WebKit
// builds don't - can't hang word playback indefinitely).
Future<List> _getVoicesAsync(Object synth) async {
  final immediate = List.from(js_util.callMethod(synth, 'getVoices', []));
  if (immediate.isNotEmpty) return immediate;

  final completer = Completer<List>();
  void handler(dynamic _) {
    if (!completer.isCompleted) {
      completer.complete(
        List.from(js_util.callMethod(synth, 'getVoices', [])),
      );
    }
  }

  final jsHandler = js_util.allowInterop(handler);
  js_util.callMethod(synth, 'addEventListener', ['voiceschanged', jsHandler]);
  final voices = await completer.future.timeout(
    const Duration(milliseconds: 500),
    onTimeout: () => List.from(js_util.callMethod(synth, 'getVoices', [])),
  );
  try {
    js_util.callMethod(synth, 'removeEventListener', [
      'voiceschanged',
      jsHandler,
    ]);
  } catch (_) {
    // Best-effort cleanup only.
  }
  return voices;
}

Future<void> _speakWithBrowserTts(String word) async {
  try {
    final synth = js_util.getProperty(js_util.globalThis, 'speechSynthesis');
    js_util.callMethod(synth, 'cancel', []);

    final voices = await _getVoicesAsync(synth);
    final isChinese = RegExp(r'[一-鿿]').hasMatch(word);
    final langPrefix = isChinese ? 'zh' : 'en';

    final langVoices = voices
        .where((v) => js_util
            .getProperty(v, 'lang')
            .toString()
            .startsWith(langPrefix))
        .toList();

    // Only pick a voice of the right language. Falling back to "any
    // voice" (voices.first) can land on a wrong-language or novelty voice
    // that reads Chinese as garbage; with no match we leave the voice unset
    // and only set utter.lang, so the browser picks its own default voice
    // for that language.
    final preferredName = _preferredVoices[langPrefix];
    final selectedVoice = langVoices.isEmpty
        ? null
        : langVoices.firstWhere(
            (v) =>
                preferredName != null &&
                js_util.getProperty(v, 'name').toString() == preferredName,
            orElse: () => langVoices.firstWhere(
              (v) => _looksFemale(js_util.getProperty(v, 'name').toString()),
              orElse: () => langVoices.first,
            ),
          );
    final fallbackLang = isChinese ? 'zh-CN' : 'en-US';

    void speakOnce({bool isRetry = false}) {
      final utter = js_util.callConstructor(
        js_util.getProperty(js_util.globalThis, 'SpeechSynthesisUtterance'),
        [word],
      );
      if (selectedVoice != null) {
        js_util.setProperty(utter, 'voice', selectedVoice);
        js_util.setProperty(
          utter,
          'lang',
          js_util.getProperty(selectedVoice, 'lang'),
        );
      } else {
        js_util.setProperty(utter, 'lang', fallbackLang);
      }
      // speechSynthesis.speak() doesn't reject on a gesture-policy
      // rejection - it fails silently with no event at all - so there's
      // no reliable signal to retry on for THAT case. What IS observable
      // is a genuine 'error' event (e.g. the engine was still tearing
      // down the cancel() call issued above, or hit a transient glitch);
      // one retry after a short delay recovers from that specific case
      // without risking a retry loop.
      if (!isRetry) {
        js_util.callMethod(utter, 'addEventListener', [
          'error',
          js_util.allowInterop((_) {
            Future.delayed(
              const Duration(milliseconds: 150),
              () => speakOnce(isRetry: true),
            );
          }),
        ]);
      }
      js_util.callMethod(synth, 'speak', [utter]);
    }

    speakOnce();
  } catch (_) {
    // No speechSynthesis available at all — silently give up, matching
    // native flutter_tts's own try/catch-and-continue behavior.
  }
}
