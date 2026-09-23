import 'dart:math';
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../utils/handwriting_gift.dart';
import 'celebration.dart';

/// "You've been writing a lot - here's a present!" A wobbling gift box the
/// child taps to open; it bursts open to reveal [gift], then a button
/// closes it. [onClaim] runs synchronously from that button's tap so the
/// caller can keep its audio/gesture chain intact (see StudyScreen).
class GiftBoxDialog extends StatefulWidget {
  final HandwriteGift gift;
  final VoidCallback onClaim;

  const GiftBoxDialog({super.key, required this.gift, required this.onClaim});

  @override
  State<GiftBoxDialog> createState() => _GiftBoxDialogState();
}

class _GiftBoxDialogState extends State<GiftBoxDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wobble = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..repeat();
  bool _opened = false;

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  void _open() {
    if (_opened) return;
    setState(() => _opened = true);
    _wobble.stop();
    Celebration.reward(context);
  }

  @override
  Widget build(BuildContext context) {
    final gift = widget.gift;
    return Dialog(
      backgroundColor: DuolingoColors.backgroundWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
      ),
      child: Padding(
        padding: EdgeInsets.all(DuolingoSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _opened ? gift.label : 'A gift for your writing!',
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.sectionTitle,
            ),
            SizedBox(height: DuolingoSpacing.xl),
            GestureDetector(
              onTap: _open,
              child: SizedBox(
                height: 120,
                child: _opened
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.3, end: 1),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (_, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Text(
                          gift.emoji,
                          style: const TextStyle(fontSize: 96),
                        ),
                      )
                    : AnimatedBuilder(
                        animation: _wobble,
                        builder: (_, child) => Transform.rotate(
                          angle: sin(_wobble.value * 2 * pi) * 0.12,
                          child: child,
                        ),
                        child: const Text('🎁', style: TextStyle(fontSize: 96)),
                      ),
              ),
            ),
            SizedBox(height: DuolingoSpacing.md),
            if (_opened) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: DuolingoSpacing.md,
                children: [
                  if (gift.coins > 0)
                    Text(
                      '+${gift.coins} 💰',
                      style: DuolingoTextStyles.cardTitle.copyWith(
                        color: DuolingoColors.treasureGold,
                        fontSize: 22,
                      ),
                    ),
                  if (gift.xp > 0)
                    Text(
                      '+${gift.xp} ⚡ XP',
                      style: DuolingoTextStyles.cardTitle.copyWith(
                        color: DuolingoColors.streakOrange,
                        fontSize: 22,
                      ),
                    ),
                ],
              ),
              SizedBox(height: DuolingoSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuolingoColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DuolingoSpacing.radiusButton,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onClaim();
                  },
                  child: Text(
                    'AWESOME!',
                    style: DuolingoTextStyles.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else
              Text(
                'Tap to open!',
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.bodyText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
