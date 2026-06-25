import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xxs,
        right: AppSpacing.xxs,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: p.primaryBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: p.primary),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.tone = PillTone.neutral,
  });

  final String label;
  final String value;
  final IconData? icon;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone, context.palette);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 6),
          ],
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: TextStyle(
                color: colors.foreground.withValues(alpha: 0.75),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum PillTone { neutral, primary, success, warning, danger, accent }

class ToneColors {
  final Color background;
  final Color border;
  final Color foreground;
  const ToneColors(this.background, this.border, this.foreground);
}

ToneColors toneColors(PillTone tone, AppPalette p) {
  switch (tone) {
    case PillTone.primary:
      return ToneColors(p.primaryBg, p.primary.withValues(alpha: 0.35),
          p.isDark ? p.primarySoft : p.primaryDeep);
    case PillTone.accent:
      return ToneColors(p.accentBg, p.accent.withValues(alpha: 0.35),
          p.isDark ? p.accent : p.accentDeep);
    case PillTone.success:
      return ToneColors(
          p.successBg, p.success.withValues(alpha: 0.35), p.success);
    case PillTone.warning:
      return ToneColors(
          p.warningBg, p.warning.withValues(alpha: 0.35), p.warning);
    case PillTone.danger:
      return ToneColors(p.dangerBg, p.danger.withValues(alpha: 0.35), p.danger);
    case PillTone.neutral:
      return ToneColors(p.surfaceHigh, p.borderSoft, p.textSecondary);
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.background,
    this.color,
  });

  final IconData icon;
  final double size;
  final Color? background;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: background ?? p.primaryBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: color ?? p.primary,
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.tone = PillTone.primary,
  });

  final String message;
  final IconData icon;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone, context.palette);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.foreground),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.foreground,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: p.borderSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: p.primaryBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 26, color: p.primary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.textMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
