/// Speaks [word] using Google Cloud TTS on web (falling back to the
/// browser's built-in speechSynthesis if that fails or on desktop, where
/// browser voices are already decent). Native platforms don't use this —
/// SoundService calls flutter_tts directly there instead.
export 'web_tts_web.dart' if (dart.library.io) 'web_tts_stub.dart';
