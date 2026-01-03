import 'package:flutter/material.dart';

class ThreeDotLoading extends StatefulWidget {
  final Color color;
  final double size;

  const ThreeDotLoading({
    super.key,
    this.color = Colors.black,
    this.size = 24.0,
  });

  @override
  State<ThreeDotLoading> createState() => _ThreeDotLoadingState();
}

class _ThreeDotLoadingState extends State<ThreeDotLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size / 3; // roughly 3 dots fitting in size?
    // Actually the user passed size=24 to the previous sized box.
    // If we want 3 dots, they should be small. maybe 6px radius.

    return SizedBox(
      width: widget.size * 2, // width needs to be wider for 3 dots
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Staggered delay logic
              // Cycle is 0..1.
              // Dot 1 peaks at 0.2, Dot 2 at 0.5, Dot 3 at 0.8?
              // Or use sin wave logic.

              // Time for this dot with staggering:
              double t = (_controller.value - (index * 0.2)) % 1.0;
              if (t < 0) t += 1.0;

              // Calculate opacity based on closeness to 'active' point in cycle
              // This creates a wave effect passing through dots
              double opacity =
                  0.4 + 0.6 * (1.0 - (t - 0.1).abs() * 5).clamp(0.0, 1.0);

              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: opacity, // scale with opacity for pop effect
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    margin: EdgeInsets.symmetric(horizontal: dotSize / 4),
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
