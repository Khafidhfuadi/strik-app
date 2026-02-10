import 'dart:math';
import 'package:flutter/material.dart';

class LegendParticleBackground extends StatefulWidget {
  const LegendParticleBackground({super.key});

  @override
  State<LegendParticleBackground> createState() =>
      _LegendParticleBackgroundState();
}

class _LegendParticleBackgroundState extends State<LegendParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < 50; i++) {
        _particles.add(_generateParticle(size));
      }
    }
  }

  Particle _generateParticle(Size size) {
    return Particle(
      position: Offset(
        _random.nextDouble() * size.width,
        _random.nextDouble() * size.height,
      ),
      velocity: Offset(
        (_random.nextDouble() - 0.5) * 0.5, // Slight horizontal drift
        (_random.nextDouble() * -0.5) - 0.2, // Upward movement
      ),
      size: _random.nextDouble() * 3 + 1,
      color: const Color(
        0xFFFFD700,
      ).withOpacity(_random.nextDouble() * 0.5 + 0.1),
      lifespan: _random.nextDouble() * 0.5 + 0.5, // 0.5 to 1.0 (normalized)
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
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        _updateParticles(size);
        return CustomPaint(
          painter: ParticlePainter(_particles),
          size: Size.infinite,
        );
      },
    );
  }

  void _updateParticles(Size size) {
    for (var particle in _particles) {
      particle.position += particle.velocity;
      particle.lifespan -= 0.005; // Decay

      // If dead or out of bounds, regenerate at bottom
      if (particle.lifespan <= 0 || particle.position.dy < -50) {
        final newParticle = _generateParticle(size);
        particle.position = Offset(
          _random.nextDouble() * size.width,
          size.height + 10,
        );
        particle.velocity = newParticle.velocity;
        particle.size = newParticle.size;
        particle.color = newParticle.color;
        particle.lifespan = 1.0;
      }
    }
  }
}

class Particle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double lifespan;

  Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.lifespan,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(
          (particle.color.opacity * particle.lifespan).clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill;

      // Draw glowing effect (blur)
      final glowPaint = Paint()
        ..color = particle.color.withOpacity(
          (particle.color.opacity * particle.lifespan * 0.5).clamp(0.0, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(particle.position, particle.size, glowPaint);
      canvas.drawCircle(particle.position, particle.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
