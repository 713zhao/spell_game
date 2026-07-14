class LessonRewards {
  final int xp;
  final int coins;

  const LessonRewards({required this.xp, required this.coins});
}

/// XP and coin rewards shown on the Lesson Overview screen, scaled to the
/// number of words in the deck.
LessonRewards computeLessonRewards(int wordCount) {
  return LessonRewards(xp: wordCount * 10, coins: wordCount * 2);
}
