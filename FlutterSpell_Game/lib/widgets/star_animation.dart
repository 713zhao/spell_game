import 'package:flutter/material.dart';

/// Animation for stars popping in sequence
class StarAnimation extends StatefulWidget {
  final int starCount;
  final double size;
  final Duration delayBetweenStars;
  final VoidCallback? onComplete;

  const StarAnimation({
    Key? key,
    required this.starCount,
    this.size = 32,
    this.delayBetweenStars = const Duration(milliseconds: 200),
    this.onComplete,
  }) : super(key: key);

  @override
  State<StarAnimation> createState() => _StarAnimationState();
}

class _StarAnimationState extends State<StarAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _controllers = List.generate(widget.starCount, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
    }).toList();
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(
        widget.delayBetweenStars * i,
        () {
          if (mounted) {
            _controllers[i].forward();
          }
        },
      );
    }

    // Call onComplete after all animations finish
    Future.delayed(
      widget.delayBetweenStars * (widget.starCount - 1) +
          const Duration(milliseconds: 600),
      () {
        if (mounted) {
          widget.onComplete?.call();
        }
      },
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.starCount, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ScaleTransition(
            scale: _scaleAnimations[index],
            child: Icon(
              Icons.star,
              color: Colors.amber,
              size: widget.size,
            ),
          ),
        );
      }),
    );
  }
}

/// Individual star pop animation
class StarPop extends StatefulWidget {
  final int starIndex;
  final Duration delay;
  final double size;

  const StarPop({
    Key? key,
    required this.starIndex,
    required this.delay,
    this.size = 48,
  }) : super(key: key);

  @override
  State<StarPop> createState() => _StarPopState();
}

class _StarPopState extends State<StarPop> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.5, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
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
        child: Icon(
          Icons.star,
          color: Colors.amber[300],
          size: widget.size,
        ),
      ),
    );
  }
}
