import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

enum AppButtonSize { small, medium, large }

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.loading = false,
    this.size = AppButtonSize.medium,
    this.fullWidth = true,
    this.gradient,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool loading;
  final AppButtonSize size;
  final bool fullWidth;
  final List<Color>? gradient;

  double get _height {
    switch (size) {
      case AppButtonSize.small:
        return 40;
      case AppButtonSize.medium:
        return 52;
      case AppButtonSize.large:
        return 58;
    }
  }

  double get _fontSize {
    switch (size) {
      case AppButtonSize.small:
        return 13.5;
      case AppButtonSize.medium:
        return 15.5;
      case AppButtonSize.large:
        return 17;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final disabled = onPressed == null || loading;
    final colors = disabled
        ? [p.surfaceHigh, p.surfaceHigh]
        : (gradient ?? p.brandGradient);

    final button = Container(
      height: _height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: disabled ? null : p.glow(colors.first, strength: 0.30),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (icon != null) ...[
                          Icon(icon,
                              size: 18,
                              color: disabled ? p.textMuted : Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: disabled ? p.textMuted : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: _fontSize,
                              letterSpacing: 0,
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

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.size = AppButtonSize.medium,
    this.fullWidth = true,
    this.foregroundColor,
    this.borderColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final AppButtonSize size;
  final bool fullWidth;
  final Color? foregroundColor;
  final Color? borderColor;

  double get _height {
    switch (size) {
      case AppButtonSize.small:
        return 40;
      case AppButtonSize.medium:
        return 50;
      case AppButtonSize.large:
        return 56;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final disabled = onPressed == null;
    final fg = disabled ? p.textMuted : (foregroundColor ?? p.textPrimary);
    final bc = disabled ? p.borderSoft : (borderColor ?? p.borderStrong);

    final button = Container(
      height: _height,
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.6 : 1.0),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: bc, width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        letterSpacing: 0,
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

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.foregroundColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? context.palette.textSecondary;
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
    final style = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
    );
    if (icon == null) {
      return TextButton(
        onPressed: onPressed,
        style: style,
        child: labelWidget,
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: color),
      label: labelWidget,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
    );
  }
}
