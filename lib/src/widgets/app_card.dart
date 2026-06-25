import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppInsets.card,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.borderRadius,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? p.surface,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? p.borderSoft,
          width: 1,
        ),
        boxShadow: elevated ? p.cardShadow : p.softShadow,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: p.primary.withValues(alpha: 0.12),
        highlightColor: p.primary.withValues(alpha: 0.06),
        child: content,
      ),
    );
  }
}

class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.gradient,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final List<Color>? gradient;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.xl);
    final colors = gradient ?? p.brandGradient;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: p.glow(colors.first, strength: 0.30),
      ),
      child: child,
    );
  }
}
