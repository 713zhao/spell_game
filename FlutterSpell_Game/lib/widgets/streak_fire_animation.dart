import 'package:flutter/material.dart';

/// Animated fire emoji for streak milestones
class StreakFireAnimation extends StatefulWidget {
  final int count;
  final Duration duration;
  final VoidCallback? onComplete;
  final double size;

  const StreakFireAnimation({
    Key? key,
    this.count = 1,
    this.duration = const Duration(milliseconds: 800),
    this.onComplete,
    this.size = 64,
  }) : super(key: key);

  @override
  State<StreakFireAnimation> createState() => _StreakFireAnimationState();
}

class _StreakFireAnimationState extends State<StreakFireAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.3, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: RotationTransition(
        turns: _rotateAnimation,
        child: Text(
          '🔥' * widget.count,
          style: TextStyle(fontSize: widget.size),
        ),
      ),
    );
  }
}

/// Streak milestone celebration with multiple fire animations
class StreakMilestoneCelebration extends StatefulWidget {
  final int streakDays;
  final VoidCallback? onComplete;

  const StreakMilestoneCelebration({
    Key? key,
    required this.streakDays,
    this.onComplete,
  }) : super(key: key);

  @override
  State<StreakMilestoneCelebration> createState() =>
      _StreakMilestoneCelebrationState();
}

class _StreakMilestoneCelebrationState
    extends State<StreakMilestoneCelebration> with TickerProviderStateMixin {
  late AnimationController _textController;
  late AnimationController _fireController;
  late Animation<double> _textScale;
  late Animation<double> _fireScale;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fireController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticOut),
    );

    _fireScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fireController, curve: Curves.elasticOut),
    );

    _textController.forward().then((_) {
      _fireController.forward();
      Future.delayed(const Duration(milliseconds: 1600), () {
        widget.onComplete?.call();
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _fireController.dispose();
    super.dispose();
  }

  String _getMilestoneMessage() {
    if (widget.streakDays % 100 == 0) {
      return '${widget.streakDays}-Day Streak!';
    } else if (widget.streakDays % 30 == 0) {
      return 'Month Streak!';
    } else if (widget.streakDays % 7 == 0) {
      return 'Week Streak!';
    }
    return '${widget.streakDays}-Day Streak!';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _textScale,
          child: Column(
            children: [
              Text(
                _getMilestoneMessage(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        ScaleTransition(
          scale: _fireScale,
          child: const Text(
            '🔥🔥🔥',
            style: TextStyle(fontSize: 64),
          ),
        ),
      ],
    );
  }
}
