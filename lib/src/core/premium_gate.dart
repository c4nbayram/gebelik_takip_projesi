import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/premium_provider.dart';
import '../screens/membership_screen.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import 'guest_guard.dart';

class PremiumFeatures {
  PremiumFeatures._();
  static const String guide = "guide";
  static const String detailedAssessment = "detailed_assessment";
  static const String premiumContent = "premium_content";
}

Future<bool> requirePremium(
  BuildContext context,
  String feature, {
  String reason = "Bu içerik premium üyelik gerektirir.",
}) async {
  var premium = context.read<PremiumProvider>();
  if (premium.hasFeature(feature)) return true;

  if (!await ensureSignedIn(context,
      reason: "Premium içeriklere erişmek için giriş yapmalısın.")) {
    return false;
  }
  if (!context.mounted) return false;

  await context.read<PremiumProvider>().refresh();
  if (!context.mounted) return false;
  if (context.read<PremiumProvider>().hasFeature(feature)) return true;

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const MembershipScreen()),
  );
  if (!context.mounted) return false;
  return context.read<PremiumProvider>().hasFeature(feature);
}

class PremiumLockCard extends StatelessWidget {
  const PremiumLockCard({
    super.key,
    this.title = "Premium içerik",
    required this.message,
    this.feature = PremiumFeatures.premiumContent,
  });

  final String title;
  final String message;
  final String feature;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: p.brandGradient),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: p.glow(p.primary, strength: 0.25),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 24),
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
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.lock_rounded, size: 13, color: p.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          "Premium üyelere özel",
                          style: TextStyle(
                            color: p.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            onPressed: () => requirePremium(context, feature),
            label: "Üyeliğe Geç",
            icon: Icons.workspace_premium_rounded,
          ),
        ],
      ),
    );
  }
}
