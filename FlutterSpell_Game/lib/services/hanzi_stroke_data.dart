import 'package:http/http.dart' as http;

/// The HanziWriter JS library loaded in web/index.html reads stroke data
/// from this CDN by default (pinned version, matching the script tag there)
/// - used both by that library and here to preflight whether every
/// character in a word has data before committing to the guided quiz UI
/// (see HanziWriterTrace) instead of the free-draw fallback.
const String hanziWriterDataBaseUrl =
    'https://cdn.jsdelivr.net/npm/hanzi-writer-data@2.0.1';

/// Whether stroke-order data exists for every distinct character in [word].
/// Multi-character words switch to guided tracing only when this is true
/// for all of them - a word with even one unsupported character (e.g. a
/// character outside HanziWriter's dataset, or punctuation) falls back to
/// free-draw tracing for the whole word rather than mixing UX mid-word.
Future<bool> hanziStrokeDataAvailable(String word) async {
  final characters = word.split('').toSet();
  if (characters.isEmpty) return false;
  try {
    final results = await Future.wait(characters.map(_charHasStrokeData));
    return results.every((ok) => ok);
  } catch (_) {
    return false;
  }
}

Future<bool> _charHasStrokeData(String char) async {
  try {
    final uri = Uri.parse(
      '$hanziWriterDataBaseUrl/${Uri.encodeComponent(char)}.json',
    );
    final response = await http.head(uri).timeout(const Duration(seconds: 4));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
