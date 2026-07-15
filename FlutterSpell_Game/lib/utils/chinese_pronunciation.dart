import 'package:lpinyin/lpinyin.dart';

/// Star rating (1-3) for a Chinese voice-reading attempt, comparing the
/// speech-recognized transcript's pronunciation against the target
/// character's:
/// - 3 stars: the transcript contains the exact character, or a
///   homophone of it (same pinyin *and* tone, e.g. 是/事/视 all "shì").
/// - 2 stars: similar (same pinyin, different tone).
/// - 1 star: no meaningful match, including no speech detected at all.
int rateChineseReading(String target, String? transcript) {
  if (transcript == null || transcript.trim().isEmpty) return 1;
  if (transcript.contains(target)) return 3;

  final targetToned = _pinyinWithTone(target);
  final targetBase = _pinyinWithoutTone(target);
  if (targetToned == null || targetBase == null) return 1;

  var bestTier = 1;
  for (final ch in transcript.split('')) {
    if (!ChineseHelper.isChinese(ch)) continue;
    final chToned = _pinyinWithTone(ch);
    if (chToned != null && chToned == targetToned) return 3;
    final chBase = _pinyinWithoutTone(ch);
    if (chBase != null && chBase == targetBase) bestTier = 2;
  }
  return bestTier;
}

String? _pinyinWithTone(String hanzi) {
  try {
    return PinyinHelper.getPinyin(
      hanzi,
      separator: '',
      format: PinyinFormat.WITH_TONE_NUMBER,
    );
  } catch (_) {
    return null; // character isn't in the pinyin dictionary
  }
}

String? _pinyinWithoutTone(String hanzi) {
  try {
    return PinyinHelper.getPinyin(
      hanzi,
      separator: '',
      format: PinyinFormat.WITHOUT_TONE,
    );
  } catch (_) {
    return null;
  }
}
