import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'hanzi_writer_trace.dart' show HanziWriterTraceController;

int _viewIdCounter = 0;

/// Web implementation: hosts a div via a platform view and drives the
/// HanziWriter JS instance (loaded globally in web/index.html) through
/// dart:js_util interop. See hanzi_writer_trace.dart for the shared doc.
class HanziWriterTrace extends StatefulWidget {
  final String character;
  final double size;
  final VoidCallback onComplete;
  final VoidCallback onUnavailable;
  final HanziWriterTraceController? controller;

  const HanziWriterTrace({
    super.key,
    required this.character,
    required this.size,
    required this.onComplete,
    required this.onUnavailable,
    this.controller,
  });

  @override
  State<HanziWriterTrace> createState() => _HanziWriterTraceState();
}

class _HanziWriterTraceState extends State<HanziWriterTrace> {
  late final String _viewType;
  late final html.DivElement _container;
  Object? _writer;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'hanzi-writer-view-${_viewIdCounter++}';
    _container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      // Drawing a stroke must not pan/scroll the page under the finger.
      ..style.touchAction = 'none';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _container,
    );
    widget.controller?.attachedShowStrokeOrder = _showStrokeOrder;
    // Deferred to a post-frame callback so the div is actually attached to
    // the DOM by the time HanziWriter measures it on create().
    WidgetsBinding.instance.addPostFrameCallback((_) => _createWriter());
  }

  @override
  void dispose() {
    if (widget.controller?.attachedShowStrokeOrder == _showStrokeOrder) {
      widget.controller?.attachedShowStrokeOrder = null;
    }
    super.dispose();
  }

  /// Plays the stroke-order demo animation, then hands control back to a
  /// fresh quiz so the child can try it themselves right after watching.
  void _showStrokeOrder() {
    final writer = _writer;
    if (writer == null || _resolved) return;
    try {
      js_util.callMethod(writer, 'cancelQuiz', []);
      js_util.callMethod(writer, 'animateCharacter', [
        js_util.jsify({
          'onComplete': js_util.allowInterop((dynamic _) => _startQuiz()),
        }),
      ]);
    } catch (_) {}
  }

  void _startQuiz() {
    final writer = _writer;
    if (writer == null || !mounted || _resolved) return;
    try {
      js_util.callMethod(writer, 'quiz', [
        js_util.jsify({
          'onComplete': js_util.allowInterop((dynamic _) => _complete()),
        }),
      ]);
    } catch (_) {
      _fail();
    }
  }

  void _fail() {
    if (!mounted || _resolved) return;
    _resolved = true;
    widget.onUnavailable();
  }

  void _complete() {
    if (!mounted || _resolved) return;
    _resolved = true;
    widget.onComplete();
  }

  void _createWriter() {
    if (!mounted) return;
    try {
      final hanziWriterClass = js_util.getProperty(
        js_util.globalThis,
        'HanziWriter',
      );
      if (hanziWriterClass == null) {
        _fail();
        return;
      }
      final options = js_util.jsify({
        'width': widget.size,
        'height': widget.size,
        'padding': 8,
        'showOutline': true,
        'strokeColor': '#1899D6',
        'strokeAnimationSpeed': 2,
        'delayBetweenStrokes': 200,
        'onLoadCharDataError': js_util.allowInterop((dynamic _) => _fail()),
      });
      _writer = js_util.callMethod(hanziWriterClass, 'create', [
        _container,
        widget.character,
        options,
      ]);
      _startQuiz();
    } catch (_) {
      _fail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
