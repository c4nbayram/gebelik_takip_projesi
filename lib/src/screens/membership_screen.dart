import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../providers/premium_provider.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';
import 'payment_screen.dart';

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );

  late Future<List<Plan>> _plansFuture;

  @override
  void initState() {
    super.initState();
    _plansFuture = _api.getPlans();
  }

  Future<void> _openPayment(Plan plan) async {
    final purchased = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaymentScreen(plan: plan)),
    );
    if (purchased == true && mounted) {
      await context.read<PremiumProvider>().refresh();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Üyelik Paketleri"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Plan>>(
          future: _plansFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final plans = snapshot.data ?? const <Plan>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                _statusHero(premium),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: "Paketler",
                  subtitle: "Detaylı değerlendirme ve ekstra içerikler için",
                  icon: Icons.workspace_premium_rounded,
                ),
                if (plans.isEmpty)
                  const EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: "Paketler yüklenemedi",
                    description:
                        "Bağlantını kontrol edip tekrar dene. Supabase yapılandırılmamış olabilir.",
                  )
                else
                  for (final plan in plans) ...[
                    _planCard(plan, premium),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                const SizedBox(height: AppSpacing.xs),
                const InfoBanner(
                  message:
                      "Bu bir demo ödeme akışıdır; gerçek tahsilat yapılmaz. Satın alma kaydı yalnızca yönetim paneline düşer.",
                  icon: Icons.info_outline_rounded,
                  tone: PillTone.neutral,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statusHero(PremiumProvider premium) {
    final p = context.palette;
    final isPremium = premium.isPremium;
    final sub = premium.subscription;
    return GradientHeroCard(
      gradient: isPremium ? null : p.heroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: Icon(
                  isPremium
                      ? Icons.workspace_premium_rounded
                      : Icons.lock_open_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isPremium
                          ? "Premium üyelik aktif"
                          : "Mevcut plan: Ücretsiz",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium
                          ? _fixText(sub?.planName ?? "Premium")
                          : "Gebelik Rehberi, detaylı değerlendirme ve premium içerik kilitli",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isPremium && sub?.expiresAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Bitiş: ${sub!.expiresAt!.toLocal().toString().split(' ').first}",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _planCard(Plan plan, PremiumProvider premium) {
    final p = context.palette;
    final isCurrent =
        premium.isPremium && premium.subscription?.planCode == plan.code;
    final highlight = !plan.isFree;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: highlight ? p.primary.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _fixText(plan.name),
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        if (highlight)
                          const StatPill(
                            label: "",
                            value: "Önerilen",
                            icon: Icons.star_rounded,
                            tone: PillTone.accent,
                          ),
                      ],
                    ),
                    if (plan.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _fixText(plan.description!),
                        style: TextStyle(
                          color: p.textMuted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.isFree
                        ? "Ücretsiz"
                        : "${plan.price.toStringAsFixed(2)} ${plan.currency}",
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (!plan.isFree)
                    Text(
                      plan.periodLabel,
                      style: TextStyle(color: p.textMuted, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final perk in plan.perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: p.success),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _fixText(perk),
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!plan.isFree) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: p.textMuted),
                const SizedBox(width: 6),
                Text(
                  _durationLabel(plan),
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (isCurrent)
            const StatPill(
              label: "",
              value: "Aktif planın",
              icon: Icons.verified_rounded,
              tone: PillTone.success,
            )
          else if (plan.isFree)
            Text(
              premium.isPremium ? "Temel plan" : "Mevcut planın",
              style: TextStyle(
                color: p.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            PrimaryButton(
              onPressed: () => _openPayment(plan),
              label: "Seç ve Öde",
              icon: Icons.shopping_cart_checkout_rounded,
            ),
        ],
      ),
    );
  }

  String _durationLabel(Plan plan) {
    final months = plan.durationMonths;
    if (months == null) return plan.isFree ? "Süresiz" : "Ömür boyu";
    if (months == 1) return "1 ay erişim";
    if (months == 9) return "Doğuma kadar (9 ay)";
    return "$months ay erişim";
  }

  String _fixText(String value) {
    const replacements = {
      "Ãœ": "Ü",
      "Ã¼": "ü",
      "Ã–": "Ö",
      "Ã¶": "ö",
      "Ã‡": "Ç",
      "Ã§": "ç",
      "Äž": "Ğ",
      "ÄŸ": "ğ",
      "Åž": "Ş",
      "ÅŸ": "ş",
      "Ä°": "İ",
      "Ä±": "ı",
      "â‚º": "₺",
      "â€”": "-",
    };

    var fixed = value;
    replacements.forEach((wrong, correct) {
      fixed = fixed.replaceAll(wrong, correct);
    });
    return fixed;
  }
}
