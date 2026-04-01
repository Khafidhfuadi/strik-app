import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';

class AiResponseLoadingState extends StatefulWidget {
  final String title;
  final String headline;
  final String helperText;
  final List<String> phases;
  final IconData icon;
  final Color accentColor;

  const AiResponseLoadingState({
    super.key,
    required this.title,
    required this.headline,
    required this.helperText,
    required this.phases,
    this.icon = Icons.auto_awesome_rounded,
    this.accentColor = AppTheme.primary,
  }) : assert(phases.length > 1, 'phases must contain at least 2 items');

  @override
  State<AiResponseLoadingState> createState() => _AiResponseLoadingStateState();
}

class _AiResponseLoadingStateState extends State<AiResponseLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _phaseTimer;
  int _activePhase = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _phaseTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      setState(() {
        _activePhase = (_activePhase + 1) % widget.phases.length;
      });
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = 0.88 + (math.sin(_controller.value * math.pi * 2) * 0.12);
        final shimmer =
            0.18 + (math.sin((_controller.value * math.pi * 2) - 0.8) * 0.08);

        return Container(
          key: const ValueKey('ai-loading-state'),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.95),
                            accent.withValues(alpha: 0.18),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.32),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, color: Colors.black, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.2),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            widget.phases[_activePhase],
                            key: ValueKey(_activePhase),
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: pulse.clamp(0.0, 1.0),
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.headline,
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.helperText,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(widget.phases.length, (index) {
                  final isDone = index < _activePhase;
                  final isActive = index == _activePhase;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? accent.withValues(alpha: 0.16)
                          : Colors.white.withValues(
                              alpha: isDone ? 0.07 : 0.03,
                            ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? accent.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_rounded
                              : isActive
                              ? Icons.more_horiz_rounded
                              : Icons.circle_outlined,
                          size: 14,
                          color: isDone
                              ? accent
                              : isActive
                              ? accent
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.phases[index],
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive || isDone
                                ? AppTheme.textPrimary
                                : Colors.white.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSkeletonLine(
                      widthFactor: 0.94,
                      opacityBoost: shimmer,
                    ),
                    const SizedBox(height: 10),
                    _buildSkeletonLine(
                      widthFactor: 0.76,
                      opacityBoost: shimmer * 0.9,
                    ),
                    const SizedBox(height: 10),
                    _buildSkeletonLine(
                      widthFactor: 0.58,
                      opacityBoost: shimmer * 0.8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tenang, insight bakal muncul otomatis begitu Coach selesai ngerangkai jawabannya.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.58),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLine({
    required double widthFactor,
    required double opacityBoost,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: opacityBoost.clamp(0.08, 0.3)),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
