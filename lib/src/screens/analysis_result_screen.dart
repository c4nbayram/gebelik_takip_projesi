import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/premium_gate.dart';
import '../models/app_models.dart';
import '../providers/premium_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';
import '../widgets/tracking_insight_sections.dart';

class AnalysisResultScreen extends StatelessWidget {
  const AnalysisResultScreen({
    super.key,
    required this.result,
    required this.insight,
    required this.weekEntries,
    required this.selectedWeek,
  });

  final HealthAnalyzeResult result;
  final TrackingInsight insight;
  final List<WeekEntry> weekEntries;
  final int selectedWeek;

  @override
  Widget build(BuildContext context) {
    final palette = _RiskPalette.from(result.riskLabel);

    return Scaffold(
      appBar: AppBar(
        title: Text("Hafta ${result.weekNo} • Analiz"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            _riskHero(context, palette),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Kisisel Rehberlik Notu",
              subtitle: "Saglik notlari ve tum haftalar birlikte yorumlandi",
              icon: Icons.auto_awesome_rounded,
            ),
            if (context
                .watch<PremiumProvider>()
                .hasFeature(PremiumFeatures.detailedAssessment))
              TrackingInsightCard(insight: insight)
            else
              const PremiumLockCard(
                title: "Detaylı rehberlik notu premium'a özel",
                message:
                    "Risk skorunu ücretsiz görüyorsun. Sağlık notların ve tüm haftaların kural tabanlı olarak değerlendirildiği kişiselleştirilmiş rehberlik notları için premium üyeliğe geç.",
                feature: PremiumFeatures.detailedAssessment,
              ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: "Hesaplama Detaylari",
              subtitle: result.fromDataset
                  ? "Dogrulanmis veri setine gore KNN"
                  : "Cevrimdisi tahmin (yerel)",
              icon: Icons.bubble_chart_rounded,
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sourceBadge(context, result.fromDataset),
                  const SizedBox(height: AppSpacing.sm),
                  _detailRow(
                    context,
                    icon: Icons.scatter_plot_rounded,
                    label: "Bakilan komsu sayisi (K)",
                    value: "${result.knnK}",
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _neighborBar(context, result),
                  const SizedBox(height: AppSpacing.sm),
                  _detailRow(
                    context,
                    icon: Icons.priority_high_rounded,
                    label: "Yuksek riskli komsu",
                    value: "${result.knnHigh}",
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _detailRow(
                    context,
                    icon: Icons.warning_amber_rounded,
                    label: "Orta riskli komsu",
                    value: "${result.knnMid}",
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _detailRow(
                    context,
                    icon: Icons.check_circle_outline_rounded,
                    label: "Dusuk riskli komsu",
                    value: "${result.knnLow}",
                  ),
                  if (result.fromDataset) ...[
                    const SizedBox(height: AppSpacing.xs),
                    _detailRow(
                      context,
                      icon: Icons.straighten_rounded,
                      label: "Ortalama benzerlik mesafesi",
                      value: result.avgDistance.toStringAsFixed(2),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  _detailRow(
                    context,
                    icon: Icons.percent_rounded,
                    label: "Toplam risk skoru",
                    value: "${(result.riskScore * 100).toStringAsFixed(1)}%",
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    result.fromDataset
                        ? "Bu sonuc, olcumlerinin dogrulanmis maternal saglik veri setindeki en yakin ${result.knnK} ornekle karsilastirilmasiyla hesaplandi."
                        : "Sunucuya ulasilamadigi icin sonuc cihaz uzerindeki kural tabanli tahminle uretildi. Baglanti saglaninca veri setiyle yeniden degerlendirilecek.",
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Tum Haftalarin Grafigi",
              subtitle: "Risk ve olcumlerin haftalik karsilastirmasi",
              icon: Icons.stacked_line_chart_rounded,
            ),
            TrackingTrendsCard(insight: insight),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Hafta Hafta Farklar",
              subtitle: "Secili hafta ve onceki kayit arasindaki degisim",
              icon: Icons.compare_arrows_rounded,
            ),
            TrackingComparisonsCard(insight: insight),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Diger Haftalar",
              subtitle: "Farkli hafta kayitlarini gor",
              icon: Icons.history_rounded,
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Farkli bir hafta secerek kayitlarini gorebilir ve gerekirse duzenleyebilirsin.",
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    onPressed: () => _openWeekPicker(context),
                    label: "Haftalari Gor",
                    icon: Icons.calendar_month_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riskHero(BuildContext context, _RiskPalette palette) {
    final riskPercent = (result.riskScore * 100).toStringAsFixed(1);
    return GradientHeroCard(
      gradient: palette.gradient,
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(palette.icon, color: Colors.white, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      "RISK DURUMU",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                "Hafta ${result.weekNo}",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                result.riskLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  height: 1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  "%$riskPercent",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            palette.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                FractionallySizedBox(
                  widthFactor: result.riskScore.clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: context.palette.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: context.palette.borderSoft),
          ),
          child: Icon(icon, size: 16, color: context.palette.primarySoft),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.palette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _sourceBadge(BuildContext context, bool fromDataset) {
    final color =
        fromDataset ? context.palette.success : context.palette.warning;
    final bg =
        fromDataset ? context.palette.successBg : context.palette.warningBg;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fromDataset ? Icons.verified_rounded : Icons.cloud_off_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 6),
          Text(
            fromDataset ? "DOGRULANMIS VERI SETI" : "CEVRIMDISI TAHMIN",
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _neighborBar(BuildContext context, HealthAnalyzeResult result) {
    final total = result.knnHigh + result.knnMid + result.knnLow;
    if (total <= 0) return const SizedBox.shrink();
    int flex(int v) => v <= 0 ? 0 : v;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Row(
        children: [
          Expanded(
            flex: flex(result.knnLow),
            child: Container(height: 10, color: context.palette.success),
          ),
          Expanded(
            flex: flex(result.knnMid),
            child: Container(height: 10, color: context.palette.warning),
          ),
          Expanded(
            flex: flex(result.knnHigh),
            child: Container(height: 10, color: context.palette.danger),
          ),
        ],
      ),
    );
  }

  Future<void> _openWeekPicker(BuildContext context) async {
    final existing = weekEntries.map((e) => e.weekNo).toSet();
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.palette.bgBase,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: context.palette.primarySoft, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      "Hafta Sec",
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.palette.borderSoft),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: 40,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xxs),
                  itemBuilder: (context, i) {
                    final week = i + 1;
                    final hasData = existing.contains(week);
                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, week),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color:
                                context.palette.surface.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border:
                                Border.all(color: context.palette.borderSoft),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  gradient: hasData
                                      ? LinearGradient(
                                          colors: context.palette.brandGradient,
                                        )
                                      : null,
                                  color: hasData
                                      ? null
                                      : context.palette.surfaceHigh,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xs),
                                  border: Border.all(
                                    color: hasData
                                        ? Colors.transparent
                                        : context.palette.borderSoft,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "$week",
                                  style: TextStyle(
                                    color: hasData
                                        ? Colors.white
                                        : context.palette.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "$week. Hafta",
                                      style: TextStyle(
                                        color: context.palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      hasData ? "Kayit var" : "Bos",
                                      style: TextStyle(
                                        color: context.palette.textMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                hasData
                                    ? Icons.edit_rounded
                                    : Icons.add_rounded,
                                size: 18,
                                color: hasData
                                    ? context.palette.primarySoft
                                    : context.palette.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && context.mounted) {
      Navigator.pop(context, picked);
    }
  }
}

class _RiskPalette {
  const _RiskPalette({
    required this.gradient,
    required this.icon,
    required this.description,
  });

  final List<Color> gradient;
  final IconData icon;
  final String description;

  static _RiskPalette from(String label) {
    final l = label.toLowerCase();
    if (l.contains("yuksek") || l.contains("high")) {
      return const _RiskPalette(
        gradient: [Color(0xFFB84A5E), Color(0xFFFF7E8C)],
        icon: Icons.priority_high_rounded,
        description:
            "Olcumlerin ilgili aralikta yuksek risk isareti veriyor. Bir saglik uzmanina danismani oneririz.",
      );
    }
    if (l.contains("orta") || l.contains("mid")) {
      return const _RiskPalette(
        gradient: [Color(0xFFB87A3E), Color(0xFFF3B96C)],
        icon: Icons.warning_amber_rounded,
        description:
            "Olcumlerin ortanin ustunde seyir ediyor. Takibi sik yapmanda fayda var.",
      );
    }
    if (l.contains("dusuk") || l.contains("low")) {
      return const _RiskPalette(
        gradient: [Color(0xFF3F9E7A), Color(0xFF6ED3A6)],
        icon: Icons.check_circle_rounded,
        description:
            "Olcumlerin stabil seyir ediyor. Rutin takibe devam edebilirsin.",
      );
    }
    return const _RiskPalette(
      gradient: [Color(0xFF7C6CF0), Color(0xFF9B7BF0)],
      icon: Icons.monitor_heart_rounded,
      description: "Risk profili degerlendirildi.",
    );
  }
}
