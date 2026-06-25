import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../core/guest_guard.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_common.dart';
import '../../widgets/app_text_field.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _weight = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = double.tryParse(_weight.text.trim().replaceAll(",", "."));
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Geçerli bir kilo gir.")),
      );
      return;
    }
    if (!await ensureSignedIn(context,
        reason: "Kilo kaydı için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await _api.upsertWeight(recordedOn: DateTime.now(), weightKg: v);
      _weight.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Kilo Takibi")),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<WeightEntry>>(
          stream: _api.weightStream(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <WeightEntry>[];
            final latest = items.isNotEmpty ? items.last : null;
            final first = items.isNotEmpty ? items.first : null;
            final change = (latest != null && first != null)
                ? latest.weightKg - first.weightKg
                : 0.0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
              children: [
                GradientHeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Güncel kilo",
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            latest == null
                                ? "—"
                                : latest.weightKg.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                height: 1),
                          ),
                          const SizedBox(width: 6),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text("kg",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                          ),
                          const Spacer(),
                          if (items.length >= 2)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                "${change >= 0 ? "+" : ""}${change.toStringAsFixed(1)} kg",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                      if (items.length >= 2) ...[
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          height: 70,
                          child: CustomPaint(
                            painter: _WeightChart(
                              values: items.map((e) => e.weightKg).toList(),
                              color: Colors.white,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: "Bugünün kilosu",
                  subtitle: "Aynı gün tekrar girersen güncellenir",
                  icon: Icons.add_circle_outline_rounded,
                ),
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _weight,
                          label: "Kilo (kg)",
                          hint: "ör. 64.5",
                          prefixIcon: Icons.monitor_weight_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 120,
                        child: PrimaryButton(
                          onPressed: _saving ? null : _save,
                          loading: _saving,
                          label: "Kaydet",
                          icon: Icons.check_rounded,
                          size: AppButtonSize.medium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const InfoBanner(
                  message:
                      "Tek bebekli gebelikte toplam ~11–16 kg artış sık önerilir; kesin aralık için doktoruna danış.",
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: "Geçmiş",
                  subtitle: "Kayıtlı ölçümlerin",
                  icon: Icons.history_rounded,
                ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.monitor_weight_rounded,
                    title: "Henüz kayıt yok",
                    description: "İlk kilonu girerek takibe başla.",
                  )
                else
                  Column(
                    children: [
                      for (final e in items.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: p.primary),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    DateFormat("dd MMMM yyyy", "tr_TR")
                                        .format(e.recordedOn),
                                    style: TextStyle(
                                        color: p.textSecondary, fontSize: 13.5),
                                  ),
                                ),
                                Text("${e.weightKg.toStringAsFixed(1)} kg",
                                    style: TextStyle(
                                        color: p.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
                                IconButton(
                                  onPressed: () => _api.deleteWeight(e.id),
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: p.danger, size: 19),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WeightChart extends CustomPainter {
  _WeightChart({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;
    final stepX = size.width / (values.length - 1);
    final line = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size);

    Offset pt(int i) {
      final t = (values[i] - minV) / range;
      return Offset(stepX * i, size.height - t * (size.height - 8) - 4);
    }

    final path = Path();
    final area = Path()..moveTo(0, size.height);
    for (int i = 0; i < values.length; i++) {
      final o = pt(i);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
      area.lineTo(o.dx, o.dy);
    }
    area.lineTo(size.width, size.height);
    area.close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
    for (int i = 0; i < values.length; i++) {
      canvas.drawCircle(pt(i), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChart old) =>
      old.values != values || old.color != color;
}
