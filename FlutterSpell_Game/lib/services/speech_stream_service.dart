/// Continuous (multi-utterance) speech recognition with interim results.
/// Web uses the browser's Web Speech API; other platforms report
/// unsupported.
export 'speech_stream_web.dart'
    if (dart.library.io) 'speech_stream_stub.dart';
