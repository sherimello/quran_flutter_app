import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Wraps a bottom sheet's content in the same blur-in/blur-out animation
/// used by the last-read card morph. Reads the enclosing [ModalRoute]'s
/// primary animation so it blurs from full → clear on open and clear → full
/// on close. Pass [animation] explicitly when nested inside a
/// DraggableScrollableSheet (where ModalRoute lookup may miss the route).
class BlurredSheet extends StatelessWidget {
  final Widget child;
  final Animation<double>? animation;

  const BlurredSheet({super.key, required this.child, this.animation});

  @override
  Widget build(BuildContext context) {
    final anim = animation ?? ModalRoute.of(context)?.animation;
    if (anim == null) return child;

    return AnimatedBuilder(
      animation: anim,
      builder: (context, inner) {
        final t = anim.value.clamp(0.0, 1.0);
        final blur = (1.0 - t) * 21.0;

        if (blur < 0.3) return inner!;

        final blurProg = blur / 16.0;
        final edgeH = 0.05 + 0.15 * blurProg;
        final edgeV = 0.03 + 0.08 * blurProg;

        return ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
            tileMode: TileMode.decal,
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, edgeH, 1.0 - edgeH, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, edgeV, 1.0 - edgeV, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: inner!,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
