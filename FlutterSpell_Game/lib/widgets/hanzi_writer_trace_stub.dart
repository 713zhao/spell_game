import 'package:flutter/material.dart';

import 'hanzi_writer_trace.dart' show HanziWriterTraceController;

/// Non-web stub. study.dart already gates on kIsWeb before ever choosing
/// the HanziWriter quiz mode, so this only exists to satisfy the
/// conditional export on native builds; it reports unavailable in case
/// it's ever reached anyway.
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUnavailable();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
