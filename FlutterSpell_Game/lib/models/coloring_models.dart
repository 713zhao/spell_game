import 'package:flutter/material.dart';

/// One fillable region of a Color by Number picture: a single closed SVG
/// path `d` string plus the palette index it must be filled with to be
/// "solved". Regions are listed (and must be painted/hit-tested) in a
/// specific order - see [ColoringPicture].
class ColoringRegion {
  final int id;
  final int colorIndex;
  final String path;

  const ColoringRegion({
    required this.id,
    required this.colorIndex,
    required this.path,
  });

  factory ColoringRegion.fromJson(Map<String, dynamic> json) {
    return ColoringRegion(
      id: json['id'] as int,
      colorIndex: json['colorIndex'] as int,
      path: json['path'] as String,
    );
  }
}

/// A Color by Number picture: a fixed 300x300 viewBox of [regions], each
/// mapped via [colorIndex] into [palette].
///
/// Regions are stored in the exact order they must be painted (later =
/// drawn on top, for small regions nested inside larger ones, e.g. an eye
/// inside a head). Hit-testing must walk [regions] in reverse so a tap on a
/// nested region resolves to the topmost shape, not the larger one beneath
/// it.
class ColoringPicture {
  final String id;
  final String title;
  final double width;
  final double height;
  final Map<int, Color> palette;
  final List<ColoringRegion> regions;

  const ColoringPicture({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.palette,
    required this.regions,
  });

  factory ColoringPicture.fromJson(Map<String, dynamic> json) {
    final paletteJson = json['palette'] as Map<String, dynamic>;
    final palette = <int, Color>{
      for (final entry in paletteJson.entries)
        int.parse(entry.key): _colorFromHex(entry.value as String),
    };
    final regions = (json['regions'] as List)
        .map((r) => ColoringRegion.fromJson(r as Map<String, dynamic>))
        .toList();
    return ColoringPicture(
      id: json['id'] as String,
      title: json['title'] as String,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      palette: palette,
      regions: regions,
    );
  }

  /// Distinct colorIndex values present, in ascending order - used to build
  /// the palette swatch strip.
  List<int> get distinctColorIndexes {
    final set = <int>{for (final r in regions) r.colorIndex};
    final list = set.toList()..sort();
    return list;
  }

  static Color _colorFromHex(String hex) {
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  }
}
