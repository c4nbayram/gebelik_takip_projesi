import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';

class FoodSafetyScreen extends StatelessWidget {
  const FoodSafetyScreen({super.key});

  static const List<String> _safe = [
    "İyi pişmiş et, tavuk ve balık",
    "Pastörize süt, yoğurt ve peynir",
    "İyi yıkanmış meyve ve sebze",
    "İyice pişmiş yumurta",
    "Düşük cıvalı balık (somon, sardalya)",
    "Kuruyemiş ve baklagiller",
    "Tam tahıllı ürünler",
  ];

  static const List<String> _limit = [
    "Kafein: günde en fazla ~200 mg (1–2 fincan)",
    "Büyük balıkları (ton balığı) sınırla",
    "Şeker ve işlenmiş gıdalar",
    "Tuz tüketimi (ödem/tansiyon için)",
  ];

  static const List<String> _avoid = [
    "Çiğ veya az pişmiş et ve yumurta",
    "Pastörize edilmemiş süt ve peynir",
    "Çiğ deniz ürünleri (suşi, istiridye)",
    "Yüksek cıvalı balık (kılıç, köpekbalığı, kral uskumru)",
    "İşlenmiş şarküteri (listeria riski)",
    "Çiğ filizler",
    "Alkol (tamamen)",
    "Yıkanmamış meyve/sebze",
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Beslenme & İlaç Güvenliği")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
          children: [
            _section(
                p, "Güvenli", Icons.check_circle_rounded, p.success, _safe),
            const SizedBox(height: AppSpacing.md),
            _section(
                p, "Sınırla", Icons.warning_amber_rounded, p.warning, _limit),
            const SizedBox(height: AppSpacing.md),
            _section(p, "Kaçın", Icons.cancel_rounded, p.danger, _avoid),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medication_rounded,
                          size: 18, color: p.primarySoft),
                      const SizedBox(width: 8),
                      Text("İlaç güvenliği",
                          style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Reçeteli/reçetesiz hiçbir ilacı veya bitkisel takviyeyi doktoruna danışmadan kullanma. "
                    "Folik asit ve doktorunun önerdiği gebelik vitaminleri genellikle güvenlidir. "
                    "Ağrı kesici, antibiyotik veya bitki çayları için mutlaka hekimine sor.",
                    style: TextStyle(
                        color: p.textSecondary, fontSize: 13, height: 1.55),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const InfoBanner(
              message:
                  "Bu liste genel bilgilendirme amaçlıdır. Kişisel durumun için doktoruna danış.",
              icon: Icons.info_outline_rounded,
              tone: PillTone.neutral,
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(AppPalette p, String title, IconData icon, Color color,
      List<String> items) {
    return AppCard(
      borderColor: color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final s in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    height: 7,
                    width: 7,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(s,
                        style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 13.5,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
