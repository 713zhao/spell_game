import 'package:flutter/material.dart';

/// A minimal freehand-drawing surface for handwriting practice. There's no
/// stroke recognition — it exists purely so a child can trace over a faint
/// reference character underneath; grading is a self-report by the caller
/// (see [ExerciseType.handwriteTrace] in study.dart).
class HandwritingCanvas extends StatefulWidget {
  const HandwritingCanvas({super.key});

  @override
  State<HandwritingCanvas> createState() => _HandwritingCanvasState();
}

class _HandwritingCanvasState extends State<HandwritingCanvas> {
  final List<List<Offset>> _strokes = [];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() => _strokes.add([details.localPosition]));
      },
      onPanUpdate: (details) {
        setState(() => _strokes.last.add(details.localPosition));
      },
      child: CustomPaint(
        painter: _StrokePainter(_strokes),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1899D6)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) => true;
}
