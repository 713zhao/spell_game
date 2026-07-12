import 'package:flutter/material.dart';

/// Enhanced "+X points" pop animation with floating effect
class PointPopAnimation extends StatefulWidget {
  final int points;
  final Offset startPosition;
  final Duration duration;
  final VoidCallback? onComplete;
  final Color color;

  const PointPopAnimation({
    Key? key,
    required this.points,
    required this.startPosition,
    this.duration = const Duration(milliseconds: 1000),
    this.onComplete,
    this.color = Colors.green,
  }) : super(key: key);

  @override
  State<PointPopAnimation> createState() => _PointPopAnimationState();
}

class _PointPopAnimationState extends State<PointPopAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Float upward animation
    _positionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: widget.startPosition + const Offset(0, -80),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Fade out animation
    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    // Scale animation - pop and grow slightly
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.elasticOut),
      ),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                '+${widget.points} points',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black.withValues(alpha: 0.3),
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Multiple point pops for rewards
class MultiPointPop extends StatefulWidget {
  final List<int> pointsList;
  final Offset startPosition;
  final Duration delayBetween;

  const MultiPointPop({
    Key? key,
    required this.pointsList,
    required this.startPosition,
    this.delayBetween = const Duration(milliseconds: 150),
  }) : super(key: key);

  @override
  State<MultiPointPop> createState() => _MultiPointPopState();
}

class _MultiPointPopState extends State<MultiPointPop> {
  late List<bool> _animationComplete;

  @override
  void initState() {
    super.initState();
    _animationComplete = List.filled(widget.pointsList.length, false);
  }

  void _markComplete(int index) {
    setState(() {
      _animationComplete[index] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int i = 0; i < widget.pointsList.length; i++)
          if (!_animationComplete[i])
            PointPopAnimation(
              points: widget.pointsList[i],
              startPosition: Offset(
                widget.startPosition.dx + (i * 20 - (widget.pointsList.length * 10)).toDouble(),
                widget.startPosition.dy,
              ),
              onComplete: () => _markComplete(i),
            ),
      ],
    );
  }
}
