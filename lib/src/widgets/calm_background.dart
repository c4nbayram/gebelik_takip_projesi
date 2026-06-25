import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

class CalmAppBackground extends StatelessWidget {
  const CalmAppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: p.isDark
                    ? [p.bgDeep, p.bgBase, const Color(0xFF181B3E)]
                    : [
                        const Color(0xFFF3F0FF),
                        p.bgBase,
                        const Color(0xFFFDF3F8)
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -140,
          right: -90,
          child: _Blob(
            size: 300,
            color: p.primary.withValues(alpha: p.isDark ? 0.18 : 0.12),
          ),
        ),
        Positioned(
          top: 160,
          left: -100,
          child: _Blob(
            size: 220,
            color: p.accent.withValues(alpha: p.isDark ? 0.10 : 0.12),
          ),
        ),
        Positioned(
          bottom: -180,
          right: -120,
          child: _Blob(
            size: 360,
            color: p.primaryDeep.withValues(alpha: p.isDark ? 0.16 : 0.08),
          ),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
