import 'package:flutter/foundation.dart';

/// Guided stroke-order tracing for a single Chinese character, backed by
/// the HanziWriter JS library (see web/index.html): it checks stroke
/// direction/shape as the child draws and fills in each correct stroke
/// onto the character outline, only completing once every stroke is
/// right - the same UX as https://hanziwriter.org/quiz.html. Web only
/// (it's a JS library embedded via a platform view); non-web platforms
/// get a stub that immediately reports itself unavailable so the caller
/// falls back to the plain free-draw HandwritingCanvas.
export 'hanzi_writer_trace_web.dart' if (dart.library.io) 'hanzi_writer_trace_stub.dart';

/// Lets a caller trigger the "show me how to write it" stroke-order demo
/// on a live HanziWriterTrace from outside the widget (e.g. a button in
/// the parent screen), without tearing down and losing quiz progress the
/// way rebuilding with a new widget Key would. Pass the same instance to
/// HanziWriterTrace across character changes - each new instance attaches
/// itself in initState, so the controller always drives whichever
/// character is currently on screen.
class HanziWriterTraceController {
  VoidCallback? attachedShowStrokeOrder;

  void showStrokeOrder() => attachedShowStrokeOrder?.call();
}
