import 'dart:math';

/// A gift box opens after every this-many successful handwriting exercises
/// in a session - handwriting is the slowest exercise, so every one earns
/// a reward.
const int handwriteGiftEvery = 1;

bool handwriteGiftDue(int handwritesDone) =>
    handwritesDone > 0 && handwritesDone % handwriteGiftEvery == 0;

class HandwriteGift {
  final String emoji;
  final String label;
  final int coins;
  final int xp;

  const HandwriteGift({
    required this.emoji,
    required this.label,
    this.coins = 0,
    this.xp = 0,
  });
}

const _coinGift = HandwriteGift(emoji: '🪙', label: 'Shiny coins!', coins: 5);
const _xpGift = HandwriteGift(emoji: '⚡', label: 'Energy boost!', xp: 15);
const _jackpotGift = HandwriteGift(
  emoji: '💎',
  label: 'Rare gem!',
  coins: 15,
  xp: 10,
);

/// Rolls the contents of a gift box: mostly coins or XP, with the odd rare
/// jackpot to keep opening them exciting.
HandwriteGift rollHandwriteGift(Random random) {
  final roll = random.nextInt(10);
  if (roll < 5) return _coinGift;
  if (roll < 9) return _xpGift;
  return _jackpotGift;
}
