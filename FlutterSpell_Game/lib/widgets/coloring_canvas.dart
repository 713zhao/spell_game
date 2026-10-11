import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../models/coloring_models.dart';

/// Neutral off-white fill shown for a region that hasn't been solved yet,
/// so the picture reads as a blank coloring-book outline.
const Color kColoringUnsolvedFill = Color(0xFFF5F5F0);
const Color kColoringStroke = Color(0xFF2B2B2B);

/// Parses every region's SVG path `d` string once and caches the result so
/// repeated rebuilds (e.g. on each tap) don't reparse 10-20 paths every
/// frame.
class ColoringPathCache {
  final Map<int, Path> _paths;
  final Map<int, Rect> _bounds;

  ColoringPathCache._(this._paths, this._bounds);

  factory ColoringPathCache.build(ColoringPicture picture) {
    final paths = <int, Path>{};
    final bounds = <int, Rect>{};
    for (final region in picture.regions) {
      final path = parseSvgPathData(region.path);
      paths[region.id] = path;
      bounds[region.id] = path.getBounds();
    }
    return ColoringPathCache._(paths, bounds);
  }

  Path pathFor(int regionId) => _paths[regionId]!;

  final Map<int, Offset> _labels = {};

  /// Where to draw a region's number: a point well inside the part of the
  /// region that isn't covered by regions painted later (so the number of a
  /// big base shape, or a ring around an eye, isn't hidden under details).
  /// Computed lazily, once per region.
  Offset labelFor(ColoringPicture picture, ColoringRegion region) {
    return _labels.putIfAbsent(region.id, () {
      final own = _paths[region.id]!;
      final b = _bounds[region.id]!;
      final later = <Path>[];
      var after = false;
      for (final r in picture.regions) {
        if (r.id == region.id) {
          after = true;
          continue;
        }
        if (after && _bounds[r.id]!.overlaps(b)) later.add(_paths[r.id]!);
      }
      bool visible(Offset p) =>
          own.contains(p) && !later.any((path) => path.contains(p));
      final probe = max(2.0, min(b.width, b.height) * 0.2);
      const dirs = [
        Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1),
        Offset(0.7, 0.7), Offset(-0.7, 0.7), Offset(0.7, -0.7), Offset(-0.7, -0.7),
      ];
      Offset best = b.center;
      var bestScore = -1.0;
      const steps = 9;
      for (var i = 0; i < steps; i++) {
        for (var j = 0; j < steps; j++) {
          final p = Offset(
            b.left + (i + 0.5) / steps * b.width,
            b.top + (j + 0.5) / steps * b.height,
          );
          if (!visible(p)) continue;
          var score = dirs.where((d) => visible(p + d * probe)).length.toDouble();
          score -= (p - b.center).distance / (b.longestSide + 1);
          if (score > bestScore) {
            bestScore = score;
            best = p;
          }
        }
      }
      return best;
    });
  }
  Rect boundsFor(int regionId) => _bounds[regionId]!;
}

/// Paints a [ColoringPicture]: each region filled with its target color once
/// [solvedRegionIds] contains it, otherwise a neutral outline fill with its
/// number centered in it. Always strokes every region's outline in black.
class ColoringPainter extends CustomPainter {
  final ColoringPicture picture;
  final ColoringPathCache cache;
  final Set<int> solvedRegionIds;
  final bool showNumbers;

  ColoringPainter({
    required this.picture,
    required this.cache,
    required this.solvedRegionIds,
    this.showNumbers = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Regions are authored in the picture's native coordinate space (e.g.
    // 300x300). The actual box this painter receives can differ (phone
    // width, AspectRatio rounding, etc.), so scale the canvas rather than
    // assuming a 1:1 match - otherwise shapes drawn in native coordinates
    // would misalign with (or overflow past) the painted box.
    final scaleX = picture.width == 0 ? 1.0 : size.width / picture.width;
    final scaleY = picture.height == 0 ? 1.0 : size.height / picture.height;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kColoringStroke;

    for (final region in picture.regions) {
      final path = cache.pathFor(region.id);
      final solved = solvedRegionIds.contains(region.id);
      fillPaint.color = solved
          ? (picture.palette[region.colorIndex] ?? Colors.grey)
          : kColoringUnsolvedFill;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      if (!solved && showNumbers) {
        final bounds = cache.boundsFor(region.id);
        // Small regions get a smaller number so it stays inside them.
        final fontSize = (min(bounds.width, bounds.height) * 0.7).clamp(7.0, 16.0);
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${region.colorIndex}',
            style: TextStyle(
              color: const Color(0xFF757575),
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final center = cache.labelFor(picture, region);
        textPainter.paint(
          canvas,
          Offset(
            center.dx - textPainter.width / 2,
            center.dy - textPainter.height / 2,
          ),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ColoringPainter oldDelegate) {
    return oldDelegate.solvedRegionIds.length != solvedRegionIds.length ||
        !oldDelegate.solvedRegionIds.containsAll(solvedRegionIds) ||
        oldDelegate.picture != picture;
  }
}

/// Finds which region (if any) a local tap point hit, checking topmost
/// (last-painted) regions first so a tap on a small region nested inside a
/// larger one resolves to the nested one.
ColoringRegion? hitTestColoring(
  ColoringPicture picture,
  ColoringPathCache cache,
  Offset localPosition,
) {
  for (final region in picture.regions.reversed) {
    if (cache.pathFor(region.id).contains(localPosition)) {
      return region;
    }
  }
  return null;
}

/// The interactive coloring canvas: pinch-zoom/pan wrapper + tap-to-fill.
/// Pure UI/hit-testing - the caller owns [solvedRegionIds] and the
/// correct/incorrect feedback.
class ColoringCanvas extends StatefulWidget {
  final ColoringPicture picture;
  final Set<int> solvedRegionIds;
  final int? selectedColorIndex;
  final void Function(ColoringRegion region, bool correct) onRegionTapped;

  const ColoringCanvas({
    super.key,
    required this.picture,
    required this.solvedRegionIds,
    required this.selectedColorIndex,
    required this.onRegionTapped,
  });

  @override
  State<ColoringCanvas> createState() => _ColoringCanvasState();
}

class _ColoringCanvasState extends State<ColoringCanvas>
    with SingleTickerProviderStateMixin {
  late final ColoringPathCache _cache = ColoringPathCache.build(
    widget.picture,
  );
  late final AnimationController _shakeController = AnimationController(
    duration: const Duration(milliseconds: 350),
    vsync: this,
  );
  int? _shakeRegionId;

  // Identifies the CustomPaint's own RenderBox so tap coordinates can be
  // converted via that box specifically - NOT via `context` captured from
  // build(), which (since the GestureDetector is passed as AnimatedBuilder's
  // static `child:`, built once with the outer context rather than inside
  // its `builder:` callback) resolves to a much larger ancestor box (the
  // full LayoutBuilder area, not the square AspectRatio-constrained paint
  // box), silently producing wildly wrong hit-test coordinates.
  final GlobalKey _paintKey = GlobalKey();

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details) {
    final box = _paintKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final boxLocal = box.globalToLocal(details.globalPosition);
    final picture = widget.picture;
    final scaleX = picture.width / box.size.width;
    final scaleY = picture.height / box.size.height;
    final local = Offset(boxLocal.dx * scaleX, boxLocal.dy * scaleY);
    final region = hitTestColoring(picture, _cache, local);
    if (region == null) return;
    if (widget.solvedRegionIds.contains(region.id)) return;
    final selected = widget.selectedColorIndex;
    final correct = selected != null && selected == region.colorIndex;
    if (!correct) {
      setState(() => _shakeRegionId = region.id);
      _shakeController.forward(from: 0);
    }
    widget.onRegionTapped(region, correct);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = widget.picture.width / widget.picture.height;
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final dx = _shakeRegionId == null
                      ? 0.0
                      : sin(_shakeController.value * pi * 6) * 6;
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTapUp: _handleTapUp,
                  child: CustomPaint(
                    key: _paintKey,
                    painter: ColoringPainter(
                      picture: widget.picture,
                      cache: _cache,
                      solvedRegionIds: widget.solvedRegionIds,
                    ),
                    size: Size(widget.picture.width, widget.picture.height),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Renders a picture fully solved (every region at its target color, no
/// numbers) - used for gallery thumbnails.
class ColoringThumbnailPainter extends CustomPainter {
  final ColoringPicture picture;
  final ColoringPathCache cache;

  ColoringThumbnailPainter({required this.picture, required this.cache});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = picture.width == 0 ? 1.0 : size.width / picture.width;
    final scaleY = picture.height == 0 ? 1.0 : size.height / picture.height;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = kColoringStroke;
    for (final region in picture.regions) {
      final path = cache.pathFor(region.id);
      fillPaint.color = picture.palette[region.colorIndex] ?? Colors.grey;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ColoringThumbnailPainter oldDelegate) => false;
}
