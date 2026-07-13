import 'dart:math';
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../services/sound_service.dart';

/// Common celebration effects (animation + sound), Duolingo-style.
///
/// Call from anywhere with a single line:
///   Celebration.correct(context);           // star burst + happy chime
///   Celebration.lessonComplete(context);    // confetti rain + fanfare
///   Celebration.xpPop(context, 10);         // floating "+10 XP"
///   Celebration.reward(context);            // gold coin burst + coin sound
///   Celebration.unlock(context);            // sparkle burst + unlock sound
///   Celebration.confetti(context);          // confetti rain (no sound)
class Celebration {
  static final SoundService _sound = SoundService();
  static bool _soundReady = false;

  static void _ensureSound() {
    if (!_soundReady) {
      _soundReady = true;
      _sound.init();
    }
  }

  /// Quick gold star burst from the center + correct-answer chime.
  static void correct(BuildContext context, {bool withSound = true}) {
    _ensureSound();
    if (withSound) _sound.playCorrectAnswer();
    _overlay(
      context,
      (done) => _ParticleBurst.starBurst(onComplete: done),
    );
  }

  /// Full-screen confetti rain + level-complete fanfare.
  static void lessonComplete(BuildContext context, {bool withSound = true}) {
    _ensureSound();
    if (withSound) _sound.playLevelComplete();
    _overlay(
      context,
      (done) => _ParticleBurst.confettiRain(onComplete: done),
    );
  }

  /// Confetti rain only (no sound) — for custom compositions.
  static void confetti(BuildContext context) {
    _overlay(
      context,
      (done) => _ParticleBurst.confettiRain(onComplete: done),
    );
  }

  /// Floating "+N XP" text that rises and fades from the center.
  static void xpPop(BuildContext context, int xp) {
    _overlay(
      context,
      (done) => _FloatingText(text: '+$xp XP', onComplete: done),
    );
  }

  /// Gold coin burst + coin ding — for treasure / point rewards.
  static void reward(BuildContext context, {bool withSound = true}) {
    _ensureSound();
    if (withSound) _sound.playPointRedemption();
    _overlay(
      context,
      (done) => _ParticleBurst.coinBurst(onComplete: done),
    );
  }

  /// Sparkle burst + unlock chime — for cosmetics / achievements.
  static void unlock(BuildContext context, {bool withSound = true}) {
    _ensureSound();
    if (withSound) _sound.playCosmeticUnlock();
    _overlay(
      context,
      (done) => _ParticleBurst.starBurst(
        colors: const [
          DuolingoColors.specialPurple,
          DuolingoColors.informationBlue,
          DuolingoColors.rewardYellow,
          Colors.white,
        ],
        onComplete: done,
      ),
    );
  }

  /// Streak milestone: confetti + rising sweep sound.
  static void streak(BuildContext context, {bool withSound = true}) {
    _ensureSound();
    if (withSound) _sound.playStreakMilestone();
    _overlay(
      context,
      (done) => _ParticleBurst.confettiRain(onComplete: done),
    );
  }

  static void _overlay(
    BuildContext context,
    Widget Function(VoidCallback done) builder,
  ) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: builder(() {
          if (entry.mounted) entry.remove();
        }),
      ),
    );
    overlay.insert(entry);
  }
}

enum _Shape { circle, rect, star }

/// One particle with analytic motion: pos(t) = start + v*t + 0.5*g*t^2 (+sway)
class _Particle {
  final Offset start;
  final Offset velocity;
  final double gravity;
  final double swayAmp;
  final double swayFreq;
  final double swayPhase;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;
  final _Shape shape;
  final double delay; // 0..0.5 fraction of total duration
  final double life; // fraction of remaining time this particle lives

  _Particle({
    required this.start,
    required this.velocity,
    required this.gravity,
    required this.color,
    required this.size,
    required this.shape,
    this.swayAmp = 0,
    this.swayFreq = 0,
    this.swayPhase = 0,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.delay = 0,
    this.life = 1,
  });
}

class _ParticleBurst extends StatefulWidget {
  final Duration duration;
  final VoidCallback onComplete;
  final List<_Particle> Function(Size size, Random random) factory;

  const _ParticleBurst({
    required this.duration,
    required this.onComplete,
    required this.factory,
  });

  /// Confetti raining from the top across the whole screen.
  factory _ParticleBurst.confettiRain({required VoidCallback onComplete}) {
    return _ParticleBurst(
      duration: const Duration(milliseconds: 2500),
      onComplete: onComplete,
      factory: (size, rnd) {
        const colors = [
          DuolingoColors.primaryGreen,
          DuolingoColors.informationBlue,
          DuolingoColors.rewardYellow,
          DuolingoColors.streakOrange,
          DuolingoColors.mistakeRed,
          DuolingoColors.specialPurple,
        ];
        return List.generate(120, (_) {
          return _Particle(
            start: Offset(
              rnd.nextDouble() * size.width,
              -20 - rnd.nextDouble() * size.height * 0.3,
            ),
            velocity: Offset(0, 120 + rnd.nextDouble() * 160),
            gravity: 150,
            swayAmp: 15 + rnd.nextDouble() * 35,
            swayFreq: 2 + rnd.nextDouble() * 3,
            swayPhase: rnd.nextDouble() * 2 * pi,
            color: colors[rnd.nextInt(colors.length)],
            size: 6 + rnd.nextDouble() * 8,
            rotation: rnd.nextDouble() * 2 * pi,
            rotationSpeed: (rnd.nextDouble() - 0.5) * 12,
            shape: rnd.nextBool() ? _Shape.rect : _Shape.circle,
            delay: rnd.nextDouble() * 0.3,
          );
        });
      },
    );
  }

  /// Gold stars bursting outward from the center.
  factory _ParticleBurst.starBurst({
    required VoidCallback onComplete,
    List<Color> colors = const [
      DuolingoColors.rewardYellow,
      DuolingoColors.treasureGold,
      DuolingoColors.streakOrange,
      Colors.white,
    ],
  }) {
    return _ParticleBurst(
      duration: const Duration(milliseconds: 900),
      onComplete: onComplete,
      factory: (size, rnd) {
        final center = Offset(size.width / 2, size.height * 0.45);
        return List.generate(26, (_) {
          final angle = rnd.nextDouble() * 2 * pi;
          final speed = 220 + rnd.nextDouble() * 320;
          return _Particle(
            start: center,
            velocity: Offset(cos(angle) * speed, sin(angle) * speed - 80),
            gravity: 500,
            color: colors[rnd.nextInt(colors.length)],
            size: 8 + rnd.nextDouble() * 12,
            rotation: rnd.nextDouble() * 2 * pi,
            rotationSpeed: (rnd.nextDouble() - 0.5) * 15,
            shape: _Shape.star,
          );
        });
      },
    );
  }

  /// Gold coins fountaining upward from the bottom center.
  factory _ParticleBurst.coinBurst({required VoidCallback onComplete}) {
    return _ParticleBurst(
      duration: const Duration(milliseconds: 1200),
      onComplete: onComplete,
      factory: (size, rnd) {
        final origin = Offset(size.width / 2, size.height * 0.7);
        return List.generate(30, (_) {
          final angle = -pi / 2 + (rnd.nextDouble() - 0.5) * pi * 0.7;
          final speed = 300 + rnd.nextDouble() * 300;
          return _Particle(
            start: origin,
            velocity: Offset(cos(angle) * speed, sin(angle) * speed),
            gravity: 700,
            color: rnd.nextBool()
                ? DuolingoColors.rewardYellow
                : DuolingoColors.treasureGold,
            size: 10 + rnd.nextDouble() * 8,
            rotation: rnd.nextDouble() * 2 * pi,
            rotationSpeed: (rnd.nextDouble() - 0.5) * 10,
            shape: _Shape.circle,
          );
        });
      },
    );
  }

  @override
  State<_ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<_ParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<_Particle>? _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _particles ??= widget.factory(size, _random);
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: size,
            painter: _ParticlePainter(
              particles: _particles!,
              t: _controller.value,
              totalSeconds:
                  widget.duration.inMilliseconds / 1000.0,
            ),
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1
  final double totalSeconds;

  _ParticlePainter({
    required this.particles,
    required this.t,
    required this.totalSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final local = (t - p.delay) / (1 - p.delay);
      if (local <= 0) continue;
      final seconds = local * totalSeconds;

      final dx = p.start.dx +
          p.velocity.dx * seconds +
          p.swayAmp * sin(p.swayFreq * seconds * 2 * pi + p.swayPhase);
      final dy = p.start.dy +
          p.velocity.dy * seconds +
          0.5 * p.gravity * seconds * seconds;

      final opacity = (1 - local).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(opacity);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotation + p.rotationSpeed * seconds);

      switch (p.shape) {
        case _Shape.circle:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case _Shape.rect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: p.size, height: p.size * 0.6),
              const Radius.circular(2),
            ),
            paint,
          );
          break;
        case _Shape.star:
          canvas.drawPath(_starPath(p.size), paint);
          break;
      }
      canvas.restore();
    }
  }

  Path _starPath(double size) {
    final path = Path();
    final outer = size / 2;
    final inner = outer * 0.45;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / 5;
      final point = Offset(cos(a) * r, sin(a) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => oldDelegate.t != t;
}

/// Floating text ("+10 XP") that scales in, rises, and fades out.
class _FloatingText extends StatefulWidget {
  final String text;
  final VoidCallback onComplete;

  const _FloatingText({required this.text, required this.onComplete});

  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rise;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..forward().whenComplete(widget.onComplete);

    _scale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.3, curve: Curves.elasticOut),
    );
    _rise = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1, curve: Curves.easeIn),
    );
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
      builder: (context, _) => Center(
        child: Transform.translate(
          offset: Offset(0, -90 * _rise.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: 1 - _fade.value,
              child: Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: DuolingoColors.rewardYellow,
                  shadows: [
                    Shadow(
                      color: DuolingoColors.streakOrange,
                      offset: Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
