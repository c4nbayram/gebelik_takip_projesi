import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';

class RedFlagScreen extends StatelessWidget {
  const RedFlagScreen({super.key});

  static const List<(String, String, String)> _flags = [
    (
      "🩸",
      "Vajinal kanama",
      "Lekelenmeden fazla, parlak kırmızı veya pıhtılı kanama."
    ),
    (
      "💧",
      "Su gelmesi",
      "Ani veya sızıntı şeklinde sıvı gelişi (amniyon sıvısı olabilir)."
    ),
    (
      "🤕",
      "Şiddetli/sürekli baş ağrısı",
      "Geçmeyen, görme bulanıklığı veya ışık çakmasıyla birlikte olan baş ağrısı."
    ),
    (
      "👁️",
      "Görmede değişiklik",
      "Bulanık görme, ışık çakmaları, kör noktalar — preeklampsi belirtisi olabilir."
    ),
    ("🦶", "Ani şiddetli şişlik", "El, yüz veya ayaklarda ani, belirgin ödem."),
    (
      "📉",
      "Bebek hareketlerinde azalma",
      "Bebeğin her zamankinden belirgin az hareket etmesi veya hiç hissedilmemesi."
    ),
    (
      "🤰",
      "Düzenli/güçlü kasılmalar",
      "37. haftadan önce düzenli, sıklaşan ve şiddetlenen kasılmalar."
    ),
    (
      "🌡️",
      "Yüksek ateş",
      "38°C ve üzeri, titreme veya idrar yakınmasıyla birlikte ateş."
    ),
    (
      "🫄",
      "Şiddetli karın/üst karın ağrısı",
      "Geçmeyen, şiddetli karın ağrısı (özellikle sağ üst karın)."
    ),
    (
      "🤮",
      "Durdurulamayan kusma",
      "Sıvı alamayacak kadar şiddetli, sürekli kusma."
    ),
    (
      "💨",
      "Nefes darlığı / göğüs ağrısı",
      "Ani nefes darlığı, göğüs ağrısı veya çarpıntı."
    ),
    (
      "🧠",
      "Baygınlık / bilinç bulanıklığı",
      "Bayılma, denge kaybı veya bilinç bulanıklığı."
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ne Zaman Doktora?"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _emergencyHero(p),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "Aşağıdaki belirtilerden biri olursa beklemeden sağlık kuruluşuna başvur:",
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final f in _flags) ...[
              _flagTile(p, f.$1, f.$2, f.$3),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Text(
                "Bu liste bilgilendirme amaçlıdır ve tıbbi tavsiye yerine geçmez. "
                "Emin olmadığın her durumda doktoruna danışmaktan çekinme.",
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emergencyHero(AppPalette p) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB84A5E), Color(0xFFFF7E8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: p.glow(p.danger, strength: 0.35),
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.emergency_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Acil durumda 112",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Şiddetli belirtilerde vakit kaybetme; 112'yi ara veya en yakın acile git.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagTile(AppPalette p, String emoji, String title, String desc) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderColor: p.danger.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.dangerBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
