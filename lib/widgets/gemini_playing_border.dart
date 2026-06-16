import 'package:flutter/material.dart';

class GeminiPlayingBorder extends StatefulWidget {
  final bool isPlaying;
  final Widget child;

  const GeminiPlayingBorder({
    super.key,
    required this.isPlaying,
    required this.child,
  });

  @override
  State<GeminiPlayingBorder> createState() => _GeminiPlayingBorderState();
}

class _GeminiPlayingBorderState extends State<GeminiPlayingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _palette = [
    Color(0xFF1A73E8), // Google blue
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFF1A73E8), // seamless loop
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(GeminiPlayingBorder old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !old.isPlaying) {
      _ctrl.repeat();
    } else if (!widget.isPlaying && old.isPlaying) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _lerp(double t) {
    t = t % 1.0;
    final n = _palette.length - 1;
    final s = t * n;
    final i = s.floor().clamp(0, n - 1);
    double blend = s - i;
    // Smoothstep: 3t²−2t³ — eases in and out at every color boundary
    blend = blend * blend * (3.0 - 2.0 * blend);
    return Color.lerp(_palette[i], _palette[i + 1], blend)!;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: widget.isPlaying ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) {
                  final t = _ctrl.value;
                  final innerColor = _lerp(t);
                  final outerColor = _lerp((t + 0.4) % 1.0);
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        // radius 1.1 ensures the gradient is fully transparent
                        // at or before every card edge (top, bottom, sides, corners)
                        radius: 1.1,
                        colors: [
                          innerColor.withValues(alpha: 0.48),
                          outerColor.withValues(alpha: 0.12),
                          outerColor.withValues(alpha: 0.01),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.28, 0.52, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
