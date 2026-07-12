import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Confetti particle for celebration animation
class ConfettiPiece {
  final Offset startPosition;
  final Offset velocity;
  final Color color;
  final double rotation;
  final double rotationSpeed;
  final double size;
  late Offset currentPosition;

  ConfettiPiece({
    required this.startPosition,
    required this.velocity,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
  }) {
    currentPosition = startPosition;
  }

  void update(double deltaTime, double gravity) {
    // Update position based on velocity
    currentPosition = Offset(
      currentPosition.dx + velocity.dx * deltaTime,
      currentPosition.dy + velocity.dy * deltaTime,
    );

    // Apply gravity
    currentPosition = Offset(
      currentPosition.dx,
      currentPosition.dy + gravity * deltaTime * deltaTime,
    );
  }
}

/// Confetti animation widget for level completion celebrations
class ConfettiAnimation extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;
  final int pieceCount;

  const ConfettiAnimation({
    Key? key,
    this.duration = const Duration(seconds: 3),
    this.onComplete,
    this.pieceCount = 50,
  }) : super(key: key);

  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<ConfettiPiece> confetti;
  late math.Random _random;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _initializeConfetti();

    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animationController.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  void _initializeConfetti() {
    confetti = List.generate(widget.pieceCount, (_) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 150 + _random.nextDouble() * 250;
      final velocity = Offset(
        math.cos(angle) * speed,
        math.sin(angle) * speed - 50, // Initial upward bias
      );

      return ConfettiPiece(
        startPosition: Offset(
          MediaQuery.of(context).size.width / 2 + _random.nextDouble() * 100 - 50,
          MediaQuery.of(context).size.height / 2,
        ),
        velocity: velocity,
        color: _getRandomColor(),
        rotation: _random.nextDouble() * 2 * math.pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
        size: 4 + _random.nextDouble() * 8,
      );
    });
  }

  Color _getRandomColor() {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // Update confetti positions
        final deltaTime = 1 / 60; // Assume 60 FPS
        final gravity = 500.0;
        for (var piece in confetti) {
          piece.update(deltaTime, gravity);
        }

        return Stack(
          children: [
            ...confetti.map((piece) {
              // Calculate opacity - fade out over time
              final opacity = math.max(
                0.0,
                1 - (_animationController.value * 1.2),
              );

              return Positioned(
                left: piece.currentPosition.dx,
                top: piece.currentPosition.dy,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: piece.rotation + (piece.rotationSpeed * _animationController.value),
                    child: Container(
                      width: piece.size,
                      height: piece.size,
                      decoration: BoxDecoration(
                        color: piece.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
