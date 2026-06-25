import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'app_common.dart';

class TrackingInsightCard extends StatelessWidget {
  const TrackingInsightCard({super.key, required this.insight});

  final TrackingInsight insight;

  @override
  Widget build(BuildContext context) {
    return GradientHeroCard(
      gradient: const [Color(0xFF6F5AE0), Color(0xFF9B7BF0)],
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 12, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      "GEBELIK REHBERI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (insight.focusWeek != null)
                Text(
                  "Odak hafta ${insight.focusWeek}",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            insight.headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            insight.summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _heroStat(label: "Kayit", value: "${insight.trackedWeeks} hafta"),
              if (insight.trackedWeeks > 0)
                _heroStat(
                  label: "Ort. risk",
                  value:
                      "%${(insight.averageRiskScore * 100).toStringAsFixed(0)}",
                ),
              if (insight.highestRiskWeek != null &&
                  insight.highestRiskScore != null)
                _heroStat(
                  label: "En yuksek",
                  value:
                      "${insight.highestRiskWeek}. hf • %${(insight.highestRiskScore! * 100).toStringAsFixed(0)}",
                ),
            ],
          ),
          if (insight.medicalFlags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: insight.medicalFlags
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (insight.recommendations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...insight.recommendations.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.favorite_rounded,
                          size: 13, color: Colors.white),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.94),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        "$label  $value",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TrackingComparisonsCard extends StatelessWidget {
  const TrackingComparisonsCard({super.key, required this.insight});

  final TrackingInsight insight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (insight.comparisons.isEmpty) {
      return const EmptyState(
        icon: Icons.compare_arrows_rounded,
        title: "Karsilastirma icin veri bekleniyor",
        description:
            "Ilk kayittan sonra secili hafta onceki haftalarla otomatik karsilastirilir.",
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth > 520;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - AppSpacing.sm) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: insight.comparisons
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 34,
                              width: 34,
                              decoration: BoxDecoration(
                                color: _metricColor(item.key)
                                    .withValues(alpha: 0.16),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Icon(_metricIcon(item.key),
                                  size: 18, color: _metricColor(item.key)),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.status,
                                    style: TextStyle(
                                      color: _statusColor(item.status, p),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _directionBadge(item.direction, item.status, p),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _formatValue(item.currentValue, item.unit),
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.previousValue == null
                              ? "Ilk baz kaydi"
                              : "Onceki kayit: ${_formatValue(item.previousValue!, item.unit)}",
                          style: TextStyle(
                            color: p.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          item.summary,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class TrackingTrendsCard extends StatelessWidget {
  const TrackingTrendsCard({super.key, required this.insight});

  final TrackingInsight insight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (insight.trendSeries.isEmpty) {
      return const EmptyState(
        icon: Icons.stacked_line_chart_rounded,
        title: "Grafik hazir degil",
        description:
            "Haftalik olcumler girdikce tum haftalarin degerleri bu bolumde grafiksel olarak gorunecek.",
      );
    }

    final riskSeries =
        insight.trendSeries.cast<MetricTrendSeries?>().firstWhere(
              (item) => item?.key == "riskScore",
              orElse: () => null,
            );
    final metricSeries = insight.trendSeries
        .where((item) => item.key != "riskScore")
        .toList(growable: false);

    return Column(
      children: [
        if (riskSeries != null)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Risk trendi",
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Tum haftalardaki risk skorunun seyri",
                  style: TextStyle(color: p.textMuted, fontSize: 12),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 180,
                  child: _BigTrendChart(
                    series: riskSeries,
                    accent: p.accent,
                    highlightWeek: insight.focusWeek,
                  ),
                ),
              ],
            ),
          ),
        if (metricSeries.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 520;
              final itemWidth = twoColumns
                  ? (constraints.maxWidth - AppSpacing.sm) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: metricSeries
                    .map(
                      (series) => SizedBox(
                        width: itemWidth,
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height: 30,
                                    width: 30,
                                    decoration: BoxDecoration(
                                      color: _metricColor(series.key)
                                          .withValues(alpha: 0.16),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: Icon(_metricIcon(series.key),
                                        size: 16,
                                        color: _metricColor(series.key)),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      series.label,
                                      style: TextStyle(
                                        color: p.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatValue(
                                        series.points.last.value, series.unit),
                                    style: TextStyle(
                                      color: p.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                height: 72,
                                child: _SparklineChart(
                                  series: series,
                                  accent: _metricColor(series.key),
                                  highlightWeek: insight.focusWeek,
                                  gridColor: p.borderSoft,
                                  dotColor: p.surface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                "${series.points.first.weekNo}. hafta - ${series.points.last.weekNo}. hafta",
                                style:
                                    TextStyle(color: p.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _BigTrendChart extends StatelessWidget {
  const _BigTrendChart({
    required this.series,
    required this.accent,
    required this.highlightWeek,
  });

  final MetricTrendSeries series;
  final Color accent;
  final int? highlightWeek;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final minValue = series.points.map((e) => e.value).reduce(math.min);
    final maxValue = series.points.map((e) => e.value).reduce(math.max);
    final paddedMin = minValue == maxValue ? minValue - 1 : minValue;
    final paddedMax = minValue == maxValue ? maxValue + 1 : maxValue;
    final axisStyle = TextStyle(color: p.textMuted, fontSize: 10.5);

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paddedMax.toStringAsFixed(0), style: axisStyle),
                    Text(((paddedMax + paddedMin) / 2).toStringAsFixed(0),
                        style: axisStyle),
                    Text(paddedMin.toStringAsFixed(0), style: axisStyle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: CustomPaint(
                  painter: _TrendPainter(
                    points: series.points,
                    accent: accent,
                    highlightWeek: highlightWeek,
                    strokeWidth: 3,
                    showDots: true,
                    gridColor: p.borderSoft,
                    dotColor: p.surface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text("${series.points.first.weekNo}. hafta", style: axisStyle),
            const Spacer(),
            Text("${series.points.last.weekNo}. hafta", style: axisStyle),
          ],
        ),
      ],
    );
  }
}

class _SparklineChart extends StatelessWidget {
  const _SparklineChart({
    required this.series,
    required this.accent,
    required this.highlightWeek,
    required this.gridColor,
    required this.dotColor,
  });

  final MetricTrendSeries series;
  final Color accent;
  final int? highlightWeek;
  final Color gridColor;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(
        points: series.points,
        accent: accent,
        highlightWeek: highlightWeek,
        strokeWidth: 2.6,
        showDots: false,
        gridColor: gridColor,
        dotColor: dotColor,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.points,
    required this.accent,
    required this.highlightWeek,
    required this.strokeWidth,
    required this.showDots,
    required this.gridColor,
    required this.dotColor,
  });

  final List<TrendPoint> points;
  final Color accent;
  final int? highlightWeek;
  final double strokeWidth;
  final bool showDots;
  final Color gridColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.26),
          accent.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final values = points.map((e) => e.value).toList(growable: false);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;
    final stepX = points.length == 1 ? 0.0 : size.width / (points.length - 1);

    Offset offsetFor(int index) {
      final value = points[index].value;
      final t = (value - minValue) / range;
      final y = size.height - (t * (size.height - 10)) - 5;
      return Offset(stepX * index, y);
    }

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < points.length; i++) {
      final offset = offsetFor(i);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
        fillPath.moveTo(offset.dx, size.height);
        fillPath.lineTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
        fillPath.lineTo(offset.dx, offset.dy);
      }
    }
    fillPath.lineTo(offsetFor(points.length - 1).dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      final offset = offsetFor(i);
      final isHighlight =
          highlightWeek != null && points[i].weekNo == highlightWeek;
      if (showDots || isHighlight) {
        final dotPaint = Paint()..color = isHighlight ? dotColor : accent;
        canvas.drawCircle(offset, isHighlight ? 5 : 3, dotPaint);
        if (isHighlight) {
          canvas.drawCircle(
            offset,
            8,
            Paint()
              ..color = accent.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.accent != accent ||
        oldDelegate.highlightWeek != highlightWeek ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.showDots != showDots;
  }
}

Widget _directionBadge(TrendDirection direction, String status, AppPalette p) {
  IconData icon;
  Color color;
  switch (direction) {
    case TrendDirection.up:
      icon = Icons.north_rounded;
      color =
          status == "Dikkat" || status == "Yukseliyor" ? p.danger : p.warning;
      break;
    case TrendDirection.down:
      icon = Icons.south_rounded;
      color = p.success;
      break;
    case TrendDirection.steady:
      icon = Icons.remove_rounded;
      color = p.textMuted;
      break;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Icon(icon, size: 14, color: color),
  );
}

Color _statusColor(String status, AppPalette p) {
  switch (status) {
    case "Dikkat":
    case "Yukseliyor":
      return p.danger;
    case "Iyilesiyor":
      return p.success;
    case "Stabil":
      return p.info;
    default:
      return p.textMuted;
  }
}

Color _metricColor(String key) {
  switch (key) {
    case "systolic":
      return const Color(0xFFFF8B94);
    case "diastolic":
      return const Color(0xFFFFB36B);
    case "bloodSugar":
      return const Color(0xFFF0A93D);
    case "bodyTemp":
      return const Color(0xFFFF7C91);
    case "bmi":
      return const Color(0xFF36C39A);
    case "heartRate":
      return const Color(0xFF5B8DEF);
    case "riskScore":
      return const Color(0xFFFF8FB1);
    default:
      return const Color(0xFF7C6CF0);
  }
}

IconData _metricIcon(String key) {
  switch (key) {
    case "systolic":
      return Icons.arrow_upward_rounded;
    case "diastolic":
      return Icons.arrow_downward_rounded;
    case "bloodSugar":
      return Icons.bloodtype_outlined;
    case "bodyTemp":
      return Icons.thermostat_rounded;
    case "bmi":
      return Icons.scale_rounded;
    case "heartRate":
      return Icons.favorite_rounded;
    case "riskScore":
      return Icons.monitor_heart_rounded;
    default:
      return Icons.show_chart_rounded;
  }
}

String _formatValue(double value, String unit) {
  final decimals = unit == "°C" || unit == "kg/m²" ? 1 : 0;
  final text = value.toStringAsFixed(decimals);
  return unit == "%" ? "%$text" : "$text $unit";
}
