import 'package:flutter/material.dart';

class NeonFilledButton extends StatelessWidget {
  const NeonFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.colors = const [
      Color(0xFFD93FFF),
      Color(0xFF8F4BFF),
      Color(0xFFFF9A4F),
    ],
    this.glowColor = const Color(0xFFCB61FF),
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final List<Color> colors;
  final Color glowColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFFF7F8FF),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        );

    final gradientColors = disabled
        ? const [
            Color(0xFF4D4A66),
            Color(0xFF5A5672),
          ]
        : colors;

    return Opacity(
      opacity: disabled ? 0.62 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: disabled ? 0.08 : 0.38),
              blurRadius: disabled ? 8 : 26,
              spreadRadius: disabled ? 0 : 1.1,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: borderRadius,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: const Color(0x66FFFFFF),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 3,
                    child: IgnorePointer(
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.26),
                              Colors.white.withValues(alpha: 0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: padding,
                    child: Center(
                      child: DefaultTextStyle(
                        style: textStyle ??
                            const TextStyle(
                              color: Color(0xFFF7F8FF),
                              fontWeight: FontWeight.w700,
                            ),
                        child: IconTheme(
                          data: const IconThemeData(color: Color(0xFFF7F8FF)),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
