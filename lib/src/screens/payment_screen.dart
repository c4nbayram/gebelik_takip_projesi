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
import '../widgets/app_text_field.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.plan});

  final Plan plan;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );
  final _card = TextEditingController(text: "4242 4242 4242 4242");
  final _exp = TextEditingController(text: "12/30");
  final _cvc = TextEditingController(text: "123");
  final _name = TextEditingController();

  bool _processing = false;
  bool _done = false;

  @override
  void dispose() {
    _card.dispose();
    _exp.dispose();
    _cvc.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final sub = await _api.purchasePlan(widget.plan);
      if (!mounted) return;
      context.read<PremiumProvider>().applyPurchase(sub);
      setState(() {
        _processing = false;
        _done = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ödeme tamamlanamadı: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final plan = widget.plan;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ödeme"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _done
            ? _successState(p)
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                children: [
                  _summaryCard(p, plan),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: "Kart Bilgileri",
                    subtitle: "Demo — gerçek tahsilat yapılmaz",
                    icon: Icons.credit_card_rounded,
                  ),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _name,
                          label: "Kart üzerindeki isim",
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _card,
                          label: "Kart numarası",
                          prefixIcon: Icons.credit_card_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _exp,
                                label: "AA/YY",
                                prefixIcon: Icons.calendar_month_rounded,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppTextField(
                                controller: _cvc,
                                label: "CVC",
                                prefixIcon: Icons.lock_outline_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const InfoBanner(
                    message:
                        "Bu ekran bir demodur. Kart bilgileri işlenmez ve hiçbir ücret alınmaz; yalnızca üyeliğin etkinleşir ve kayıt yönetim paneline düşer.",
                    icon: Icons.shield_outlined,
                    tone: PillTone.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    onPressed: _processing ? null : _pay,
                    loading: _processing,
                    label: plan.isFree
                        ? "Etkinleştir"
                        : "${plan.price.toStringAsFixed(2)} ${plan.currency} Öde",
                    icon: Icons.lock_rounded,
                    size: AppButtonSize.large,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard(AppPalette p, Plan plan) {
    return GradientHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Seçilen paket",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                plan.isFree
                    ? "Ücretsiz"
                    : "${plan.price.toStringAsFixed(2)} ${plan.currency}${plan.periodLabel}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _successState(AppPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 96,
              width: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: p.brandGradient),
                boxShadow: p.glow(p.primary, strength: 0.45),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 50),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "Üyeliğin etkinleşti!",
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Artık Gebelik Rehberi, detaylı değerlendirme ve premium içeriklere erişebilirsin.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.textMuted,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
