import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../core/icon_catalog.dart';
import '../core/premium_gate.dart';
import '../models/app_models.dart';
import '../providers/premium_provider.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';

class PremiumContentScreen extends StatefulWidget {
  const PremiumContentScreen({super.key});

  @override
  State<PremiumContentScreen> createState() => _PremiumContentScreenState();
}

class _PremiumContentScreenState extends State<PremiumContentScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );
  late Future<List<PremiumContent>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getPremiumContents();
  }

  Future<void> _open(PremiumContent content) async {
    final premium = context.read<PremiumProvider>();
    if (!premium.hasFeature(PremiumFeatures.premiumContent)) {
      final unlocked =
          await requirePremium(context, PremiumFeatures.premiumContent);
      if (!unlocked || !mounted) return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => _PremiumContentDetail(content: content)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final premium = context.watch<PremiumProvider>();
    final unlocked = premium.hasFeature(PremiumFeatures.premiumContent);
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Premium İçerik"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<List<PremiumContent>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? const <PremiumContent>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                if (!unlocked)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: PremiumLockCard(
                      title: "Uzman rehberleri",
                      message:
                          "Beslenme, egzersiz, doğuma hazırlık ve daha fazlası premium üyelere özel. Üyeliğe geçerek tüm içeriklerin kilidini aç.",
                    ),
                  ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.menu_book_rounded,
                    title: "İçerik bulunamadı",
                    description: "Yakında yeni rehberler eklenecek.",
                  )
                else
                  for (final c in items) ...[
                    _contentCard(p, c, unlocked),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _contentCard(AppPalette p, PremiumContent c, bool unlocked) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => _open(c),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: p.brandGradient),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(iconForName(c.icon, fallback: Icons.menu_book_rounded),
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (c.category != null) ...[
                      Text(
                        c.category!.toUpperCase(),
                        style: TextStyle(
                          color: p.primarySoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  c.title,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (c.summary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    c.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: AppSpacing.xs),
          Icon(
            unlocked ? Icons.chevron_right_rounded : Icons.lock_rounded,
            color: unlocked ? p.textMuted : p.primarySoft,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _PremiumContentDetail extends StatelessWidget {
  const _PremiumContentDetail({required this.content});

  final PremiumContent content;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(content.category ?? "İçerik"),
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
            Text(
              content.title,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            if (content.summary != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                content.summary!,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Text(
                content.body ?? "",
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
