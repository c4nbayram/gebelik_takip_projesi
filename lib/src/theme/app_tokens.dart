import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class AppRadius {
  AppRadius._();
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

class AppColors {
  AppColors._();

  static const Color bgDeep = Color(0xFF0B0D25);
  static const Color bgBase = Color(0xFF12142E);
  static const Color bgElevated = Color(0xFF191C3E);

  static const Color surface = Color(0xFF1E2148);
  static const Color surfaceHigh = Color(0xFF262A58);
  static const Color surfaceGlass = Color(0x22FFFFFF);

  static const Color borderSoft = Color(0xFF2E3268);
  static const Color border = Color(0xFF3A3F7A);
  static const Color borderStrong = Color(0xFF4B5097);

  static const Color primary = Color(0xFF9E8BFF);
  static const Color primaryDeep = Color(0xFF7A65E8);
  static const Color primarySoft = Color(0xFFBCB0FF);
  static const Color accent = Color(0xFFFFA6C0);
  static const Color accentDeep = Color(0xFFEE7CA2);

  static const Color success = Color(0xFF6ED3A6);
  static const Color successBg = Color(0x336ED3A6);
  static const Color warning = Color(0xFFF3B96C);
  static const Color warningBg = Color(0x33F3B96C);
  static const Color danger = Color(0xFFFF7E8C);
  static const Color dangerBg = Color(0x33FF7E8C);
  static const Color info = Color(0xFF7EC0FF);

  static const Color textPrimary = Color(0xFFF1F3FF);
  static const Color textSecondary = Color(0xFFBEC4EC);
  static const Color textMuted = Color(0xFF8A90C0);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const List<Color> brandGradient = [
    Color(0xFF8F78FF),
    Color(0xFF6F5AE0),
  ];
  static const List<Color> heroGradient = [
    Color(0xFF2A2458),
    Color(0xFF5645B4),
  ];
  static const List<Color> accentGradient = [
    Color(0xFFFF9EBF),
    Color(0xFFB385FF),
  ];
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 22,
      offset: Offset(0, 12),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double strength = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: strength),
          blurRadius: 24,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
      ];
}

class AppInsets {
  AppInsets._();
  static const EdgeInsets screen = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.xl,
  );
  static const EdgeInsets card = EdgeInsets.all(AppSpacing.md);
  static const EdgeInsets cardLarge = EdgeInsets.all(AppSpacing.lg);
}
