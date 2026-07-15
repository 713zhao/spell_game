/// Records one short utterance and returns the recognized text, or null if
/// unsupported/failed/timed out. Web uses the browser's Web Speech API;
/// other platforms have no implementation yet and always return null.
export 'speech_recognition_web.dart'
    if (dart.library.io) 'speech_recognition_stub.dart';
