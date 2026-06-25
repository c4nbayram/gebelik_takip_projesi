import 'package:flutter/material.dart';

@immutable
class AppPalette {
  final Brightness brightness;

  final Color bgDeep;
  final Color bgBase;
  final Color bgElevated;

  final Color surface;
  final Color surfaceHigh;
  final Color surfaceGlass;

  final Color borderSoft;
  final Color border;
  final Color borderStrong;

  final Color primary;
  final Color primaryDeep;
  final Color primarySoft;
  final Color accent;
  final Color accentDeep;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnPrimary;

  final Color shadowColor;
  final List<Color> brandGradient;
  final List<Color> accentGradient;
  final List<Color> heroGradient;

  const AppPalette({
    required this.brightness,
    required this.bgDeep,
    required this.bgBase,
    required this.bgElevated,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceGlass,
    required this.borderSoft,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.primaryDeep,
    required this.primarySoft,
    required this.accent,
    required this.accentDeep,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnPrimary,
    required this.shadowColor,
    required this.brandGradient,
    required this.accentGradient,
    required this.heroGradient,
  });

  bool get isDark => brightness == Brightness.dark;

  Color get successBg => success.withValues(alpha: isDark ? 0.20 : 0.13);
  Color get warningBg => warning.withValues(alpha: isDark ? 0.20 : 0.14);
  Color get dangerBg => danger.withValues(alpha: isDark ? 0.20 : 0.13);
  Color get primaryBg => primary.withValues(alpha: isDark ? 0.18 : 0.10);
  Color get accentBg => accent.withValues(alpha: isDark ? 0.20 : 0.14);

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: isDark ? 0.28 : 0.10),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

  List<BoxShadow> get softShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: isDark ? 0.22 : 0.07),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  List<BoxShadow> glow(Color color, {double strength = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: strength * (isDark ? 1.0 : 0.6)),
          blurRadius: 24,
          spreadRadius: 1,
          offset: const Offset(0, 4),
        ),
      ];

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    bgDeep: Color(0xFFEDE9FF),
    bgBase: Color(0xFFF6F5FF),
    bgElevated: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1EEFF),
    surfaceGlass: Color(0x0F7C6CF0),
    borderSoft: Color(0xFFEDEAFB),
    border: Color(0xFFE3DEF6),
    borderStrong: Color(0xFFD4CDEF),
    primary: Color(0xFF7C6CF0),
    primaryDeep: Color(0xFF5B49D6),
    primarySoft: Color(0xFF6E5CEA),
    accent: Color(0xFFFF8FB1),
    accentDeep: Color(0xFFF2689A),
    success: Color(0xFF1FB68A),
    warning: Color(0xFFE2912F),
    danger: Color(0xFFF0566F),
    info: Color(0xFF4F86E8),
    textPrimary: Color(0xFF211E3D),
    textSecondary: Color(0xFF5A5680),
    textMuted: Color(0xFF918EAE),
    textOnPrimary: Color(0xFFFFFFFF),
    shadowColor: Color(0xFF6F5AE0),
    brandGradient: [Color(0xFF8C7BFF), Color(0xFF6F5AE0)],
    accentGradient: [Color(0xFFFF9FBE), Color(0xFFB58CFF)],
    heroGradient: [Color(0xFF8B79FF), Color(0xFF6A57E6)],
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    bgDeep: Color(0xFF0C0B22),
    bgBase: Color(0xFF121130),
    bgElevated: Color(0xFF1A1838),
    surface: Color(0xFF201E44),
    surfaceHigh: Color(0xFF2A2858),
    surfaceGlass: Color(0x14FFFFFF),
    borderSoft: Color(0xFF2E2C5C),
    border: Color(0xFF3A3878),
    borderStrong: Color(0xFF4A4794),
    primary: Color(0xFF8E7BFF),
    primaryDeep: Color(0xFF6F5AE0),
    primarySoft: Color(0xFFB6ABFF),
    accent: Color(0xFFFF9FBE),
    accentDeep: Color(0xFFEE7CA2),
    success: Color(0xFF5FD3A4),
    warning: Color(0xFFF0B968),
    danger: Color(0xFFFF7E8C),
    info: Color(0xFF7EC0FF),
    textPrimary: Color(0xFFF1F0FF),
    textSecondary: Color(0xFFC6C2EC),
    textMuted: Color(0xFF8B88BE),
    textOnPrimary: Color(0xFFFFFFFF),
    shadowColor: Color(0xFF000000),
    brandGradient: [Color(0xFF8F78FF), Color(0xFF6F5AE0)],
    accentGradient: [Color(0xFFFF9EBF), Color(0xFFB385FF)],
    heroGradient: [Color(0xFF3A2F72), Color(0xFF5A48B4)],
  );
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).brightness == Brightness.dark
      ? AppPalette.dark
      : AppPalette.light;
}
