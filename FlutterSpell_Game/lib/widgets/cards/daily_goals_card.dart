import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

/// Compact "today's goals" strip: one icon per goal, in full colour with a
/// check once done and greyed out until then, plus a lock that opens when
/// the required goals are done (the games unlock). [goals] is the backend's
/// daily-goals list ({kind, title, icon, required, done, ...}); long-press
/// or hover an icon for its name.
class DailyGoalsCard extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final bool allDone;

  final void Function(String kind) onGoalTap;

  const DailyGoalsCard({
    Key? key,
    required this.goals,
    required this.allDone,
    required this.onGoalTap,
  }) : super(key: key);

  static const _greyMatrix = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  Widget _goal(Map<String, dynamic> g) {
    final done = g['done'] == true;
    final bonus = g['required'] == false;
    Widget icon = Text(g['icon'] as String, style: const TextStyle(fontSize: 26));
    if (!done) {
      icon = Opacity(
        opacity: 0.4,
        child: ColorFiltered(colorFilter: _greyMatrix, child: icon),
      );
    }
    return Tooltip(
      message: '${g['title']}${bonus ? ' (bonus)' : ''}',
      child: GestureDetector(
        onTap: () => onGoalTap(g['kind'] as String),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? DuolingoColors.primaryGreen.withOpacity(0.15)
                      : DuolingoColors.neutralGray,
                  border: Border.all(
                    color: done
                        ? DuolingoColors.primaryGreen
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: icon,
              ),
              if (done)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DuolingoColors.primaryGreen,
                    ),
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return const SizedBox.shrink();
    final required = goals.where((g) => g['required'] != false);
    final bonus = goals.where((g) => g['required'] == false);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: DuolingoSpacing.md,
        vertical: DuolingoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: DuolingoColors.backgroundWhite,
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border.all(
          color: allDone
              ? DuolingoColors.primaryGreen
              : DuolingoColors.neutralGray,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final g in required) _goal(g),
          for (final g in bonus) _goal(g),
          Tooltip(
            message: allDone
                ? 'Games unlocked - finish the goals again for +10 min'
                : 'Games locked',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(allDone ? '🎮' : '🔒', style: const TextStyle(fontSize: 26)),
                if (allDone)
                  Text(
                    '+10',
                    style: DuolingoTextStyles.label.copyWith(
                      color: DuolingoColors.primaryGreen,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
