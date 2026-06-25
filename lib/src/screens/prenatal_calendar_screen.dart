import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';

class PrenatalCalendarScreen extends StatelessWidget {
  const PrenatalCalendarScreen({super.key});

  static const List<(String, String, String)> _items = [
    (
      "6–8",
      "İlk muayene & ultrason",
      "Gebeliğin doğrulanması, kalp atışı kontrolü, tahmini doğum tarihi."
    ),
    (
      "11–14",
      "İkili tarama + NT ultrasonu",
      "Kromozom anomalisi riski için kan testi ve ense kalınlığı ölçümü."
    ),
    (
      "15–20",
      "Üçlü / dörtlü tarama",
      "Nöral tüp ve kromozom anomalileri için kan taraması."
    ),
    (
      "18–22",
      "Detaylı (anomali) ultrasonu",
      "Organ gelişiminin ayrıntılı değerlendirilmesi."
    ),
    (
      "24–28",
      "Şeker yükleme testi",
      "Gestasyonel diyabet taraması, kan sayımı kontrolü."
    ),
    (
      "28–30",
      "Anti-D (gerekirse)",
      "Rh uyuşmazlığı olan annelerde koruyucu iğne."
    ),
    (
      "28+",
      "Tetanoz aşısı (gerekirse)",
      "Aşı durumuna göre hekimin önerisiyle yapılır."
    ),
    ("35–37", "GBS kültürü", "Grup B Streptokok taraması (doğum öncesi)."),
    (
      "32–36",
      "Büyüme ultrasonu",
      "Bebeğin gelişiminin ve pozisyonunun değerlendirilmesi."
    ),
    (
      "36–40",
      "Haftalık kontrol & NST",
      "Düzenli takip, non-stres test, doğuma hazırlık değerlendirmesi."
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Prenatal Takvim")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
          children: [
            const InfoBanner(
              message:
                  "Aşağıdaki haftalar yaklaşık değerlerdir. Kesin test ve aşı zamanlamasını doktorun belirler.",
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final i in _items) ...[
              _tile(p, i.$1, i.$2, i.$3),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(AppPalette p, String weeks, String title, String desc) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: p.brandGradient),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              children: [
                Text(weeks,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const Text("hafta",
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        color: p.textMuted, fontSize: 12.5, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
