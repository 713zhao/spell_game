/// Speaks [word] using Google Cloud TTS on web (falling back to the
/// browser's built-in speechSynthesis if that fails). Native platforms
/// don't use this — SoundService calls flutter_tts directly there instead.
///
/// Also exports [unlockAudioForGesture], which primes speechSynthesis and
/// an AudioElement from inside a real user gesture so that later
/// programmatic playback (e.g. auto-advancing to the next word) isn't
/// silently blocked by browser autoplay policies (notably iOS Safari).
export 'web_tts_web.dart' if (dart.library.io) 'web_tts_stub.dart';
